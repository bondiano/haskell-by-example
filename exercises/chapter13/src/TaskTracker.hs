module TaskTracker where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)

newtype TaskId = TaskId Int
  deriving (Show, Eq, Ord)
  deriving newtype (Num)

data Priority = Low | Medium | High
  deriving (Show, Eq, Ord)

data Status = Todo | InProgress | Done
  deriving (Show, Eq, Ord)

data Task = Task
  { taskTitle :: Text
  , taskDescription :: Text
  , taskPriority :: Priority
  , taskStatus :: Status
  }
  deriving (Show, Eq)

newtype TaskStore = TaskStore {unTaskStore :: Map TaskId Task}
  deriving (Show, Eq)

data AppConfig = AppConfig
  { configStorePath :: FilePath
  , configMaxTasks :: Int
  }
  deriving (Show, Eq)

data AppError = TaskNotFound TaskId | InvalidInput Text | StoreFull
  deriving (Show, Eq)

emptyStore :: TaskStore
emptyStore = TaskStore Map.empty

addTask :: TaskId -> Task -> TaskStore -> TaskStore
addTask tid task (TaskStore m) = TaskStore (Map.insert tid task m)

lookupTask :: TaskId -> TaskStore -> Maybe Task
lookupTask tid (TaskStore m) = Map.lookup tid m

storeSize :: TaskStore -> Int
storeSize (TaskStore m) = Map.size m

exampleStore :: TaskStore
exampleStore =
  TaskStore $
    Map.fromList
      [ (TaskId 1, Task "Купить молоко" "" Medium Todo)
      , (TaskId 2, Task "Написать отчёт" "" High InProgress)
      , (TaskId 3, Task "Полить цветы" "" Low Done)
      ]
