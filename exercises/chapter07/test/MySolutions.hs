module MySolutions where

import Data.Map.Strict qualified as Map
import TaskTracker

-- | Упражнение 1: Найти задачу по идентификатору.
lookupTask :: TaskId -> TaskStore -> Maybe Task
lookupTask = undefined

{- | Упражнение 2: Сериализовать хранилище в строку.
Формат каждой строки: "id|title|priority|status"
Например: "1|Релиз|High|Todo"
-}
serializeStore :: TaskStore -> String
serializeStore = undefined

{- | Упражнение 3: Разобрать строку обратно в хранилище.
При ошибке формата возвращает Left с описанием ошибки.
-}
parseStore :: String -> Either String TaskStore
parseStore = undefined

{- | Упражнение 4: Пронумеровать строки текста.
"hello\nworld" → "1: hello\n2: world"
-}
addNumbers :: String -> String
addNumbers = undefined

-- Интерактивные IO-упражнения (описаны в тексте главы, не тестируются автоматически):
--
-- echoLoop :: IO ()
-- echoLoop = undefined
--
-- interactiveSum :: IO ()
-- interactiveSum = undefined
--
-- numberLines :: IO ()
-- numberLines = undefined
