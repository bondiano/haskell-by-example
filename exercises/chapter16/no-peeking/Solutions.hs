module Solutions where

import Control.Concurrent (threadDelay)
import Control.Concurrent.Async
import Control.Concurrent.MVar
import Control.Concurrent.STM

-- ============================================================
-- Упражнение 1: Потокобезопасный счётчик на MVar
-- ============================================================

type Counter = MVar Int

-- | Создаём MVar с начальным значением 0.
newCounter :: IO Counter
newCounter = newMVar 0

-- | modifyMVar_ атомарно читает, модифицирует и записывает значение.
increment :: Counter -> IO ()
increment c = modifyMVar_ c (\n -> pure (n + 1))

-- | readMVar читает значение без извлечения.
getCount :: Counter -> IO Int
getCount = readMVar

-- ============================================================
-- Упражнение 2: Таймаут для IO-действия
-- ============================================================

{- | race запускает два действия параллельно.
Если таймер (threadDelay) завершится первым → Left () → Nothing.
Если действие завершится первым → Right a → Just a.
-}
withTimeout :: Int -> IO a -> IO (Maybe a)
withTimeout microseconds action = do
  result <- race (threadDelay microseconds) action
  case result of
    Left () -> pure Nothing
    Right a -> pure (Just a)

-- ============================================================
-- Упражнение 3: Параллельная сумма
-- ============================================================

{- | Запускаем pure для каждого элемента конкурентно, затем суммируем.
Для реально больших списков можно разбить на чанки.
-}
parallelSum :: [Int] -> IO Int
parallelSum xs = sum <$> mapConcurrently pure xs

-- ============================================================
-- Упражнение 4: STM банковские переводы
-- ============================================================

type Account = TVar Int

-- | Создаём TVar с начальным балансом.
newAccount :: Int -> IO Account
newAccount = newTVarIO

-- | Атомарно увеличиваем баланс.
deposit :: Account -> Int -> STM ()
deposit acc amount = modifyTVar' acc (+ amount)

-- | Атомарно уменьшаем баланс.
withdraw :: Account -> Int -> STM ()
withdraw acc amount = modifyTVar' acc (subtract amount)

{- | Перевод — это снятие с одного и зачисление на другой
в одной STM-транзакции (атомарно).
-}
transfer :: Account -> Account -> Int -> STM ()
transfer from to amount = do
  withdraw from amount
  deposit to amount

-- ============================================================
-- Упражнение 5: parallelMap
-- ============================================================

{- | mapConcurrently запускает все действия параллельно
и собирает результаты в том же порядке.
-}
parallelMap :: (a -> IO b) -> [a] -> IO [b]
parallelMap = mapConcurrently

-- ============================================================
-- Упражнение 6: Логгер на TChan
-- ============================================================

type Logger = TChan String

-- | Создаём новый TChan.
newLogger :: IO Logger
newLogger = newTChanIO

-- | Записываем сообщение в канал.
logMessage :: Logger -> String -> IO ()
logMessage logger msg = atomically $ writeTChan logger msg

{- | Читаем все сообщения из канала (tryReadTChan возвращает Nothing,
когда канал пуст).
-}
flushLog :: Logger -> IO [String]
flushLog logger = atomically $ flushTChan logger
 where
  flushTChan :: TChan a -> STM [a]
  flushTChan chan = do
    mval <- tryReadTChan chan
    case mval of
      Nothing -> pure []
      Just val -> (val :) <$> flushTChan chan

-- ============================================================
-- Упражнение 7: Гонка нескольких действий
-- ============================================================

{- | Запускаем все действия через async, ждём первое завершившееся
через waitAnyCancel (отменяет остальные).
-}
raceAll :: [IO a] -> IO a
raceAll [] = error "raceAll: пустой список действий"
raceAll actions = do
  asyncs <- mapM async actions
  (_, result) <- waitAnyCancel asyncs
  pure result

-- ============================================================
-- Упражнение 8: Пул воркеров (не тестируется)
-- ============================================================

-- workerPool :: Int -> TChan (IO ()) -> IO ()
-- workerPool n chan = do
--   let worker = forever $ do
--         action <- atomically $ readTChan chan
--         action
--   mapConcurrently_ (const worker) [1..n]
