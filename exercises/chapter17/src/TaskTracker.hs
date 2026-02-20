module TaskTracker (
  Priority (..),
  Status (..),
  Task (..),
  TaskResponse (..),
  CreateTaskRequest (..),
  UpdateTaskRequest (..),
  StatsResponse (..),
  priorityToText,
  statusToText,
  textToPriority,
  textToStatus,
) where

import Data.Aeson (
  FromJSON (..),
  ToJSON (..),
  object,
  withObject,
  withText,
  (.!=),
  (.:),
  (.:?),
  (.=),
 )
import Data.Int (Int64)
import Data.Text (Text)
import Data.Text qualified as T
import Database.Persist (PersistField (..), PersistValue (..))
import Database.Persist.Sql (PersistFieldSql (..), SqlType (..))
import GHC.Generics (Generic)

-- ── Базовые типы ────────────────────────────────────────────

data Priority = Low | Medium | High
  deriving (Show, Eq, Ord, Generic)

data Status = Todo | InProgress | Done
  deriving (Show, Eq, Ord, Generic)

data Task = Task
  { taskTitle :: Text
  , taskPriority :: Priority
  , taskStatus :: Status
  }
  deriving (Show, Eq, Generic)

-- ── JSON instances для базовых типов ───────────────────────

instance ToJSON Priority where
  toJSON = toJSON . priorityToText

instance FromJSON Priority where
  parseJSON = withText "Priority" $ \t ->
    case textToPriority t of
      Right p -> pure p
      Left err -> fail (T.unpack err)

instance ToJSON Status where
  toJSON = toJSON . statusToText

instance FromJSON Status where
  parseJSON = withText "Status" $ \t ->
    case textToStatus t of
      Right s -> pure s
      Left err -> fail (T.unpack err)

instance ToJSON Task
instance FromJSON Task

-- ── PersistField instances для типобезопасности БД ─────────

instance PersistField Priority where
  toPersistValue Low = PersistText "low"
  toPersistValue Medium = PersistText "medium"
  toPersistValue High = PersistText "high"

  fromPersistValue (PersistText "low") = Right Low
  fromPersistValue (PersistText "medium") = Right Medium
  fromPersistValue (PersistText "high") = Right High
  fromPersistValue (PersistText x) =
    Left $ "Неизвестный приоритет: " <> x
  fromPersistValue x =
    Left $ "Ожидался Text, получено: " <> T.pack (show x)

instance PersistFieldSql Priority where
  sqlType _ = SqlString

instance PersistField Status where
  toPersistValue Todo = PersistText "todo"
  toPersistValue InProgress = PersistText "in_progress"
  toPersistValue Done = PersistText "done"

  fromPersistValue (PersistText "todo") = Right Todo
  fromPersistValue (PersistText "in_progress") = Right InProgress
  fromPersistValue (PersistText "done") = Right Done
  fromPersistValue (PersistText x) =
    Left $ "Неизвестный статус: " <> x
  fromPersistValue x =
    Left $ "Ожидался Text, получено: " <> T.pack (show x)

instance PersistFieldSql Status where
  sqlType _ = SqlString

-- ── DTO типы для API ────────────────────────────────────────

data CreateTaskRequest = CreateTaskRequest
  { ctrTitle :: Text
  , ctrDescription :: Text
  , ctrPriority :: Text
  }
  deriving (Show, Eq, Generic)

instance FromJSON CreateTaskRequest where
  parseJSON = withObject "CreateTaskRequest" $ \v ->
    CreateTaskRequest
      <$> v .: "title"
      <*> v .:? "description" .!= ""
      <*> v .:? "priority" .!= "medium"

data UpdateTaskRequest = UpdateTaskRequest
  { utrTitle :: Maybe Text
  , utrDescription :: Maybe Text
  , utrPriority :: Maybe Text
  , utrStatus :: Maybe Text
  }
  deriving (Show, Eq, Generic)

instance FromJSON UpdateTaskRequest where
  parseJSON = withObject "UpdateTaskRequest" $ \v ->
    UpdateTaskRequest
      <$> v .:? "title"
      <*> v .:? "description"
      <*> v .:? "priority"
      <*> v .:? "status"

data TaskResponse = TaskResponse
  { responseId :: Int64
  , responseTitle :: Text
  , responsePriority :: Text
  , responseStatus :: Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON TaskResponse where
  toJSON TaskResponse{..} =
    object
      [ "id" .= responseId
      , "title" .= responseTitle
      , "priority" .= responsePriority
      , "status" .= responseStatus
      ]

data StatsResponse = StatsResponse
  { statsTotal :: Int
  , statsTodo :: Int
  , statsInProgress :: Int
  , statsDone :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON StatsResponse where
  toJSON StatsResponse{..} =
    object
      [ "total" .= statsTotal
      , "todo" .= statsTodo
      , "in_progress" .= statsInProgress
      , "done" .= statsDone
      ]

-- ── Конвертация Priority ↔ Text ────────────────────────────

priorityToText :: Priority -> Text
priorityToText Low = "low"
priorityToText Medium = "medium"
priorityToText High = "high"

textToPriority :: Text -> Either Text Priority
textToPriority t =
  case T.toLower t of
    "low" -> Right Low
    "medium" -> Right Medium
    "high" -> Right High
    _ -> Left ("Неизвестный приоритет: " <> t)

-- ── Конвертация Status ↔ Text ──────────────────────────────

statusToText :: Status -> Text
statusToText Todo = "todo"
statusToText InProgress = "in_progress"
statusToText Done = "done"

textToStatus :: Text -> Either Text Status
textToStatus t =
  case T.toLower t of
    "todo" -> Right Todo
    "in_progress" -> Right InProgress
    "done" -> Right Done
    _ -> Left ("Неизвестный статус: " <> t)
