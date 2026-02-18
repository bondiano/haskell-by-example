module Euler where

-- | Задача Эйлера №1
-- Найти сумму всех чисел, кратных 3 или 5, ниже заданного предела.
--
-- >>> answer 10
-- 23
answer :: Int -> Int
answer limit = sum [x | x <- [1 .. limit - 1], x `mod` 3 == 0 || x `mod` 5 == 0]
