module Main where

import Test.Hspec
import Data.Aeson (decode, encode, object, (.=), Value(..))
import Data.ByteString.Lazy (ByteString)
import qualified Data.Text as T
import System.Directory (removeFile, getTemporaryDirectory)
import Contact
import FFIExample qualified
import MySolutions

main :: IO ()
main = hspec $ do
  describe "FFIExample (предоставлено)" $ do
    it "cAbs вычисляет абсолютное значение" $ do
      FFIExample.cAbs (-42) `shouldBe` 42

    it "cStrlen вычисляет длину строки" $ do
      len <- FFIExample.cStrlen "hello"
      len `shouldBe` 5

  describe "encodeContacts / decodeContacts (упражнение 1)" $ do
    it "round-trip для списка контактов" $ do
      let contacts = exampleContacts
      decodeContacts (encodeContacts contacts) `shouldBe` Just contacts

    it "пустой список" $ do
      decodeContacts (encodeContacts []) `shouldBe` Just []

    it "один контакт" $ do
      let contacts = [Contact "Тест" "123" "test@example.com"]
      decodeContacts (encodeContacts contacts) `shouldBe` Just contacts

  describe "Movie — ручные экземпляры (упражнение 2)" $ do
    it "round-trip" $ do
      let movie = Movie "Начало" 2010 8.8
      decodeMovie (encodeMovie movie) `shouldBe` Just movie

    it "парсит JSON с ключами title, year, rating" $ do
      let json = encode (object
            [ "title"  .= ("Тест" :: String)
            , "year"   .= (2020 :: Int)
            , "rating" .= (7.5 :: Double)
            ])
      decodeMovie json `shouldBe` Just (Movie "Тест" 2020 7.5)

    it "не парсит JSON с ключами movieTitle и т.д." $ do
      let json = encode (object
            [ "movieTitle"  .= ("Тест" :: String)
            , "movieYear"   .= (2020 :: Int)
            , "movieRating" .= (7.5 :: Double)
            ])
      decodeMovie json `shouldBe` Nothing

  describe "saveJSON / loadJSON (упражнение 3)" $ do
    it "round-trip с файлом" $ do
      tmpDir <- getTemporaryDirectory
      let path = tmpDir <> "/hbe-ch10-test.json"
      saveJSON path exampleContacts
      result <- loadJSON path
      result `shouldBe` Right exampleContacts
      removeFile path

    it "round-trip с пустым списком" $ do
      tmpDir <- getTemporaryDirectory
      let path = tmpDir <> "/hbe-ch10-test2.json"
      saveJSON path ([] :: [Contact])
      result <- loadJSON path
      result `shouldBe` Right ([] :: [Contact])
      removeFile path

    it "невалидный JSON возвращает Left" $ do
      tmpDir <- getTemporaryDirectory
      let path = tmpDir <> "/hbe-ch10-test3.json"
      writeFile path "это не json"
      result <- loadJSON path :: IO (Either String [Contact])
      case result of
        Left _  -> return ()
        Right _ -> expectationFailure "ожидался Left для невалидного JSON"
      removeFile path

  describe "Config — опциональные поля (упражнение 4)" $ do
    it "round-trip полного конфига" $ do
      let config = Config "localhost" 8080 True (Just "/var/log/app.log")
      decodeConfig (encodeConfig config) `shouldBe` Just config

    it "debug по умолчанию False" $ do
      let json = encode (object
            [ "host" .= ("localhost" :: String)
            , "port" .= (8080 :: Int)
            ])
      decodeConfig json `shouldBe` Just (Config "localhost" 8080 False Nothing)

    it "log_file опционален" $ do
      let json = encode (object
            [ "host"  .= ("localhost" :: String)
            , "port"  .= (8080 :: Int)
            , "debug" .= True
            ])
      decodeConfig json `shouldBe` Just (Config "localhost" 8080 True Nothing)

    it "log_file null → Nothing" $ do
      let json = encode (object
            [ "host"     .= ("localhost" :: String)
            , "port"     .= (8080 :: Int)
            , "log_file" .= (Nothing :: Maybe String)
            ])
      decodeConfig json `shouldBe` Just (Config "localhost" 8080 False Nothing)

  describe "normalizeText (упражнение 5)" $ do
    it "приводит к нижнему регистру и убирает лишние пробелы" $
      normalizeText "  Hello   World  " `shouldBe` "hello world"

    it "обрабатывает пустую строку" $
      normalizeText "" `shouldBe` ""

    it "обрабатывает строку из пробелов" $
      normalizeText "   " `shouldBe` ""

    it "одно слово с пробелами вокруг" $
      normalizeText "  HELLO  " `shouldBe` "hello"

    it "уже нормализованная строка" $
      normalizeText "hello world" `shouldBe` "hello world"

    it "табуляции и множественные пробелы" $
      normalizeText "  one   two\tthree  " `shouldBe` "one two three"
