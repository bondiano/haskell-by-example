module Solutions where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as T

import TaskTracker

-- ============================================================
-- Упражнение 1: Логика завершения задачи
-- ============================================================

{- | Проверяем текущий статус — если Done, ошибка;
иначе возвращаем задачу с Done.
-}
handleCompleteLogic :: Task -> Either Text Task
handleCompleteLogic task
  | taskStatus task == Done = Left "Задача уже выполнена"
  | otherwise = Right task{taskStatus = Done}

-- ============================================================
-- Упражнение 2: Статистика по статусам
-- ============================================================

{- | Для каждой задачи определяем ключ статуса,
затем группируем и считаем через Map.
-}
computeStatsMap :: [Task] -> Map Text Int
computeStatsMap tasks =
  let statusKey Todo = "todo"
      statusKey InProgress = "in_progress"
      statusKey Done = "done"
      keys = map (statusKey . taskStatus) tasks
   in Map.fromListWith (+) [(k, 1) | k <- keys]

-- ============================================================
-- Упражнение 3: Пагинация
-- ============================================================

-- | Пропускаем (page - 1) * perPage элементов, берём perPage.
paginate :: Int -> Int -> [a] -> [a]
paginate page perPage = take perPage . drop ((page - 1) * perPage)

-- ============================================================
-- Упражнение 4: Поиск по названию
-- ============================================================

{- | Приводим и запрос, и название к нижнему регистру,
затем проверяем вхождение через T.isInfixOf.
-}
searchByTitle :: Text -> [Task] -> [Task]
searchByTitle query = filter (\t -> needle `T.isInfixOf` T.toLower (taskTitle t))
 where
  needle = T.toLower query

-- ============================================================
-- Упражнение 5: Валидация приоритета
-- ============================================================

-- | Приводим к нижнему регистру и проверяем допустимость.
validatePriority :: Text -> Either Text Text
validatePriority input =
  let lowered = T.toLower input
   in if lowered `elem` ["low", "medium", "high"]
        then Right lowered
        else Left ("Неизвестный приоритет: " <> input)

-- ============================================================
-- Упражнение 6: Конвертация Task в TaskResponse
-- ============================================================

-- | Используем priorityToText и statusToText для конвертации.
entityToResponse :: Int -> Task -> TaskResponse
entityToResponse eid task =
  TaskResponse
    { responseId = eid
    , responseTitle = taskTitle task
    , responsePriority = priorityToText (taskPriority task)
    , responseStatus = statusToText (taskStatus task)
    }

-- ============================================================
-- Упражнение 7: Конвертация Priority ↔ Text
-- ============================================================

-- | Простое сопоставление с образцом.
priorityToText :: Priority -> Text
priorityToText Low = "low"
priorityToText Medium = "medium"
priorityToText High = "high"

-- | Приводим к нижнему регистру и сопоставляем.
textToPriority :: Text -> Either Text Priority
textToPriority t =
  case T.toLower t of
    "low" -> Right Low
    "medium" -> Right Medium
    "high" -> Right High
    _ -> Left ("Неизвестный приоритет: " <> t)

-- ============================================================
-- Упражнение 8: Конвертация Status ↔ Text
-- ============================================================

-- | Простое сопоставление с образцом.
statusToText :: Status -> Text
statusToText Todo = "todo"
statusToText InProgress = "in_progress"
statusToText Done = "done"

-- | Приводим к нижнему регистру и сопоставляем.
textToStatus :: Text -> Either Text Status
textToStatus t =
  case T.toLower t of
    "todo" -> Right Todo
    "in_progress" -> Right InProgress
    "done" -> Right Done
    _ -> Left ("Неизвестный статус: " <> t)
