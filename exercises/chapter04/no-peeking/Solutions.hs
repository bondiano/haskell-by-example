{-# HLINT ignore "Use map" #-}
module Solutions where

import Data.List (foldl')
import TaskTracker

-- | Вычислить статистику по списку задач с помощью foldl'.
computeStats :: TaskList -> TaskStats
computeStats = foldl' accumulate emptyStats
 where
  accumulate stats task =
    TaskStats
      { totalTasks = totalTasks stats + 1
      , todoCount = todoCount stats + if taskStatus task == Todo then 1 else 0
      , progressCount = progressCount stats + if taskStatus task == InProgress then 1 else 0
      , doneCount = doneCount stats + if taskStatus task == Done then 1 else 0
      , highCount = highCount stats + if taskPriority task == High then 1 else 0
      }

{- | Процент завершённых задач (doneCount / totalTasks).
Для пустого списка вернуть 0.0.
-}
completionRate :: TaskList -> Double
completionRate [] = 0.0
completionRate tasks =
  let stats = computeStats tasks
   in fromIntegral (doneCount stats) / fromIntegral (totalTasks stats)

{- | Отсортировать задачи по приоритету (High первые).
Реализовать через foldr и вспомогательную функцию вставки.
-}
sortByPriority :: TaskList -> TaskList
sortByPriority = foldr insertByPriority []
 where
  -- \| Вставить задачу в отсортированный список,
  -- сохраняя порядок по приоритету (High > Medium > Low).
  insertByPriority :: Task -> TaskList -> TaskList
  insertByPriority t [] = [t]
  insertByPriority t (x : xs)
    | taskPriority t >= taskPriority x = t : x : xs
    | otherwise = x : insertByPriority t xs

-- | Перевернуть список с помощью foldl'.
myReverse :: [a] -> [a]
myReverse = foldl' (flip (:)) []

-- | Реализовать map через foldr.
myMap :: (a -> b) -> [a] -> [b]
myMap f = foldr (\x acc -> f x : acc) []

-- | Подсчитать частоту каждого элемента с помощью foldl'.
frequencies :: (Eq a) => [a] -> [(a, Int)]
frequencies = foldl' addOrIncrement []
 where
  addOrIncrement [] x = [(x, 1)]
  addOrIncrement ((k, c) : rest) x
    | k == x = (k, c + 1) : rest
    | otherwise = (k, c) : addOrIncrement rest x

-- | Разбить список на куски заданного размера.
chunksOf :: Int -> [a] -> [[a]]
chunksOf _ [] = []
chunksOf n xs =
  let (chunk, rest) = splitAt n xs
   in chunk : chunksOf n rest
