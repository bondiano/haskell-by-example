module TaskTracker where

import Data.Text (Text)
import GHC.Generics (Generic)

data Priority = Low | Medium | High
  deriving (Show, Eq, Ord, Generic)

data Status = Todo | InProgress | Done
  deriving (Show, Eq, Ord, Generic)

data Task = Task
  { taskTitle :: Text
  , taskPriority :: Priority
  , taskStatus :: Status
  }
  deriving (Show, Eq, Generic)
