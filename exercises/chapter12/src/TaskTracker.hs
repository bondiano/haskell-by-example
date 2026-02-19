module TaskTracker where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map

newtype TaskId = TaskId Int
  deriving (Show, Eq, Ord)
  deriving newtype (Num)

data Priority = Low | Medium | High
  deriving (Show, Eq, Ord)

data Status = Todo | InProgress | Done
  deriving (Show, Eq, Ord)

data Task = Task
  { taskTitle :: String
  , taskPriority :: Priority
  , taskStatus :: Status
  }
  deriving (Show, Eq)

newtype TaskStore = TaskStore {unTaskStore :: Map TaskId Task}
  deriving (Show, Eq)

data AppError = TaskNotFound TaskId | InvalidInput String | AlreadyDone TaskId
  deriving (Show, Eq)

data AppConfig = AppConfig
  { defaultPriority :: Priority
  , maxTasks :: Int
  }
  deriving (Show, Eq)

data Command = AddCmd String | CompleteCmd TaskId
  deriving (Show, Eq)

emptyStore :: TaskStore
emptyStore = TaskStore Map.empty

addTask :: TaskId -> Task -> TaskStore -> TaskStore
addTask tid task (TaskStore m) = TaskStore (Map.insert tid task m)

lookupTask :: TaskId -> TaskStore -> Maybe Task
lookupTask tid (TaskStore m) = Map.lookup tid m

{- | Вспомогательная функция: преобразует Maybe в Either.
Если Nothing, возвращает Left с указанной ошибкой.
-}
note :: e -> Maybe a -> Either e a
note e Nothing = Left e
note _ (Just a) = Right a

exampleStore :: TaskStore
exampleStore =
  TaskStore $
    Map.fromList
      [ (TaskId 1, Task "Купить молоко" Medium Todo)
      , (TaskId 2, Task "Написать отчёт" High InProgress)
      , (TaskId 3, Task "Полить цветы" Low Done)
      ]
