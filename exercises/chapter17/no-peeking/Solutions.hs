module Solutions where

import Data.Int (Int64)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as T
import Database.Persist
import Servant

import API
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
  let
    statusKey Todo = "todo"
    statusKey InProgress = "in_progress"
    statusKey Done = "done"
    keys = map (statusKey . taskStatus) tasks
   in
    Map.fromListWith (+) [(k, 1) | k <- keys]

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
entityToResponsePure :: Int64 -> Task -> TaskResponse
entityToResponsePure eid task =
  TaskResponse
    { responseId = eid
    , responseTitle = taskTitle task
    , responsePriority = priorityToText (taskPriority task)
    , responseStatus = statusToText (taskStatus task)
    }

-- ============================================================
-- Упражнение 7: Пагинированный список задач
-- ============================================================

-- | Извлекаем page и per_page, применяем LimitTo и OffsetBy.
handleListPaginated ::
  ConnectionPool ->
  Maybe Int ->
  Maybe Int ->
  Handler [TaskResponse]
handleListPaginated pool mPage mPerPage = do
  let page = fromMaybe 1 mPage
      perPage = fromMaybe 20 mPerPage
      offset = (page - 1) * perPage
  items <- runDB pool $ selectList [] [Asc TaskItemTitle, LimitTo perPage, OffsetBy offset]
  pure (map entityToResponse items)

-- ============================================================
-- Упражнение 8: Поиск по заголовку
-- ============================================================

{- | Фильтруем задачи по подстроке в Haskell (SQLite не поддерживает
регистронезависимый LIKE легко через persistent).
-}
handleSearch ::
  ConnectionPool ->
  Maybe Text ->
  Handler [TaskResponse]
handleSearch pool Nothing = handleList pool
handleSearch pool (Just query) = do
  allItems <- runDB pool $ selectList [] [Asc TaskItemTitle]
  let needle = T.toLower query
      filtered = filter (\(Entity _ item) -> needle `T.isInfixOf` T.toLower (taskItemTitle item)) allItems
  pure (map entityToResponse filtered)
