module TaskTracker where

import Data.Text (Text)

data Priority = Low | Medium | High
  deriving (Show, Eq, Ord)

data Status = Todo | InProgress | Done
  deriving (Show, Eq, Ord)

data Task = Task
  { taskTitle :: Text
  , taskDescription :: Text
  , taskPriority :: Priority
  , taskStatus :: Status
  }
  deriving (Show, Eq)
