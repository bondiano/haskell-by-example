module TaskTracker where

import Data.Text (Text)

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

type TaskList = [Task]

exampleTasks :: TaskList
exampleTasks =
  [ Task "Купить молоко" "" Medium Todo
  , Task "Написать отчёт" "" High InProgress
  , Task "Полить цветы" "" Low Done
  , Task "Сделать ревью" "" High Todo
  , Task "Обновить зависимости" "" Medium Done
  ]
