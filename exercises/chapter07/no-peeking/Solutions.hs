module Solutions where

import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as T
import TaskTracker

-- | Упражнение 1: Найти задачу по идентификатору.
lookupTask :: TaskId -> TaskStore -> Maybe Task
lookupTask tid (TaskStore m) = Map.lookup tid m

{- | Упражнение 2: Сериализовать хранилище в строку.
Формат каждой строки: "id|title|priority|status"
-}
serializeStore :: TaskStore -> String
serializeStore (TaskStore m)
  | Map.null m = ""
  | otherwise = unlines' $ map serializeEntry (Map.toAscList m)
 where
  serializeEntry (TaskId i, task) =
    show i
      ++ "|"
      ++ T.unpack (taskTitle task)
      ++ "|"
      ++ show (taskPriority task)
      ++ "|"
      ++ show (taskStatus task)

  -- unlines без завершающего переноса строки
  unlines' [] = ""
  unlines' [x] = x
  unlines' (x : xs) = x ++ "\n" ++ unlines' xs

-- | Упражнение 3: Разобрать строку обратно в хранилище.
parseStore :: String -> Either String TaskStore
parseStore "" = Right emptyStore
parseStore input = do
  entries <- mapM parseLine (lines input)
  Right $ TaskStore (Map.fromList entries)
 where
  parseLine line = case splitOn '|' line of
    [idStr, title, prioStr, statusStr] -> do
      tid <- case reads idStr of
        [(i, "")] -> Right (TaskId i)
        _ -> Left $ "Некорректный id: " ++ idStr
      prio <- parsePriority prioStr
      status <- parseStatus statusStr
      Right (tid, Task (T.pack title) prio status Set.empty)
    _ -> Left $ "Некорректный формат строки: " ++ line

  parsePriority "Low" = Right Low
  parsePriority "Medium" = Right Medium
  parsePriority "High" = Right High
  parsePriority s = Left $ "Некорректный приоритет: " ++ s

  parseStatus "Todo" = Right Todo
  parseStatus "InProgress" = Right InProgress
  parseStatus "Done" = Right Done
  parseStatus s = Left $ "Некорректный статус: " ++ s

  splitOn :: Char -> String -> [String]
  splitOn _ "" = [""]
  splitOn sep s =
    let (w, rest) = break (== sep) s
     in w : case rest of
          [] -> []
          (_ : rs) -> splitOn sep rs

-- | Упражнение 4: Пронумеровать строки текста.
addNumbers :: String -> String
addNumbers input =
  let ls = lines input
      numbered = zipWith (\n l -> show n ++ ": " ++ l) [1 :: Int ..] ls
   in unlines' numbered
 where
  unlines' [] = ""
  unlines' [x] = x
  unlines' (x : xs) = x ++ "\n" ++ unlines' xs
