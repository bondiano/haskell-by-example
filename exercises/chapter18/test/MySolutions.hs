module MySolutions where

import Data.Text (Text)
import TaskTracker

{- | Упражнение 1: Парсер одного фильтра.
  Разбирает выражения вида "status:done", "priority:high", "tag:work".
  Используйте Text.Megaparsec.Char.string для ключевых слов
  и takeWhile1P для значения.
-}
pFilterExpr :: Parser FilterExpr
pFilterExpr = undefined

{- | Упражнение 2: Парсер запроса — несколько фильтров через пробелы.
  Используйте sepBy1 или some.
-}
pQuery :: Parser Query
pQuery = undefined

{- | Упражнение 3: Проверка, соответствует ли задача одному фильтру.
  StatusFilter — сравнение по статусу.
  PriorityFilter — сравнение по приоритету.
  TagFilter — проверка, есть ли тег в taskTags.
-}
matchFilter :: FilterExpr -> Task -> Bool
matchFilter = undefined

{- | Упражнение 4: Красивая печать запроса обратно в текст.
  Query [StatusFilter "done", TagFilter "work"] -> "status:done tag:work"
-}
prettyQuery :: Query -> Text
prettyQuery = undefined

{- | Упражнение 5: Обёртка над parse — возвращает Either String Query.
  Преобразуйте ошибку megaparsec в строку с помощью errorBundlePretty.
-}
parseQuery :: Text -> Either String Query
parseQuery = undefined

{- | Упражнение 6: Фильтрация списка задач по всем фильтрам запроса (AND).
  Задача проходит, если удовлетворяет каждому фильтру в Query.
-}
executeQuery :: Query -> [Task] -> [Task]
executeQuery = undefined
