module MySolutions where

import Control.Concurrent (threadDelay)
import Control.Concurrent.Async (mapConcurrently)
import Control.Concurrent.QSem

-- Упражнение 1: параллельная сумма подсписков
--
-- Вычислите сумму каждого подсписка параллельно через mapConcurrently,
-- затем сложите результаты.

concurrentSum :: [[Int]] -> IO Int
concurrentSum = undefined

-- Упражнение 2: таймаут через race
--
-- Запустите действие с ограничением по времени (микросекунды).
-- Верните Just результат, если действие успело, или Nothing при таймауте.

withTimeout :: Int -> IO a -> IO (Maybe a)
withTimeout = undefined

-- Упражнение 3: конкурентный подсчёт слов в файлах
--
-- Прочитайте файлы параллельно и подсчитайте слова в каждом.

concurrentWordCount :: [FilePath] -> IO [(FilePath, Int)]
concurrentWordCount = undefined

-- Упражнение 4: ограниченная конкурентность
--
-- Как mapConcurrently, но не более n задач одновременно.
-- Используйте QSem для ограничения.

mapConcurrentlyLimited :: Int -> (a -> IO b) -> [a] -> IO [b]
mapConcurrentlyLimited = undefined
