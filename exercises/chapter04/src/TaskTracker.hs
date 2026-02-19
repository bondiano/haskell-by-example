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

-- | Статистика по списку задач.
data TaskStats = TaskStats
  { totalTasks :: Int
  , todoCount :: Int
  , progressCount :: Int
  , doneCount :: Int
  , highCount :: Int
  }
  deriving (Show, Eq)

-- | Пустая статистика.
emptyStats :: TaskStats
emptyStats = TaskStats 0 0 0 0 0

-- | Группировка задач по статусу.
groupByStatus :: TaskList -> [(Status, TaskList)]
groupByStatus tasks =
  [ (Todo, filter (\t -> taskStatus t == Todo) tasks)
  , (InProgress, filter (\t -> taskStatus t == InProgress) tasks)
  , (Done, filter (\t -> taskStatus t == Done) tasks)
  ]

-- | Примеры задач для тестирования.
exampleTasks :: TaskList
exampleTasks =
  [ Task "Купить молоко" "В магазине" Medium Todo
  , Task "Написать отчёт" "Квартальный" High InProgress
  , Task "Полить цветы" "" Low Done
  , Task "Обновить резюме" "Срочно" High Todo
  , Task "Позвонить врачу" "" Medium Done
  ]
