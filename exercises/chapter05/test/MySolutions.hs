module MySolutions where

import Data.List (sortBy)
import TaskTracker

-- | Класс для человекочитаемого описания значений.
class Describable a where
  describe :: a -> String

-- Упражнение 1: Реализуйте instance Describable Priority
-- "Низкий приоритет", "Средний приоритет", "Высокий приоритет"
instance Describable Priority where
  describe = undefined

-- Упражнение 2: Реализуйте instance Describable Status
-- "К выполнению", "В работе", "Выполнено"
instance Describable Status where
  describe = undefined

-- Упражнение 3: Реализуйте instance Describable Task
-- Формат: "[Высокий приоритет] Релиз — В работе"
instance Describable Task where
  describe = undefined

{- | Упражнение 4: Сравнение задач — сначала по приоритету (High первый),
затем по статусу (Todo первый).
-}
compareTasks :: Task -> Task -> Ordering
compareTasks = undefined

-- | Упражнение 5: Сортировка задач с помощью compareTasks.
sortTasks :: [Task] -> [Task]
sortTasks = undefined

-- | Упражнение 6: Список всех значений приоритета [Low, Medium, High].
allPriorities :: [Priority]
allPriorities = undefined

{- | Упражнение 7: Циклическое переключение приоритета.
Low → Medium, Medium → High, High → Low.
-}
cyclePriority :: Priority -> Priority
cyclePriority = undefined

-- | Упражнение 8: Обёртка над String с deriving Show и Eq.
newtype Name = Name String
  deriving stock (Show)
  deriving newtype (Eq)

-- | Класс для получения краткой и подробной сводки.
class Summarizable a where
  summary :: a -> String
  detailedSummary :: a -> String
  detailedSummary = summary

-- Упражнение 9: Реализуйте instance Summarizable TaskStats
-- summary: "N задач: M выполнено"
instance Summarizable TaskStats where
  summary = undefined
