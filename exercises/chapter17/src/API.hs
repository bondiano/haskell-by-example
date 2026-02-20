{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module API (
  -- * API Type
  TaskAPI,
  taskAPI,
  taskServer,

  -- * Models
  TaskItem (..),
  TaskItemId,
  EntityField (..),
  migrateAll,

  -- * Database
  ConnectionPool,
  createPool,
  runDB,

  -- * Handlers (exported for testing)
  handleList,
  handleGet,
  handleCreate,
  handleUpdate,
  handleDelete,
  handleComplete,
  handleStats,

  -- * Utilities
  entityToResponse,
  requestToTaskItem,
  buildUpdates,
  validateCreate,
) where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Logger (runStdoutLoggingT)
import Data.Aeson (ToJSON (..), object, (.=))
import Data.ByteString.Lazy.Char8 qualified as LBS
import Data.Int (Int64)
import Data.Maybe (catMaybes)
import Data.Pool qualified as Pool
import Data.Text (Text)
import Data.Text qualified as T
import Database.Persist
import Database.Persist.Sqlite hiding (ConnectionPool)
import Database.Persist.TH
import GHC.Generics (Generic)
import Servant

import TaskTracker

-- ── Persistent Models ───────────────────────────────────────

share
  [mkPersist sqlSettings, mkMigrate "migrateAll"]
  [persistLowerCase|
TaskItem
  title       Text
  description Text default=''
  priority    Priority default='Medium'
  status      Status default='Todo'
  deriving Show Eq
|]

-- ── Database Types ──────────────────────────────────────────

type DB a = SqlPersistT IO a

type ConnectionPool = Pool.Pool SqlBackend

-- | Create a connection pool
createPool :: IO ConnectionPool
createPool = runStdoutLoggingT $ createSqlitePool "tasks.db" 5

-- | Run a database query in Handler monad
runDB :: ConnectionPool -> DB a -> Handler a
runDB pool query = liftIO $ runSqlPool query pool

-- ── API Definition ──────────────────────────────────────────

type TaskAPI =
  "tasks" :> Get '[JSON] [TaskResponse]
    :<|> "tasks" :> Capture "id" Int64 :> Get '[JSON] TaskResponse
    :<|> "tasks" :> ReqBody '[JSON] CreateTaskRequest :> Post '[JSON] TaskResponse
    :<|> "tasks" :> Capture "id" Int64 :> ReqBody '[JSON] UpdateTaskRequest :> Put '[JSON] TaskResponse
    :<|> "tasks" :> Capture "id" Int64 :> DeleteNoContent
    :<|> "tasks" :> Capture "id" Int64 :> "complete" :> Patch '[JSON] TaskResponse
    :<|> "stats" :> Get '[JSON] StatsResponse

taskAPI :: Proxy TaskAPI
taskAPI = Proxy

-- ── Handlers ────────────────────────────────────────────────

taskServer :: ConnectionPool -> Server TaskAPI
taskServer pool =
  handleList pool
    :<|> handleGet pool
    :<|> handleCreate pool
    :<|> handleUpdate pool
    :<|> handleDelete pool
    :<|> handleComplete pool
    :<|> handleStats pool

-- | GET /tasks - list all tasks
handleList :: ConnectionPool -> Handler [TaskResponse]
handleList pool = do
  items <- runDB pool $ selectList [] [Asc TaskItemTitle]
  pure (map entityToResponse items)

-- | GET /tasks/:id - get single task
handleGet :: ConnectionPool -> Int64 -> Handler TaskResponse
handleGet pool tid = do
  let key = toSqlKey tid :: TaskItemId
  mItem <- runDB pool $ get key
  case mItem of
    Nothing -> throwError err404{errBody = "Задача не найдена"}
    Just item -> pure (entityToResponse (Entity key item))

-- | POST /tasks - create task
handleCreate :: ConnectionPool -> CreateTaskRequest -> Handler TaskResponse
handleCreate pool req =
  case validateCreate req of
    Left err -> throwError err400{errBody = LBS.pack (T.unpack err)}
    Right validReq ->
      case requestToTaskItem validReq of
        Left err -> throwError err400{errBody = LBS.pack (T.unpack err)}
        Right item -> do
          newId <- runDB pool $ insert item
          pure (entityToResponse (Entity newId item))

-- | PUT /tasks/:id - update task
handleUpdate :: ConnectionPool -> Int64 -> UpdateTaskRequest -> Handler TaskResponse
handleUpdate pool tid req = do
  let key = toSqlKey tid :: TaskItemId
  mItem <- runDB pool $ get key
  case mItem of
    Nothing -> throwError err404{errBody = "Задача не найдена"}
    Just _ ->
      case buildUpdates req of
        Left err -> throwError err400{errBody = LBS.pack (T.unpack err)}
        Right updates -> do
          runDB pool $ update key updates
          mUpdated <- runDB pool $ get key
          case mUpdated of
            Nothing -> throwError err404{errBody = "Задача не найдена"}
            Just item -> pure (entityToResponse (Entity key item))

-- | DELETE /tasks/:id - delete task
handleDelete :: ConnectionPool -> Int64 -> Handler NoContent
handleDelete pool tid = do
  let key = toSqlKey tid :: TaskItemId
  mItem <- runDB pool $ get key
  case mItem of
    Nothing -> throwError err404{errBody = "Задача не найдена"}
    Just _ -> do
      runDB pool $ Database.Persist.delete key
      pure NoContent

-- | PATCH /tasks/:id/complete - mark task as done
handleComplete :: ConnectionPool -> Int64 -> Handler TaskResponse
handleComplete pool tid = do
  let key = toSqlKey tid :: TaskItemId
  mItem <- runDB pool $ get key
  case mItem of
    Nothing -> throwError err404{errBody = "Задача не найдена"}
    Just item ->
      if taskItemStatus item == Done
        then throwError err400{errBody = "Задача уже выполнена"}
        else do
          runDB pool $ update key [TaskItemStatus =. Done]
          mUpdated <- runDB pool $ get key
          case mUpdated of
            Nothing -> throwError err404{errBody = "Задача не найдена"}
            Just updatedItem -> pure (entityToResponse (Entity key updatedItem))

-- | GET /stats - task statistics
handleStats :: ConnectionPool -> Handler StatsResponse
handleStats pool = do
  total <- runDB pool $ count ([] :: [Filter TaskItem])
  todoCount <- runDB pool $ count [TaskItemStatus ==. Todo]
  inProgressCount <- runDB pool $ count [TaskItemStatus ==. InProgress]
  doneCount <- runDB pool $ count [TaskItemStatus ==. Done]
  pure
    StatsResponse
      { statsTotal = total
      , statsTodo = todoCount
      , statsInProgress = inProgressCount
      , statsDone = doneCount
      }

-- ── Conversion Functions ────────────────────────────────────

entityToResponse :: Entity TaskItem -> TaskResponse
entityToResponse (Entity key item) =
  TaskResponse
    { responseId = fromSqlKey key
    , responseTitle = taskItemTitle item
    , responsePriority = priorityToText (taskItemPriority item)
    , responseStatus = statusToText (taskItemStatus item)
    }

requestToTaskItem :: CreateTaskRequest -> Either Text TaskItem
requestToTaskItem CreateTaskRequest{..} = do
  priority <- textToPriority ctrPriority
  pure $
    TaskItem
      { taskItemTitle = ctrTitle
      , taskItemDescription = ctrDescription
      , taskItemPriority = priority
      , taskItemStatus = Todo
      }

buildUpdates :: UpdateTaskRequest -> Either Text [Update TaskItem]
buildUpdates UpdateTaskRequest{..} = do
  let titleUpd = (TaskItemTitle =.) <$> utrTitle
      descUpd = (TaskItemDescription =.) <$> utrDescription
  priorityUpd <- traverse (\t -> (TaskItemPriority =.) <$> textToPriority t) utrPriority
  statusUpd <- traverse (\t -> (TaskItemStatus =.) <$> textToStatus t) utrStatus
  pure $ catMaybes [titleUpd, descUpd, priorityUpd, statusUpd]

validateCreate :: CreateTaskRequest -> Either Text CreateTaskRequest
validateCreate req
  | T.null (ctrTitle req) =
      Left "Заголовок не может быть пустым"
  | ctrPriority req `notElem` ["low", "medium", "high"] =
      Left "Приоритет: low, medium, high"
  | otherwise =
      Right req
