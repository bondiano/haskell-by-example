module MySolutions where

import Data.List (foldl')
import TaskTracker

-- | Вычислить статистику по списку задач с помощью foldl'.
computeStats :: TaskList -> TaskStats
computeStats = undefined

{- | Процент завершённых задач (doneCount / totalTasks).
Для пустого списка вернуть 0.0.
-}
completionRate :: TaskList -> Double
completionRate = undefined

{- | Отсортировать задачи по приоритету (High первые).
Реализовать через foldr и вспомогательную функцию вставки.
-}
sortByPriority :: TaskList -> TaskList
sortByPriority = undefined

-- | Перевернуть список с помощью foldl'.
myReverse :: [a] -> [a]
myReverse = undefined

-- | Реализовать map через foldr.
myMap :: (a -> b) -> [a] -> [b]
myMap = undefined

-- | Подсчитать частоту каждого элемента с помощью foldl'.
frequencies :: (Eq a) => [a] -> [(a, Int)]
frequencies = undefined

{- | Разбить список на куски заданного размера.
chunksOf 3 [1..7] == [[1,2,3],[4,5,6],[7]]
-}
chunksOf :: Int -> [a] -> [[a]]
chunksOf = undefined
