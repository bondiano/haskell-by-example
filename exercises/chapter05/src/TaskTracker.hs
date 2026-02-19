module TaskTracker where

-- | Приоритет задачи.
data Priority = Low | Medium | High
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | Статус задачи.
data Status = Todo | InProgress | Done
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | Задача трекера.
data Task = Task
  { taskTitle :: String
  , taskDescription :: String
  , taskPriority :: Priority
  , taskStatus :: Status
  }
  deriving (Show, Eq)

-- | Список задач.
type TaskList = [Task]

-- | Статистика по списку задач.
data TaskStats = TaskStats
  { totalTasks :: Int
  , todoCount :: Int
  , doneCount :: Int
  , highCount :: Int
  }
  deriving (Show, Eq)
