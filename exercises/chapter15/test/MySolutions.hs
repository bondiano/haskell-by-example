module MySolutions where

import Data.Char (toLower)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as T

import TaskTracker

-- ============================================================
-- Упражнение 1: Статистика хранилища
--
-- Определите тип TaskStats и функцию computeStats.
-- TaskStats содержит: totalTasks, todoCount, doneCount, highPriority.
-- ============================================================

data TaskStats = TaskStats
  { totalTasks :: Int
  , todoCount :: Int
  , doneCount :: Int
  , highPriority :: Int
  }
  deriving (Show, Eq)

{- | Вычислить статистику по хранилищу задач.

>>> computeStats emptyStore
TaskStats {totalTasks = 0, todoCount = 0, doneCount = 0, highPriority = 0}
-}
computeStats :: TaskStore -> TaskStats
computeStats = undefined

-- ============================================================
-- Упражнение 2: Смарт-конструктор приоритета
--
-- Парсинг строки в Priority. Регистронезависимый:
-- "low" → Just Low, "medium" → Just Medium, "high" → Just High.
-- Всё остальное → Nothing.
-- ============================================================

{- | Смарт-конструктор для Priority.

>>> mkPriority "high"
Just High

>>> mkPriority "unknown"
Nothing
-}
mkPriority :: String -> Maybe Priority
mkPriority = undefined

-- ============================================================
-- Упражнение 3: Парсинг команд
--
-- Определите тип Command и функцию parseCommand.
-- Команды:
--   "add <текст>"  → AddCmd <текст>
--   "list"         → ListCmd
--   "done <число>" → DoneCmd (TaskId <число>)
--   "delete <число>" → DeleteCmd (TaskId <число>)
--   "quit"         → QuitCmd
--   иначе          → Nothing
-- ============================================================

data Command
  = AddCmd Text
  | ListCmd
  | DoneCmd TaskId
  | DeleteCmd TaskId
  | QuitCmd
  deriving (Show, Eq)

{- | Разбор строки команды.

>>> parseCommand "add Новая задача"
Just (AddCmd "Новая задача")

>>> parseCommand "list"
Just ListCmd

>>> parseCommand "done 5"
Just (DoneCmd (TaskId 5))
-}
parseCommand :: String -> Maybe Command
parseCommand = undefined

-- ============================================================
-- Упражнение 4: Отображение задач
--
-- renderTask  — отформатировать одну задачу: "[id] title (priority, status)"
-- renderTaskList — отформатировать список через "\n"
-- renderStats — отформатировать статистику
-- ============================================================

{- | Отформатировать одну задачу.

>>> renderTask (TaskId 1, Task "Тест" High Todo)
"[1] Тест (High, Todo)"
-}
renderTask :: (TaskId, Task) -> String
renderTask = undefined

{- | Отформатировать список задач.

>>> renderTaskList [(TaskId 1, Task "Тест" High Todo)]
"[1] Тест (High, Todo)"
-}
renderTaskList :: [(TaskId, Task)] -> String
renderTaskList = undefined

{- | Отформатировать статистику.

>>> renderStats (TaskStats 4 2 1 2)
"Всего: 4, Todo: 2, Done: 1, Высокий приоритет: 2"
-}
renderStats :: TaskStats -> String
renderStats = undefined

-- ============================================================
-- Упражнение 5: Непустой текст (newtype + смарт-конструктор)
--
-- Определите newtype NonEmptyText с:
--   mkNonEmptyText  :: Text -> Maybe NonEmptyText
--   unNonEmptyText  :: NonEmptyText -> Text
-- Пустые и пробельные строки отклоняются.
-- ============================================================

newtype NonEmptyText = NonEmptyText Text
  deriving (Show, Eq)

{- | Создать NonEmptyText. Отклоняет пустые и пробельные строки.

>>> mkNonEmptyText "hello"
Just (NonEmptyText "hello")

>>> mkNonEmptyText ""
Nothing
-}
mkNonEmptyText :: Text -> Maybe NonEmptyText
mkNonEmptyText = undefined

-- | Извлечь текст из NonEmptyText.
unNonEmptyText :: NonEmptyText -> Text
unNonEmptyText (NonEmptyText t) = t

-- ============================================================
-- Упражнение 6: lookupDefault
--
-- Аналог Map.findWithDefault, но с другим порядком аргументов:
-- lookupDefault defaultValue key map
-- ============================================================

{- | Поиск значения в Map с значением по умолчанию.

>>> lookupDefault 0 "a" (Map.fromList [("a", 1)])
1

>>> lookupDefault 0 "z" (Map.fromList [("a", 1)])
0
-}
lookupDefault :: (Ord k) => v -> k -> Map k v -> v
lookupDefault = undefined

-- ============================================================
-- Упражнение 7: Парсинг CSV
--
-- Формат строки: "title,priority,status"
-- priority: low, medium, high (регистронезависимый)
-- status: todo, in_progress, done (регистронезависимый)
-- Пустая строка → Right []
-- ============================================================

{- | Парсинг CSV в список задач.

>>> parseCSV "Задача,low,todo"
Right [Task {taskTitle = "Задача", taskPriority = Low, taskStatus = Todo}]
-}
parseCSV :: Text -> Either String [Task]
parseCSV = undefined

-- ============================================================
-- Упражнение 8 (не тестируется):
-- Организация package.yaml — описано в тексте главы.
-- ============================================================
