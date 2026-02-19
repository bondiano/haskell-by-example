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
  , taskPriority :: Priority
  , taskStatus :: Status
  }
  deriving (Show, Eq)

newtype TaskStore = TaskStore {unTaskStore :: Map TaskId Task}
  deriving (Show, Eq)

emptyStore :: TaskStore
emptyStore = TaskStore Map.empty

addTask :: TaskId -> Task -> TaskStore -> TaskStore
addTask tid task (TaskStore m) = TaskStore (Map.insert tid task m)

allTasks :: TaskStore -> [(TaskId, Task)]
allTasks (TaskStore m) = Map.toList m
