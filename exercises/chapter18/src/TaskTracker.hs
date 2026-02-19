module TaskTracker where

import Data.Text (Text)
import Data.Void (Void)
import Text.Megaparsec (Parsec)

-- | Тип парсера для нашего DSL
type Parser = Parsec Void Text

-- | Приоритет задачи.
data Priority = Low | Medium | High
  deriving (Show, Eq, Ord)

-- | Статус задачи.
data Status = Todo | InProgress | Done
  deriving (Show, Eq, Ord)

-- | Задача трекера.
data Task = Task
  { taskTitle :: Text
  , taskPriority :: Priority
  , taskStatus :: Status
  , taskTags :: [Text]
  }
  deriving (Show, Eq)

-- | Выражение фильтрации
data FilterExpr
  = StatusFilter Text -- status:done
  | PriorityFilter Text -- priority:high
  | TagFilter Text -- tag:work
  deriving (Show, Eq)

-- | Полный запрос — список фильтров
newtype Query = Query [FilterExpr]
  deriving (Show, Eq)

-- | Проверка соответствия задачи фильтру по статусу.
statusMatches :: Text -> Task -> Bool
statusMatches "todo" t = taskStatus t == Todo
statusMatches "in-progress" t = taskStatus t == InProgress
statusMatches "done" t = taskStatus t == Done
statusMatches _ _ = False

-- | Проверка соответствия задачи фильтру по приоритету.
priorityMatches :: Text -> Task -> Bool
priorityMatches "low" t = taskPriority t == Low
priorityMatches "medium" t = taskPriority t == Medium
priorityMatches "high" t = taskPriority t == High
priorityMatches _ _ = False

-- | Примеры задач для тестирования.
exampleTasks :: [Task]
exampleTasks =
  [ Task "Купить молоко" Low Todo ["дом", "покупки"]
  , Task "Написать отчёт" High InProgress ["работа"]
  , Task "Полить цветы" Medium Done ["дом"]
  , Task "Подготовить презентацию" High Todo ["работа", "важное"]
  , Task "Забрать посылку" Low Done ["дом"]
  ]
