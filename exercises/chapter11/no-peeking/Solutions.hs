module Solutions where

import Data.Aeson
import Data.ByteString.Lazy (ByteString)
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text as T
import Contact (Contact(..))

-- Упражнение 1: кодирование и декодирование JSON

encodeContacts :: [Contact] -> ByteString
encodeContacts = encode

decodeContacts :: ByteString -> Maybe [Contact]
decodeContacts = decode

-- Упражнение 2: ручные экземпляры ToJSON / FromJSON

data Movie = Movie
  { movieTitle  :: String
  , movieYear   :: Int
  , movieRating :: Double
  } deriving stock (Show, Eq)

instance ToJSON Movie where
  toJSON Movie{..} = object
    [ "title"  .= movieTitle
    , "year"   .= movieYear
    , "rating" .= movieRating
    ]

instance FromJSON Movie where
  parseJSON = withObject "Movie" $ \o -> Movie
    <$> o .: "title"
    <*> o .: "year"
    <*> o .: "rating"

encodeMovie :: Movie -> ByteString
encodeMovie = encode

decodeMovie :: ByteString -> Maybe Movie
decodeMovie = decode

-- Упражнение 3: JSON-файлы

saveJSON :: ToJSON a => FilePath -> a -> IO ()
saveJSON path value = BL.writeFile path (encode value)

loadJSON :: FromJSON a => FilePath -> IO (Either String a)
loadJSON path = eitherDecode <$> BL.readFile path

-- Упражнение 4: опциональные поля и значения по умолчанию

data Config = Config
  { configHost    :: String
  , configPort    :: Int
  , configDebug   :: Bool
  , configLogFile :: Maybe String
  } deriving stock (Show, Eq)

instance ToJSON Config where
  toJSON Config{..} = object
    [ "host"     .= configHost
    , "port"     .= configPort
    , "debug"    .= configDebug
    , "log_file" .= configLogFile
    ]

instance FromJSON Config where
  parseJSON = withObject "Config" $ \o -> Config
    <$> o .:  "host"
    <*> o .:  "port"
    <*> o .:? "debug"    .!= False
    <*> o .:? "log_file"

encodeConfig :: Config -> ByteString
encodeConfig = encode

decodeConfig :: ByteString -> Maybe Config
decodeConfig = decode

-- Упражнение 5: нормализация текста

normalizeText :: T.Text -> T.Text
normalizeText = T.unwords . T.words . T.toLower
