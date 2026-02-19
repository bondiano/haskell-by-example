module MySolutions where

import Data.List (nubBy)
import TaskTracker

-- | Создать задачу с приоритетом Medium, статусом Todo и пустым описанием.
mkTask :: String -> Task
mkTask = undefined

-- | Завершить задачу — вернуть копию со статусом Done.
completeTask :: Task -> Task
completeTask = undefined

-- | Найти задачу по точному совпадению заголовка.
findTaskByTitle :: String -> TaskList -> Maybe Task
findTaskByTitle = undefined

-- | Проверить, существует ли задача с данным заголовком.
taskExists :: String -> TaskList -> Bool
taskExists = undefined

-- | Проверить, является ли задача высокоприоритетной.
isHighPriority :: Task -> Bool
isHighPriority = undefined

-- | Отформатировать список задач: show каждой задачи через unlines.
formatTasks :: TaskList -> String
formatTasks = undefined

-- | Удалить дубликаты по заголовку (оставить первое вхождение).
removeDuplicates :: TaskList -> TaskList
removeDuplicates = undefined
