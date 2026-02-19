module MySolutions where

import Data.Char (toLower)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map

import TaskTracker

-- ============================================================
-- Упражнение 1: Безопасное удаление задачи
--
-- Удалите задачу по идентификатору. Если задачи нет —
-- верните Left (TaskNotFound tid).
-- ============================================================

{- | Удаление задачи из хранилища.

>>> deleteTaskSafe (TaskId 1) exampleStore
Right (TaskStore ...)

>>> deleteTaskSafe (TaskId 99) exampleStore
Left (TaskNotFound (TaskId 99))
-}
deleteTaskSafe :: TaskId -> TaskStore -> Either AppError TaskStore
deleteTaskSafe = undefined

-- ============================================================
-- Упражнение 2: Обновление названия задачи
--
-- Обновите название задачи по идентификатору.
-- Проверки:
--   1. Название не должно быть пустым → Left (InvalidInput "Пустое название")
--   2. Задача должна существовать    → Left (TaskNotFound tid)
-- ============================================================

{- | Обновление названия задачи.

>>> updateTitle (TaskId 1) "Купить хлеб" exampleStore
Right (TaskStore ...)

>>> updateTitle (TaskId 1) "" exampleStore
Left (InvalidInput "Пустое название")

>>> updateTitle (TaskId 99) "Тест" exampleStore
Left (TaskNotFound (TaskId 99))
-}
updateTitle :: TaskId -> String -> TaskStore -> Either AppError TaskStore
updateTitle = undefined

-- ============================================================
-- Упражнение 3: Безопасное деление
--
-- Целочисленное деление с проверкой на ноль.
-- При делении на ноль верните Left "Деление на ноль".
-- ============================================================

{- | Безопасное целочисленное деление.

>>> safeDiv 10 3
Right 3

>>> safeDiv 10 0
Left "Деление на ноль"
-}
safeDiv :: Int -> Int -> Either String Int
safeDiv = undefined

-- ============================================================
-- Упражнение 4: Парсинг приоритета
--
-- Преобразуйте строку в значение Priority.
-- Регистронезависимый: "low" → Low, "medium" → Medium, "high" → High.
-- Иначе: Left "Неизвестный приоритет: X"
--
-- Подсказка: используйте map toLower из Data.Char.
-- ============================================================

{- | Парсинг приоритета из строки.

>>> parsePriority "high"
Right High

>>> parsePriority "LOW"
Right Low

>>> parsePriority "urgent"
Left "Неизвестный приоритет: urgent"
-}
parsePriority :: String -> Either String Priority
parsePriority = undefined

-- ============================================================
-- Упражнение 5: Цепочка операций
--
-- Примените список операций последовательно к хранилищу.
-- Остановитесь на первой ошибке.
--
-- Подсказка: используйте foldl с >>= или foldM.
-- ============================================================

{- | Последовательное применение операций.

>>> let ops = [Right . addTask (TaskId 4) (Task "Новая" Low Todo)]
>>> chainOperations ops emptyStore
Right (TaskStore ...)
-}
chainOperations ::
  [TaskStore -> Either AppError TaskStore] -> TaskStore -> Either AppError TaskStore
chainOperations = undefined

-- ============================================================
-- Бонус (не тестируется): loadTasksFromFile
--
-- Загрузка задач из файла. Это IO-упражнение.
-- Прочитайте файл, распарсите строки, верните Either AppError TaskStore.
-- ============================================================

-- loadTasksFromFile :: FilePath -> IO (Either AppError TaskStore)
-- loadTasksFromFile = undefined
