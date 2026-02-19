module Solutions where

import Data.Char (toLower)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map

import TaskTracker

-- ============================================================
-- Упражнение 1: Безопасное удаление задачи
-- ============================================================

{- | Удаление задачи — проверяем наличие через lookupTask,
затем удаляем через Map.delete.
-}
deleteTaskSafe :: TaskId -> TaskStore -> Either AppError TaskStore
deleteTaskSafe tid store@(TaskStore m) =
  case lookupTask tid store of
    Nothing -> Left (TaskNotFound tid)
    Just _ -> Right (TaskStore (Map.delete tid m))

-- ============================================================
-- Упражнение 2: Обновление названия задачи
-- ============================================================

{- | Сначала проверяем пустое название, затем наличие задачи.
Обновляем через Map.adjust.
-}
updateTitle :: TaskId -> String -> TaskStore -> Either AppError TaskStore
updateTitle _ "" _ = Left (InvalidInput "Пустое название")
updateTitle tid newTitle store@(TaskStore m) =
  case lookupTask tid store of
    Nothing -> Left (TaskNotFound tid)
    Just task ->
      let updated = task{taskTitle = newTitle}
       in Right (TaskStore (Map.insert tid updated m))

-- ============================================================
-- Упражнение 3: Безопасное деление
-- ============================================================

-- | Проверяем делитель на ноль, иначе делим через div.
safeDiv :: Int -> Int -> Either String Int
safeDiv _ 0 = Left "Деление на ноль"
safeDiv a b = Right (a `div` b)

-- ============================================================
-- Упражнение 4: Парсинг приоритета
-- ============================================================

-- | Приводим строку к нижнему регистру и сопоставляем.
parsePriority :: String -> Either String Priority
parsePriority s =
  case map toLower s of
    "low" -> Right Low
    "medium" -> Right Medium
    "high" -> Right High
    _ -> Left ("Неизвестный приоритет: " ++ s)

-- ============================================================
-- Упражнение 5: Цепочка операций
-- ============================================================

{- | foldl с >>= — каждая операция получает результат предыдущей.
При первой ошибке (Left) >>= прекращает выполнение.
-}
chainOperations ::
  [TaskStore -> Either AppError TaskStore] -> TaskStore -> Either AppError TaskStore
chainOperations ops store = foldl (>>=) (Right store) ops
