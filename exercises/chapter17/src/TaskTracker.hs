module TaskTracker where

import Data.Aeson (FromJSON (..), ToJSON (..), object, withObject, (.!=), (.:), (.:?), (.=))
import Data.Text (Text)
import Data.Text qualified as T
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

instance ToJSON Priority
instance FromJSON Priority
instance ToJSON Status
instance FromJSON Status
instance ToJSON Task
instance FromJSON Task

data TaskResponse = TaskResponse
  { responseId :: Int
  , responseTitle :: Text
  , responsePriority :: Text
  , responseStatus :: Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON TaskResponse where
  toJSON TaskResponse{..} =
    object
      [ "id" .= responseId
      , "title" .= responseTitle
      , "priority" .= responsePriority
      , "status" .= responseStatus
      ]
