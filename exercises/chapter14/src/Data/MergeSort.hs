module Data.MergeSort
  ( mergeSort
  , merge
  , sorted
  ) where

-- | Сортировка слиянием.
--
-- >>> mergeSort [3, 1, 4, 1, 5, 9]
-- [1,1,3,4,5,9]
mergeSort :: Ord a => [a] -> [a]
mergeSort []  = []
mergeSort [x] = [x]
mergeSort xs  =
  let (l, r) = splitAt (length xs `div` 2) xs
  in merge (mergeSort l) (mergeSort r)

-- | Слияние двух отсортированных списков в один отсортированный.
--
-- >>> merge [1, 3, 5] [2, 4, 6]
-- [1,2,3,4,5,6]
merge :: Ord a => [a] -> [a] -> [a]
merge [] ys = ys
merge xs [] = xs
merge (x:xs) (y:ys)
  | x <= y    = x : merge xs (y:ys)
  | otherwise = y : merge (x:xs) ys

-- | Проверяет, что список отсортирован по неубыванию.
--
-- >>> sorted [1, 2, 3]
-- True
-- >>> sorted [3, 1, 2]
-- False
sorted :: Ord a => [a] -> Bool
sorted []       = True
sorted [_]      = True
sorted (x:y:xs) = x <= y && sorted (y:xs)
