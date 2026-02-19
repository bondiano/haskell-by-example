module Solutions where

import Data.List (nubBy)
import TaskTracker

-- | Создать задачу с приоритетом Medium, статусом Todo и пустым описанием.
mkTask :: String -> Task
mkTask title =
  Task
    { taskTitle = title
    , taskDescription = ""
    , taskPriority = Medium
    , taskStatus = Todo
    }

-- | Завершить задачу — вернуть копию со статусом Done.
completeTask :: Task -> Task
completeTask task = task{taskStatus = Done}

-- | Найти задачу по точному совпадению заголовка.
findTaskByTitle :: String -> TaskList -> Maybe Task
findTaskByTitle _ [] = Nothing
findTaskByTitle title (t : ts)
  | taskTitle t == title = Just t
  | otherwise = findTaskByTitle title ts

-- | Проверить, существует ли задача с данным заголовком.
taskExists :: String -> TaskList -> Bool
taskExists title = any (\t -> taskTitle t == title)

-- | Проверить, является ли задача высокоприоритетной.
isHighPriority :: Task -> Bool
isHighPriority task = taskPriority task == High

-- | Отформатировать список задач: show каждой задачи через unlines.
formatTasks :: TaskList -> String
formatTasks = unlines . map show

-- | Удалить дубликаты по заголовку (оставить первое вхождение).
removeDuplicates :: TaskList -> TaskList
removeDuplicates = nubBy sameTitle
 where
  sameTitle t1 t2 = taskTitle t1 == taskTitle t2
