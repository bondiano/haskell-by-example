module Solutions where

import Control.Monad (foldM)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map

import TaskTracker

-- ============================================================
-- Упражнение 1: Завершение задачи
-- ============================================================

-- | Ищем задачу, проверяем статус, устанавливаем Done.
completeTask :: TaskId -> TaskStore -> Either AppError TaskStore
completeTask tid store@(TaskStore m) = do
  task <- note (TaskNotFound tid) (lookupTask tid store)
  case taskStatus task of
    Done -> Left (AlreadyDone tid)
    _ -> Right (TaskStore (Map.insert tid (task{taskStatus = Done}) m))

-- ============================================================
-- Упражнение 2: Удаление задачи
-- ============================================================

-- | Проверяем наличие задачи через note, затем удаляем.
deleteTask :: TaskId -> TaskStore -> Either AppError TaskStore
deleteTask tid store@(TaskStore m) = do
  _ <- note (TaskNotFound tid) (lookupTask tid store)
  Right (TaskStore (Map.delete tid m))

-- ============================================================
-- Упражнение 3: Обработка команд
-- ============================================================

{- | Обрабатываем команды через foldM.
AddCmd: создаём задачу с TaskId = размер + 1.
CompleteCmd: завершаем через completeTask.
-}
processCommands :: AppConfig -> [Command] -> TaskStore -> Either AppError TaskStore
processCommands cfg cmds store0 = foldM (flip $ executeCmd cfg) store0 cmds
 where
  executeCmd :: AppConfig -> Command -> TaskStore -> Either AppError TaskStore
  executeCmd config (AddCmd title) store =
    let tid = TaskId (Map.size (unTaskStore store) + 1)
        task = Task title (defaultPriority config) Todo
     in Right (addTask tid task store)
  executeCmd _ (CompleteCmd tid) store =
    completeTask tid store

-- ============================================================
-- Упражнение 4: safeHead и firstPlusSecond
-- ============================================================

-- | Безопасное взятие первого элемента.
safeHead :: [a] -> Maybe a
safeHead [] = Nothing
safeHead (x : _) = Just x

-- | Сумма первых двух элементов через do-нотацию Maybe.
firstPlusSecond :: [Int] -> Maybe Int
firstPlusSecond xs = do
  a <- safeHead xs
  b <- safeHead (drop 1 xs)
  return (a + b)

-- ============================================================
-- Упражнение 5: Валидация задачи
-- ============================================================

-- | Проверяем название: не пустое и не длиннее 200.
validateTask :: Task -> Either String Task
validateTask task
  | null (taskTitle task) = Left "Пустое название"
  | length (taskTitle task) > 200 = Left "Название слишком длинное"
  | otherwise = Right task

-- ============================================================
-- Упражнение 6: Все комбинации
-- ============================================================

-- | Монада списка: все пары (Priority, Status).
allTaskCombinations :: [(Priority, Status)]
allTaskCombinations = do
  p <- [Low, Medium, High]
  s <- [Todo, InProgress, Done]
  return (p, s)

-- ============================================================
-- Упражнение 7: Цепочка поисков
-- ============================================================

{- | Ищем каждый ключ в Map, все должны быть найдены.
Возвращаем значение последнего ключа.
-}
safeLookupChain :: (Ord k) => [k] -> Map k k -> Maybe k
safeLookupChain [] _ = Nothing
safeLookupChain (k : ks) m = do
  v <- Map.lookup k m
  foldM (\_ k' -> Map.lookup k' m) v ks
