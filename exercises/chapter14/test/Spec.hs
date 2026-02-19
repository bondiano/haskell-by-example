{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.Aeson
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KM
import Data.ByteString.Lazy qualified as BL
import Data.Text (Text)
import Test.Hspec

import MySolutions
import TaskTracker

{- | Вспомогательная функция: создаёт JSON ByteString из пар ключ-значение.
Это обходит проблему с Cyrillic в OverloadedStrings для ByteString.
-}
mkJson :: [(Text, Value)] -> BL.ByteString
mkJson pairs = encode (object [Key.fromText k .= v | (k, v) <- pairs])

main :: IO ()
main = hspec $ do
  -- ===========================================================
  -- Упражнение 1: Автоматические инстансы Priority и Status
  -- ===========================================================
  describe "Упражнение 1: Priority ToJSON/FromJSON" $ do
    it "round-trip для Low" $
      eitherDecode (encode Low) `shouldBe` (Right Low :: Either String Priority)

    it "round-trip для Medium" $
      eitherDecode (encode Medium) `shouldBe` (Right Medium :: Either String Priority)

    it "round-trip для High" $
      eitherDecode (encode High) `shouldBe` (Right High :: Either String Priority)

  describe "Упражнение 1: Status ToJSON/FromJSON" $ do
    it "round-trip для Todo" $
      eitherDecode (encode Todo) `shouldBe` (Right Todo :: Either String Status)

    it "round-trip для InProgress" $
      eitherDecode (encode InProgress) `shouldBe` (Right InProgress :: Either String Status)

    it "round-trip для Done" $
      eitherDecode (encode Done) `shouldBe` (Right Done :: Either String Status)

  -- ===========================================================
  -- Упражнение 2: Ручной инстанс Task
  -- ===========================================================
  describe "Упражнение 2: Task ToJSON/FromJSON (ручной)" $ do
    let task = Task "Buy milk" High Todo

    it "round-trip для Task" $
      eitherDecode (encode task) `shouldBe` Right task

    it "JSON использует короткий ключ \"title\"" $ do
      let json = mkJson [("title", String "Test"), ("priority", String "Low"), ("status", String "Done")]
      eitherDecode json `shouldBe` Right (Task "Test" Low Done)

    it "JSON с ключом \"taskTitle\" НЕ парсится (ручные ключи)" $ do
      let json =
            mkJson [("taskTitle", String "Test"), ("taskPriority", String "Low"), ("taskStatus", String "Done")]
      case eitherDecode json :: Either String Task of
        Left _ -> return ()
        Right _ -> expectationFailure "Expected error for Generic-style keys"

    it "значение по умолчанию для priority — Medium" $ do
      let json = mkJson [("title", String "Task")]
      eitherDecode json `shouldBe` Right (Task "Task" Medium Todo)

    it "значение по умолчанию для status — Todo" $ do
      let json = mkJson [("title", String "Task"), ("priority", String "High")]
      eitherDecode json `shouldBe` Right (Task "Task" High Todo)

    it "все поля указаны — значения по умолчанию не используются" $ do
      let json = mkJson [("title", String "Task"), ("priority", String "Low"), ("status", String "Done")]
      eitherDecode json `shouldBe` Right (Task "Task" Low Done)

    it "round-trip сохраняет кириллицу" $ do
      let taskRu = Task "Купить молоко" Medium InProgress
      eitherDecode (encode taskRu) `shouldBe` Right taskRu

    it "ToJSON использует ключ \"title\", а не \"taskTitle\"" $ do
      let encoded = encode task
      case eitherDecode encoded :: Either String Value of
        Right (Object obj) -> do
          KM.member "title" obj `shouldBe` True
          KM.member "taskTitle" obj `shouldBe` False
        _ -> expectationFailure "Expected JSON object"

  -- ===========================================================
  -- Упражнения 3-4: Person
  -- ===========================================================
  describe "Упражнения 3-4: Person" $ do
    let alice = Person "Alice" 30
    let bob = Person "Bob" 25

    it "round-trip для Person" $
      eitherDecode (encode alice) `shouldBe` Right alice

    it "encodePerson сериализует в JSON" $
      (eitherDecode (encodePerson alice) :: Either String Person)
        `shouldBe` Right alice

    it "decodePerson десериализует из JSON" $
      decodePerson (encode bob) `shouldBe` Right bob

    it "decodePerson возвращает Left при невалидном JSON" $
      case decodePerson (encode (object ["invalid" .= True])) of
        Left _ -> return ()
        Right _ -> expectationFailure "Expected Left for invalid JSON"

    it "decodePerson возвращает Left при пустом вводе" $
      case decodePerson "" of
        Left _ -> return ()
        Right _ -> expectationFailure "Expected Left for empty input"

    it "round-trip с кириллицей" $ do
      let person = Person "Алиса" 30
      decodePerson (encodePerson person) `shouldBe` Right person

  -- ===========================================================
  -- Упражнение 5: Config с значениями по умолчанию
  -- ===========================================================
  describe "Упражнение 5: Config FromJSON" $ do
    it "все поля указаны" $ do
      let json =
            mkJson
              [ ("configName", String "myapp")
              , ("configDebug", Bool True)
              , ("configMaxRetries", Number 5)
              ]
      eitherDecode json `shouldBe` Right (Config "myapp" True 5)

    it "debug по умолчанию False" $ do
      let json =
            mkJson
              [ ("configName", String "myapp")
              , ("configMaxRetries", Number 5)
              ]
      eitherDecode json `shouldBe` Right (Config "myapp" False 5)

    it "maxRetries по умолчанию 3" $ do
      let json =
            mkJson
              [ ("configName", String "myapp")
              , ("configDebug", Bool True)
              ]
      eitherDecode json `shouldBe` Right (Config "myapp" True 3)

    it "оба значения по умолчанию" $ do
      let json = mkJson [("configName", String "myapp")]
      eitherDecode json `shouldBe` Right (Config "myapp" False 3)

    it "round-trip сохраняет все поля" $
      let config = Config "test" True 10
       in eitherDecode (encode config) `shouldBe` Right config

    it "отсутствие name — ошибка" $ do
      let json = mkJson [("configDebug", Bool True)]
      case eitherDecode json :: Either String Config of
        Left _ -> return ()
        Right _ -> expectationFailure "Expected error when configName is missing"

  -- ===========================================================
  -- Упражнение 6: encodeTask и decodeTask
  -- ===========================================================
  describe "Упражнение 6: encodeTask и decodeTask" $ do
    let task = Task "Buy milk" High Todo

    it "round-trip через encode/decode" $
      decodeTask (encodeTask task) `shouldBe` Right task

    it "decodeTask с минимальным JSON (только title)" $ do
      let json = mkJson [("title", String "Test")]
      decodeTask json `shouldBe` Right (Task "Test" Medium Todo)

    it "decodeTask возвращает Left при невалидном JSON" $
      case decodeTask "not json" of
        Left _ -> return ()
        Right _ -> expectationFailure "Expected Left for invalid JSON"

    it "round-trip с кириллицей" $ do
      let taskRu = Task "Купить молоко" High Todo
      decodeTask (encodeTask taskRu) `shouldBe` Right taskRu
