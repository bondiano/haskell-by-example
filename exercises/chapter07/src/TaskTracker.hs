module TaskTracker where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)

-- | Идентификатор задачи.
newtype TaskId = TaskId Int
  deriving (Show, Eq, Ord)
  deriving newtype (Num)

-- | Тег задачи.
type Tag = Text

-- | Приоритет задачи.
data Priority = Low | Medium | High
  deriving (Show, Eq, Ord)

-- | Статус задачи.
data Status = Todo | InProgress | Done
  deriving (Show, Eq, Ord)

-- | Задача трекера.
data Task = Task
  { taskTitle :: Text
  , taskPriority :: Priority
  , taskStatus :: Status
  , taskTags :: Set Tag
  }
  deriving (Show, Eq)

-- | Хранилище задач.
newtype TaskStore = TaskStore {unTaskStore :: Map TaskId Task}
  deriving (Show, Eq)

-- | Пустое хранилище.
emptyStore :: TaskStore
emptyStore = TaskStore Map.empty

-- | Добавить задачу в хранилище.
addTask :: TaskId -> Task -> TaskStore -> TaskStore
addTask tid task (TaskStore m) = TaskStore (Map.insert tid task m)

-- | Команда пользователя.
data Command
  = AddCmd String
  | ListCmd
  | DoneCmd TaskId
  | ShowCmd TaskId
  | QuitCmd
  deriving (Show, Eq)

-- | Разобрать строку в команду.
parseCommand :: String -> Maybe Command
parseCommand input = case words input of
  ["add", title] -> Just (AddCmd title)
  ["list"] -> Just ListCmd
  ["done", n] -> case reads n of
    [(i, "")] -> Just (DoneCmd (TaskId i))
    _ -> Nothing
  ["show", n] -> case reads n of
    [(i, "")] -> Just (ShowCmd (TaskId i))
    _ -> Nothing
  ["quit"] -> Just QuitCmd
  _ -> Nothing
