module Solutions where

import Data.Char (toLower)
import Data.List (intercalate)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as T
import Text.Read (readMaybe)

import TaskTracker

-- ============================================================
-- Упражнение 1: Статистика хранилища
-- ============================================================

data TaskStats = TaskStats
  { totalTasks :: Int
  , todoCount :: Int
  , doneCount :: Int
  , highPriority :: Int
  }
  deriving (Show, Eq)

-- | Проходим по всем задачам и считаем нужные метрики.
computeStats :: TaskStore -> TaskStats
computeStats store =
  let tasks = map snd (allTasks store)
   in TaskStats
        { totalTasks = length tasks
        , todoCount = length (filter (\t -> taskStatus t == Todo) tasks)
        , doneCount = length (filter (\t -> taskStatus t == Done) tasks)
        , highPriority = length (filter (\t -> taskPriority t == High) tasks)
        }

-- ============================================================
-- Упражнение 2: Смарт-конструктор приоритета
-- ============================================================

-- | Приводим строку к нижнему регистру и сопоставляем с образцом.
mkPriority :: String -> Maybe Priority
mkPriority s =
  case map toLower s of
    "low" -> Just Low
    "medium" -> Just Medium
    "high" -> Just High
    _ -> Nothing

-- ============================================================
-- Упражнение 3: Парсинг команд
-- ============================================================

data Command
  = AddCmd Text
  | ListCmd
  | DoneCmd TaskId
  | DeleteCmd TaskId
  | QuitCmd
  deriving (Show, Eq)

-- | Разбираем строку по первому слову, используем readMaybe для чисел.
parseCommand :: String -> Maybe Command
parseCommand input =
  case words input of
    ["list"] -> Just ListCmd
    ["quit"] -> Just QuitCmd
    ("add" : rest)
      | not (null rest) -> Just (AddCmd (T.pack (unwords rest)))
    ["done", n] -> DoneCmd . TaskId <$> readMaybe n
    ["delete", n] -> DeleteCmd . TaskId <$> readMaybe n
    _ -> Nothing

-- ============================================================
-- Упражнение 4: Отображение задач
-- ============================================================

-- | Форматируем задачу: "[id] title (priority, status)"
renderTask :: (TaskId, Task) -> String
renderTask (TaskId tid, Task{taskTitle, taskPriority, taskStatus}) =
  "["
    ++ show tid
    ++ "] "
    ++ T.unpack taskTitle
    ++ " ("
    ++ show taskPriority
    ++ ", "
    ++ show taskStatus
    ++ ")"

-- | Соединяем отформатированные задачи через перенос строки.
renderTaskList :: [(TaskId, Task)] -> String
renderTaskList = intercalate "\n" . map renderTask

-- | Форматируем статистику в читаемую строку.
renderStats :: TaskStats -> String
renderStats TaskStats{..} =
  "Всего: "
    ++ show totalTasks
    ++ ", Todo: "
    ++ show todoCount
    ++ ", Done: "
    ++ show doneCount
    ++ ", Высокий приоритет: "
    ++ show highPriority

-- ============================================================
-- Упражнение 5: Непустой текст
-- ============================================================

newtype NonEmptyText = NonEmptyText Text
  deriving (Show, Eq)

-- | Проверяем, что текст не пуст и не состоит из одних пробелов.
mkNonEmptyText :: Text -> Maybe NonEmptyText
mkNonEmptyText t
  | T.null (T.strip t) = Nothing
  | otherwise = Just (NonEmptyText t)

unNonEmptyText :: NonEmptyText -> Text
unNonEmptyText (NonEmptyText t) = t

-- ============================================================
-- Упражнение 6: lookupDefault
-- ============================================================

-- | Используем Map.findWithDefault, меняя порядок аргументов.
lookupDefault :: (Ord k) => v -> k -> Map k v -> v
lookupDefault = Map.findWithDefault

-- ============================================================
-- Упражнение 7: Парсинг CSV
-- ============================================================

-- | Парсим каждую строку CSV, разделяя по запятой.
parseCSV :: Text -> Either String [Task]
parseCSV input
  | T.null input = Right []
  | otherwise = mapM parseLine (T.lines input)
 where
  parseLine :: Text -> Either String Task
  parseLine line =
    case T.splitOn "," line of
      [title, prio, stat] -> do
        p <- parsePrio (T.strip prio)
        s <- parseStatus (T.strip stat)
        Right (Task (T.strip title) p s)
      _ -> Left ("Неверный формат строки: " ++ T.unpack line)

  parsePrio :: Text -> Either String Priority
  parsePrio t =
    case T.toLower t of
      "low" -> Right Low
      "medium" -> Right Medium
      "high" -> Right High
      _ -> Left ("Неизвестный приоритет: " ++ T.unpack t)

  parseStatus :: Text -> Either String Status
  parseStatus t =
    case T.toLower t of
      "todo" -> Right Todo
      "in_progress" -> Right InProgress
      "done" -> Right Done
      _ -> Left ("Неизвестный статус: " ++ T.unpack t)

-- ============================================================
-- Упражнение 8 (не тестируется):
-- Организация package.yaml — пример структуры пакета
-- уже представлен в самом package.yaml этой главы.
-- ============================================================
