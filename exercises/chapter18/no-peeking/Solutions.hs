module Solutions where

import Data.Text (Text)
import Database.Persist
import Database.Persist.Sql (SqlPersistT)

import Data.Todo (Todo(..), TodoId, EntityField(..))

-- Упражнение 1

insertTodo :: Text -> SqlPersistT IO (Key Todo)
insertTodo title = insert (Todo title False)

-- Упражнение 2

toggleTodo :: Key Todo -> SqlPersistT IO ()
toggleTodo todoId = do
  mTodo <- get todoId
  case mTodo of
    Nothing   -> return ()
    Just todo -> update todoId [TodoCompleted =. not (todoCompleted todo)]

-- Упражнение 3

filteredTodos :: Bool -> SqlPersistT IO [Entity Todo]
filteredTodos status = selectList [TodoCompleted ==. status] []

-- Упражнение 4

archiveDone :: SqlPersistT IO Int
archiveDone = do
  done <- selectList [TodoCompleted ==. True] []
  deleteWhere [TodoCompleted ==. True]
  return (length done)
