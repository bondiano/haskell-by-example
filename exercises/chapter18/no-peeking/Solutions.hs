module Solutions where

import Data.Text (Text)
import Data.Text qualified as T
import Data.Void (Void)
import Text.Megaparsec
import Text.Megaparsec.Char (char, space, string)

import TaskTracker

{- | Упражнение 1: Парсер одного фильтра.
  Разбирает "status:value", "priority:value", "tag:value".
-}
pFilterExpr :: Parser FilterExpr
pFilterExpr = statusFilter <|> priorityFilter <|> tagFilter
 where
  -- \| Значение — непустая последовательность символов, не являющихся пробелами.
  pValue :: Parser Text
  pValue = takeWhile1P (Just "значение фильтра") (/= ' ')

  statusFilter :: Parser FilterExpr
  statusFilter = StatusFilter <$> (string "status:" *> pValue)

  priorityFilter :: Parser FilterExpr
  priorityFilter = PriorityFilter <$> (string "priority:" *> pValue)

  tagFilter :: Parser FilterExpr
  tagFilter = TagFilter <$> (string "tag:" *> pValue)

-- | Упражнение 2: Парсер запроса — несколько фильтров через пробелы.
pQuery :: Parser Query
pQuery = Query <$> sepBy1 pFilterExpr (char ' ')

-- | Упражнение 3: Проверка, соответствует ли задача одному фильтру.
matchFilter :: FilterExpr -> Task -> Bool
matchFilter (StatusFilter val) task = statusMatches val task
matchFilter (PriorityFilter val) task = priorityMatches val task
matchFilter (TagFilter val) task = val `elem` taskTags task

-- | Упражнение 4: Красивая печать запроса обратно в текст.
prettyQuery :: Query -> Text
prettyQuery (Query filters) = T.intercalate " " (map prettyFilter filters)
 where
  prettyFilter :: FilterExpr -> Text
  prettyFilter (StatusFilter val) = "status:" <> val
  prettyFilter (PriorityFilter val) = "priority:" <> val
  prettyFilter (TagFilter val) = "tag:" <> val

-- | Упражнение 5: Обёртка над parse — возвращает Either String Query.
parseQuery :: Text -> Either String Query
parseQuery input = case parse pQuery "" input of
  Left err -> Left (errorBundlePretty err)
  Right q -> Right q

-- | Упражнение 6: Фильтрация списка задач по всем фильтрам (AND-семантика).
executeQuery :: Query -> [Task] -> [Task]
executeQuery (Query filters) =
  filter (\task -> all (`matchFilter` task) filters)
