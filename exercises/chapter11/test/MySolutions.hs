module MySolutions where

import Data.Aeson
import Data.ByteString.Lazy (ByteString)
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text as T
import Contact (Contact(..))

-- Упражнение 1: кодирование и декодирование JSON
--
-- Используйте encode и decode из Data.Aeson.

encodeContacts :: [Contact] -> ByteString
encodeContacts = undefined

decodeContacts :: ByteString -> Maybe [Contact]
decodeContacts = undefined

-- Упражнение 2: ручные экземпляры ToJSON / FromJSON
--
-- Определите экземпляры для Movie с ключами "title", "year", "rating".
-- Используйте object, (.=) для ToJSON и withObject, (.:) для FromJSON.

data Movie = Movie
  { movieTitle  :: String
  , movieYear   :: Int
  , movieRating :: Double
  } deriving stock (Show, Eq)

instance ToJSON Movie where
  toJSON = undefined

instance FromJSON Movie where
  parseJSON = undefined

encodeMovie :: Movie -> ByteString
encodeMovie = undefined

decodeMovie :: ByteString -> Maybe Movie
decodeMovie = undefined

-- Упражнение 3: JSON-файлы
--
-- Сохраните значение в файл как JSON и загрузите обратно.

saveJSON :: ToJSON a => FilePath -> a -> IO ()
saveJSON = undefined

loadJSON :: FromJSON a => FilePath -> IO (Either String a)
loadJSON = undefined

-- Упражнение 4: опциональные поля и значения по умолчанию
--
-- Напишите экземпляры ToJSON / FromJSON для Config.
-- JSON: {"host": "...", "port": 8080, "debug": true, "log_file": "..."}
-- Поле "debug" по умолчанию False (если отсутствует).
-- Поле "log_file" опционально (Nothing, если отсутствует).
--
-- Используйте (.:?) для опциональных полей и (.!=) для значений по умолчанию.

data Config = Config
  { configHost    :: String
  , configPort    :: Int
  , configDebug   :: Bool
  , configLogFile :: Maybe String
  } deriving stock (Show, Eq)

instance ToJSON Config where
  toJSON = undefined

instance FromJSON Config where
  parseJSON = undefined

encodeConfig :: Config -> ByteString
encodeConfig = undefined

decodeConfig :: ByteString -> Maybe Config
decodeConfig = undefined

-- Упражнение 5: нормализация текста
--
-- Приведите к нижнему регистру и уберите лишние пробелы.
-- Используйте T.toLower, T.words, T.unwords из Data.Text.

normalizeText :: T.Text -> T.Text
normalizeText = undefined
