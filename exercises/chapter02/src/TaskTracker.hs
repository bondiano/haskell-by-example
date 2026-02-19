module TaskTracker where

-- | Приоритет задачи.
data Priority = Low | Medium | High
  deriving (Show, Eq, Ord)

-- | Статус задачи.
data Status = Todo | InProgress | Done
  deriving (Show, Eq, Ord)

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

-- | Примеры задач для тестирования.
exampleTasks :: TaskList
exampleTasks =
  [ Task "Купить молоко" "В магазине" Medium Todo
  , Task "Написать отчёт" "Квартальный" High InProgress
  , Task "Полить цветы" "" Low Done
  , Task "Купить молоко" "Другое описание" Low Todo
  ]
