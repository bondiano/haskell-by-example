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

-- | Фильтр задач — алгебраический тип.
data TaskFilter
  = AllTasks
  | ByStatus Status
  | ByPriority Priority
  deriving (Show, Eq)

-- | Проверить, подходит ли задача под фильтр.
applyFilter :: TaskFilter -> Task -> Bool
applyFilter AllTasks _ = True
applyFilter (ByStatus s) task = taskStatus task == s
applyFilter (ByPriority p) task = taskPriority task == p

-- | Отфильтровать список задач.
filterTasks :: TaskFilter -> TaskList -> TaskList
filterTasks f = filter (applyFilter f)

-- | Примеры задач для тестирования.
exampleTasks :: TaskList
exampleTasks =
  [ Task "Купить молоко" "В магазине" Medium Todo
  , Task "Написать отчёт" "Квартальный" High InProgress
  , Task "Полить цветы" "" Low Done
  , Task "Обновить резюме" "Срочно" High Todo
  ]
