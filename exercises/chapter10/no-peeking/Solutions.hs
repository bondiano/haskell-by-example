module Solutions where

import Control.Concurrent (threadDelay)
import Control.Concurrent.Async (mapConcurrently, race, withAsync, wait)
import Control.Concurrent.QSem

-- Упражнение 1: параллельная сумма подсписков

concurrentSum :: [[Int]] -> IO Int
concurrentSum xss = do
  sums <- mapConcurrently (pure . sum) xss
  return (sum sums)

-- Упражнение 2: таймаут через race

withTimeout :: Int -> IO a -> IO (Maybe a)
withTimeout usec action = do
  result <- race (threadDelay usec) action
  case result of
    Left ()  -> return Nothing
    Right a  -> return (Just a)

-- Упражнение 3: конкурентный подсчёт слов в файлах

concurrentWordCount :: [FilePath] -> IO [(FilePath, Int)]
concurrentWordCount paths =
  mapConcurrently countFile paths
  where
    countFile path = do
      contents <- readFile path
      let n = length (words contents)
      return (path, n)

-- Упражнение 4: ограниченная конкурентность

mapConcurrentlyLimited :: Int -> (a -> IO b) -> [a] -> IO [b]
mapConcurrentlyLimited n f xs = do
  sem <- newQSem n
  mapConcurrently (withSem sem . f) xs
  where
    withSem sem action = do
      waitQSem sem
      result <- action
      signalQSem sem
      return result
