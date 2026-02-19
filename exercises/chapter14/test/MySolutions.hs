module MySolutions where

import Data.Aeson
import Data.Aeson.Types (Parser)
import Data.ByteString.Lazy qualified as BL
import Data.Text (Text)
import GHC.Generics (Generic)

import TaskTracker

-- ============================================================
-- Упражнение 1: Автоматические инстансы для Priority и Status
--
-- Используйте Generic-деривацию для ToJSON и FromJSON.
-- Для типов, имеющих deriving Generic, достаточно написать
-- пустые инстансы.
-- ============================================================

instance ToJSON Priority
instance FromJSON Priority

instance ToJSON Status
instance FromJSON Status

-- ============================================================
-- Упражнение 2: Ручной инстанс для Task
--
-- Напишите РУЧНЫЕ инстансы ToJSON и FromJSON для Task
-- с короткими ключами: "title", "priority", "status".
--
-- FromJSON: при отсутствии "priority" — Medium,
-- при отсутствии "status" — Todo.
--
-- Подсказки:
--   ToJSON: object ["title" .= title, ...]
--   FromJSON: withObject "Task" $ \v -> Task
--     <$> v .:  "title"
--     <*> v .:? "priority" .!= Medium
--     <*> v .:? "status"   .!= Todo
-- ============================================================

instance ToJSON Task where
  toJSON = undefined

instance FromJSON Task where
  parseJSON = undefined

-- ============================================================
-- Упражнение 3: Тип Person с Generic-инстансами
--
-- Определите тип Person с полями personName (Text) и personAge (Int).
-- Используйте Generic-деривацию для ToJSON и FromJSON.
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
--
-- encodePerson: сериализация Person в ByteString (через encode).
-- decodePerson: десериализация из ByteString (через eitherDecode).
-- ============================================================

{- | Сериализация Person в JSON.

>>> encodePerson (Person "Алиса" 30)
"{\"personName\":\"Алиса\",\"personAge\":30}"
-}
encodePerson :: Person -> BL.ByteString
encodePerson = undefined

{- | Десериализация Person из JSON.

>>> decodePerson "{\"personName\":\"Боб\",\"personAge\":25}"
Right (Person {personName = "Боб", personAge = 25})
-}
decodePerson :: BL.ByteString -> Either String Person
decodePerson = undefined

-- ============================================================
-- Упражнение 5: Тип Config с ручным FromJSON
--
-- Определите тип Config:
--   configName       :: Text   (обязательное)
--   configDebug      :: Bool   (по умолчанию False)
--   configMaxRetries :: Int    (по умолчанию 3)
--
-- ToJSON — автоматический (Generic).
-- FromJSON — ручной, с значениями по умолчанию.
--
-- Подсказка: используйте .:? с .!= для значений по умолчанию:
--   v .:? "configDebug" .!= False
-- ============================================================

data Config = Config
  { configName :: Text
  , configDebug :: Bool
  , configMaxRetries :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON Config

instance FromJSON Config where
  parseJSON = undefined

-- ============================================================
-- Упражнение 6: encodeTask и decodeTask
--
-- Сериализация и десериализация Task.
-- Используйте ваши ручные инстансы из упражнения 2.
-- ============================================================

{- | Сериализация Task в JSON.

>>> encodeTask (Task "Купить молоко" High Todo)
"{\"title\":\"Купить молоко\",\"priority\":\"High\",\"status\":\"Todo\"}"
-}
encodeTask :: Task -> BL.ByteString
encodeTask = undefined

{- | Десериализация Task из JSON.

>>> decodeTask "{\"title\":\"Тест\"}"
Right (Task {taskTitle = "Тест", taskPriority = Medium, taskStatus = Todo})
-}
decodeTask :: BL.ByteString -> Either String Task
decodeTask = undefined
