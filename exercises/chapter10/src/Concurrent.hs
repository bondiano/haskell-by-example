module Concurrent
  ( countWords
  , fibSlow
  , timed
  ) where

import Data.Time.Clock (getCurrentTime, diffUTCTime)

-- | Подсчёт слов в строке.
countWords :: String -> Int
countWords = length . words

-- | Намеренно медленный Фибоначчи для демонстрации параллелизма.
--
-- >>> fibSlow 30
-- 832040
fibSlow :: Int -> Int
fibSlow 0 = 0
fibSlow 1 = 1
fibSlow n = fibSlow (n - 1) + fibSlow (n - 2)

-- | Измерение времени выполнения IO-действия (в секундах).
timed :: IO a -> IO (a, Double)
timed action = do
  start <- getCurrentTime
  result <- action
  end <- getCurrentTime
  let elapsed = realToFrac (diffUTCTime end start) :: Double
  return (result, elapsed)
