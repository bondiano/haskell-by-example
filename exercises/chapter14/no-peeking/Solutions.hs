module Solutions where

import Data.Aeson
import Data.Aeson.Types (Parser)
import Data.ByteString.Lazy qualified as BL
import Data.Text (Text)
import GHC.Generics (Generic)

import TaskTracker

-- ============================================================
-- Упражнение 1: Автоматические инстансы для Priority и Status
-- ============================================================

-- Generic-инстансы: просто пустые объявления, т.к. типы
-- уже имеют deriving Generic в TaskTracker.

instance ToJSON Priority
instance FromJSON Priority

instance ToJSON Status
instance FromJSON Status

-- ============================================================
-- Упражнение 2: Ручной инстанс для Task
-- ============================================================

-- Короткие ключи: "title", "priority", "status".
-- FromJSON: priority по умолчанию Medium, status — Todo.

instance ToJSON Task where
  toJSON (Task title priority status) =
    object
      [ "title" .= title
      , "priority" .= priority
      , "status" .= status
      ]

instance FromJSON Task where
  parseJSON = withObject "Task" $ \v ->
    Task
      <$> v .: "title"
      <*> v .:? "priority" .!= Medium
      <*> v .:? "status" .!= Todo

-- ============================================================
-- Упражнение 3: Тип Person с Generic-инстансами
-- ============================================================

data Person = Person
  { personName :: Text
  , personAge :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON Person
instance FromJSON Person

-- ============================================================
-- Упражнение 4: encodePerson и decodePerson
-- ============================================================

-- | Сериализация через encode из Data.Aeson.
encodePerson :: Person -> BL.ByteString
encodePerson = encode

-- | Десериализация через eitherDecode.
decodePerson :: BL.ByteString -> Either String Person
decodePerson = eitherDecode

-- ============================================================
-- Упражнение 5: Config с ручным FromJSON
-- ============================================================

data Config = Config
  { configName :: Text
  , configDebug :: Bool
  , configMaxRetries :: Int
  }
  deriving (Show, Eq, Generic)

-- ToJSON — автоматический.
instance ToJSON Config

-- FromJSON — ручной, с значениями по умолчанию.
instance FromJSON Config where
  parseJSON = withObject "Config" $ \v ->
    Config
      <$> v .: "configName"
      <*> v .:? "configDebug" .!= False
      <*> v .:? "configMaxRetries" .!= 3

-- ============================================================
-- Упражнение 6: encodeTask и decodeTask
-- ============================================================

-- | Сериализация Task (использует ручной ToJSON).
encodeTask :: Task -> BL.ByteString
encodeTask = encode

-- | Десериализация Task (использует ручной FromJSON).
decodeTask :: BL.ByteString -> Either String Task
decodeTask = eitherDecode
