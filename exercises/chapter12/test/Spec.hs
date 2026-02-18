module Main where

import Test.Hspec
import Control.Monad.State.Strict (gets)
import Data.Aeson (encode)
import qualified Data.ByteString.Lazy as BL
import Data.Map.Strict qualified as Map
import System.Directory (getTemporaryDirectory, removeFile)

import Game
import MySolutions

main :: IO ()
main = hspec $ do
  describe "runGame (предоставлено)" $ do
    it "запускает чистое вычисление" $ do
      let Right (room, _) = runGame exampleConfig initialState (gets playerRoom)
      room `shouldBe` "entrance"

  describe "look (упражнение 1)" $ do
    it "содержит описание комнаты" $ do
      let Right (desc, _) = runGame exampleConfig initialState look
      desc `shouldContain` "Вход в подземелье"

    it "содержит предметы комнаты" $ do
      let Right (desc, _) = runGame exampleConfig initialState look
      desc `shouldContain` "Лампа"

    it "содержит выходы" $ do
      let Right (desc, _) = runGame exampleConfig initialState look
      desc `shouldContain` "север"

    it "в пустой комнате показывает 'ничего'" $ do
      let state = initialState { roomItems = Map.empty }
      let Right (desc, _) = runGame exampleConfig state look
      desc `shouldContain` "ничего"

  describe "move (упражнение 2)" $ do
    it "перемещает на север" $ do
      let Right (_, st) = runGame exampleConfig initialState (move North)
      playerRoom st `shouldBe` "hall"

    it "возвращает сообщение о перемещении" $ do
      let Right (msg, _) = runGame exampleConfig initialState (move North)
      msg `shouldContain` "север"

    it "ошибка при невозможном направлении" $ do
      let result = runGame exampleConfig initialState (move East)
      result `shouldBe` Left (NoExit East)

    it "последовательные перемещения" $ do
      let game = move North >> move East
      let Right (_, st) = runGame exampleConfig initialState game
      playerRoom st `shouldBe` "treasury"

  describe "pickUp (упражнение 3)" $ do
    it "добавляет предмет в инвентарь" $ do
      let Right (_, st) = runGame exampleConfig initialState (pickUp Lamp)
      Lamp `elem` inventory st `shouldBe` True

    it "убирает предмет из комнаты" $ do
      let Right (_, st) = runGame exampleConfig initialState (pickUp Lamp)
      let items = Map.findWithDefault [] "entrance" (roomItems st)
      Lamp `elem` items `shouldBe` False

    it "возвращает сообщение" $ do
      let Right (msg, _) = runGame exampleConfig initialState (pickUp Lamp)
      msg `shouldContain` "Лампа"

    it "ошибка при отсутствии предмета" $ do
      let result = runGame exampleConfig initialState (pickUp Sword)
      result `shouldBe` Left (ItemNotFound Sword)

    it "подбор после перемещения" $ do
      let game = move North >> pickUp Sword
      let Right (_, st) = runGame exampleConfig initialState game
      Sword `elem` inventory st `shouldBe` True

  describe "useItem (упражнение 4)" $ do
    it "зелье восстанавливает здоровье" $ do
      let state = initialState { inventory = [Potion], playerHealth = 50 }
      let Right (_, st) = runGame exampleConfig state (useItem Potion)
      playerHealth st `shouldBe` 75

    it "здоровье не превышает 100" $ do
      let state = initialState { inventory = [Potion], playerHealth = 90 }
      let Right (_, st) = runGame exampleConfig state (useItem Potion)
      playerHealth st `shouldBe` 100

    it "предмет убирается из инвентаря" $ do
      let state = initialState { inventory = [Lamp, Sword] }
      let Right (_, st) = runGame exampleConfig state (useItem Lamp)
      Lamp `elem` inventory st `shouldBe` False
      Sword `elem` inventory st `shouldBe` True

    it "ошибка при отсутствии в инвентаре" $ do
      let result = runGame exampleConfig initialState (useItem Sword)
      result `shouldBe` Left (ItemNotFound Sword)

    it "полный сценарий: подобрать и использовать" $ do
      let game = do
            pickUp Lamp
            useItem Lamp
      let Right (msg, st) = runGame exampleConfig initialState game
      msg `shouldContain` "Лампа"
      Lamp `elem` inventory st `shouldBe` False

  describe "safeReadJSON (упражнение 5)" $ do
    it "читает валидный JSON-файл" $ do
      tmpDir <- getTemporaryDirectory
      let path = tmpDir <> "/hbe-ch12-test.json"
      BL.writeFile path (encode [1, 2, 3 :: Int])
      result <- safeReadJSON path :: IO (Either String [Int])
      result `shouldBe` Right [1, 2, 3]
      removeFile path

    it "возвращает Left для несуществующего файла" $ do
      result <- safeReadJSON "/nonexistent/path/file.json" :: IO (Either String [Int])
      case result of
        Left _  -> return ()
        Right _ -> expectationFailure "ожидался Left для несуществующего файла"

    it "возвращает Left для невалидного JSON" $ do
      tmpDir <- getTemporaryDirectory
      let path = tmpDir <> "/hbe-ch12-invalid.json"
      writeFile path "это не json"
      result <- safeReadJSON path :: IO (Either String [Int])
      case result of
        Left _  -> return ()
        Right _ -> expectationFailure "ожидался Left для невалидного JSON"
      removeFile path
