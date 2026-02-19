module MySolutions where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as T

import TaskTracker

-- ============================================================
-- Упражнение 1: Логика завершения задачи
--
-- Если задача уже Done → Left "Задача уже выполнена"
-- Иначе → Right (задача с taskStatus = Done)
-- ============================================================

{- | Логика завершения задачи (чистая функция, без базы данных).

>>> handleCompleteLogic (Task "Тест" Low Todo)
Right (Task {taskTitle = "Тест", taskPriority = Low, taskStatus = Done})

>>> handleCompleteLogic (Task "Тест" Low Done)
Left "Задача уже выполнена"
-}
handleCompleteLogic :: Task -> Either Text Task
handleCompleteLogic = undefined

-- ============================================================
-- Упражнение 2: Статистика по статусам
--
-- Подсчитайте количество задач для каждого статуса.
-- Ключи: "todo", "in_progress", "done".
-- ============================================================

{- | Подсчёт задач по статусам.

>>> computeStatsMap [Task "A" Low Todo, Task "B" High Done]
fromList [("done",1),("todo",1)]
-}
computeStatsMap :: [Task] -> Map Text Int
computeStatsMap = undefined

-- ============================================================
-- Упражнение 3: Пагинация
--
-- paginate page perPage xs — взять perPage элементов со страницы page.
-- Страницы нумеруются с 1.
-- paginate 1 20 xs = take 20 xs
-- paginate 2 20 xs = take 20 (drop 20 xs)
-- ============================================================

{- | Пагинация списка.

>>> paginate 1 3 [1..10]
[1,2,3]

>>> paginate 2 3 [1..10]
[4,5,6]
-}
paginate :: Int -> Int -> [a] -> [a]
paginate = undefined

-- ============================================================
-- Упражнение 4: Поиск по названию
--
-- Регистронезависимый поиск по подстроке в taskTitle.
-- Подсказка: T.isInfixOf и T.toLower.
-- ============================================================

{- | Поиск задач по подстроке в названии.

>>> searchByTitle "молоко" [Task "Купить молоко" Low Todo]
[Task {taskTitle = "Купить молоко", taskPriority = Low, taskStatus = Todo}]
-}
searchByTitle :: Text -> [Task] -> [Task]
searchByTitle = undefined

-- ============================================================
-- Упражнение 5: Валидация приоритета
--
-- Проверить и нормализовать строку приоритета.
-- "HIGH" → Right "high", "Low" → Right "low"
-- Неизвестное → Left "Неизвестный приоритет: X"
-- ============================================================

{- | Валидация и нормализация строки приоритета.

>>> validatePriority "HIGH"
Right "high"

>>> validatePriority "urgent"
Left "Неизвестный приоритет: urgent"
-}
validatePriority :: Text -> Either Text Text
validatePriority = undefined

-- ============================================================
-- Упражнение 6: Конвертация Task в TaskResponse
--
-- Преобразуйте Task в TaskResponse, добавив id и
-- конвертировав Priority/Status в текст.
-- ============================================================

{- | Создать TaskResponse из идентификатора и задачи.

>>> entityToResponse 1 (Task "Тест" Low Todo)
TaskResponse {responseId = 1, responseTitle = "Тест", responsePriority = "low", responseStatus = "todo"}
-}
entityToResponse :: Int -> Task -> TaskResponse
entityToResponse = undefined

-- ============================================================
-- Упражнение 7: Конвертация Priority ↔ Text
--
-- priorityToText: Low → "low", Medium → "medium", High → "high"
-- textToPriority: обратная операция, регистронезависимая
-- ============================================================

-- | Конвертация Priority в Text.
priorityToText :: Priority -> Text
priorityToText = undefined

-- | Конвертация Text в Priority (регистронезависимая).
textToPriority :: Text -> Either Text Priority
textToPriority = undefined

-- ============================================================
-- Упражнение 8: Конвертация Status ↔ Text
--
-- statusToText: Todo → "todo", InProgress → "in_progress", Done → "done"
-- textToStatus: обратная операция, регистронезависимая
-- ============================================================

-- | Конвертация Status в Text.
statusToText :: Status -> Text
statusToText = undefined

-- | Конвертация Text в Status (регистронезависимая).
textToStatus :: Text -> Either Text Status
textToStatus = undefined
