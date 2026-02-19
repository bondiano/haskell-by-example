module Solutions where

import Data.List (sortBy)
import TaskTracker

-- | Класс для человекочитаемого описания значений.
class Describable a where
  describe :: a -> String

-- Упражнение 1
instance Describable Priority where
  describe Low = "Низкий приоритет"
  describe Medium = "Средний приоритет"
  describe High = "Высокий приоритет"

-- Упражнение 2
instance Describable Status where
  describe Todo = "К выполнению"
  describe InProgress = "В работе"
  describe Done = "Выполнено"

-- Упражнение 3
instance Describable Task where
  describe task =
    "["
      ++ describe (taskPriority task)
      ++ "] "
      ++ taskTitle task
      ++ " — "
      ++ describe (taskStatus task)

{- | Упражнение 4: Сравнение задач — сначала по приоритету (High первый),
затем по статусу (Todo первый).
-}
compareTasks :: Task -> Task -> Ordering
compareTasks a b =
  case compare (taskPriority b) (taskPriority a) of
    EQ -> compare (taskStatus a) (taskStatus b)
    x -> x

-- | Упражнение 5: Сортировка задач с помощью compareTasks.
sortTasks :: [Task] -> [Task]
sortTasks = sortBy compareTasks

-- | Упражнение 6: Список всех значений приоритета.
allPriorities :: [Priority]
allPriorities = [minBound .. maxBound]

-- | Упражнение 7: Циклическое переключение приоритета.
cyclePriority :: Priority -> Priority
cyclePriority p
  | p == maxBound = minBound
  | otherwise = succ p

-- | Упражнение 8: Обёртка над String с deriving Show и Eq.
newtype Name = Name String
  deriving stock (Show)
  deriving newtype (Eq)

-- | Класс для получения краткой и подробной сводки.
class Summarizable a where
  summary :: a -> String
  detailedSummary :: a -> String
  detailedSummary = summary

-- Упражнение 9
instance Summarizable TaskStats where
  summary stats =
    show (totalTasks stats) ++ " задач: " ++ show (doneCount stats) ++ " выполнено"
