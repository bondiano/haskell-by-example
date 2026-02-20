module TaskTracker where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)

data Priority = Low | Medium | High
  deriving (Show, Eq, Ord, Enum, Bounded)

data Status = Todo | InProgress | Done
  deriving (Show, Eq, Ord, Enum, Bounded)

data Task = Task
  { taskTitle :: Text
  , taskDescription :: Text
  , taskPriority :: Priority
  , taskStatus :: Status
  }
  deriving (Show, Eq)

newtype TaskId = TaskId Int
  deriving (Show, Eq, Ord)
  deriving newtype (Num)

newtype TaskStore = TaskStore {unTaskStore :: Map TaskId Task}
  deriving (Show, Eq)

data TaskFilter = AllTasks | ByStatus Status | ByPriority Priority
  deriving (Show, Eq)

emptyStore :: TaskStore
emptyStore = TaskStore Map.empty

addTask :: TaskId -> Task -> TaskStore -> TaskStore
addTask tid task (TaskStore m) = TaskStore (Map.insert tid task m)

removeTask :: TaskId -> TaskStore -> TaskStore
removeTask tid (TaskStore m) = TaskStore (Map.delete tid m)

lookupTask :: TaskId -> TaskStore -> Maybe Task
lookupTask tid (TaskStore m) = Map.lookup tid m

storeSize :: TaskStore -> Int
storeSize (TaskStore m) = Map.size m

filterTasks :: TaskFilter -> [Task] -> [Task]
filterTasks AllTasks ts = ts
filterTasks (ByStatus s) ts = filter (\t -> taskStatus t == s) ts
filterTasks (ByPriority p) ts = filter (\t -> taskPriority t == p) ts
