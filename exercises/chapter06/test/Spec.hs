module Main where

import MySolutions
import TaskTracker
import Test.Hspec

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)

main :: IO ()
main = hspec $ do
  -- Тестовые данные
  let task1 = Task "Релиз" "Подготовить релиз v2.0" High Todo (Set.fromList ["dev", "urgent"])
      task2 = Task "Документация" "Обновить README и API docs" Medium InProgress (Set.fromList ["docs"])
      task3 = Task "Рефакторинг" "Переписать парсер на Megaparsec" Low Done (Set.fromList ["dev", "tech-debt"])
      store =
        addTask 1 task1
          . addTask 2 task2
          . addTask 3 task3
          $ emptyStore

  describe "Упражнение 1: storeSize" $ do
    it "возвращает 0 для пустого хранилища" $
      storeSize emptyStore `shouldBe` 0
    it "возвращает 3 для хранилища из трёх задач" $
      storeSize store `shouldBe` 3
    it "возвращает 1 после добавления одной задачи" $
      storeSize (addTask 1 task1 emptyStore) `shouldBe` 1

  describe "Упражнение 2: updateTaskStatus" $ do
    it "обновляет статус существующей задачи" $ do
      let updated = updateTaskStatus 1 Done store
      fmap taskStatus (lookupTask 1 updated) `shouldBe` Just Done
    it "не меняет другие задачи" $ do
      let updated = updateTaskStatus 1 Done store
      fmap taskStatus (lookupTask 2 updated) `shouldBe` Just InProgress
    it "не падает при обновлении несуществующей задачи" $ do
      let updated = updateTaskStatus 999 Done store
      storeSize updated `shouldBe` 3

  describe "Упражнение 3: findByTag" $ do
    it "находит задачи с тегом \"dev\"" $
      length (findByTag "dev" store) `shouldBe` 2
    it "находит задачи с тегом \"docs\"" $
      length (findByTag "docs" store) `shouldBe` 1
    it "возвращает пустой список для несуществующего тега" $
      findByTag "nonexistent" store `shouldBe` []
    it "находит задачи с тегом \"urgent\"" $ do
      let results = findByTag "urgent" store
      length results `shouldBe` 1
      taskTitle (head results) `shouldBe` "Релиз"

  describe "Упражнение 4: invertMap" $ do
    it "инвертирует простое отображение" $ do
      let m = Map.fromList [("a" :: String, 1 :: Int), ("b", 2), ("c", 3)]
      invertMap m `shouldBe` Map.fromList [(1, "a"), (2, "b"), (3, "c")]
    it "инвертирует пустое отображение" $
      invertMap (Map.empty :: Map String Int) `shouldBe` Map.empty
    it "при дублирующихся значениях сохраняет одно из них" $ do
      let m = Map.fromList [("a" :: String, 1 :: Int), ("b", 1)]
          result = invertMap m
      Map.size result `shouldBe` 1
      Map.lookup 1 result `shouldSatisfy` \v -> v == Just "a" || v == Just "b"

  describe "Упражнение 5: commonElements" $ do
    it "находит общие элементы двух списков" $
      commonElements [1 :: Int, 2, 3, 4] [3, 4, 5, 6] `shouldBe` [3, 4]
    it "возвращает пустой список при отсутствии общих элементов" $
      commonElements [1 :: Int, 2] [3, 4] `shouldBe` []
    it "работает с пустым списком" $
      commonElements ([] :: [Int]) [1, 2, 3] `shouldBe` []
    it "убирает дубликаты" $
      commonElements [1 :: Int, 1, 2, 2] [1, 2, 2, 3] `shouldBe` [1, 2]

  describe "Упражнение 6: wordFrequency" $ do
    it "считает частоту слов" $ do
      let result = wordFrequency "hello world hello"
      Map.lookup "hello" result `shouldBe` Just 2
      Map.lookup "world" result `shouldBe` Just 1
    it "приводит слова к нижнему регистру" $ do
      let result = wordFrequency "Hello HELLO hello"
      Map.lookup "hello" result `shouldBe` Just 3
    it "возвращает пустое отображение для пустой строки" $
      wordFrequency "" `shouldBe` Map.empty
    it "корректно работает с одним словом" $
      wordFrequency "Haskell" `shouldBe` Map.fromList [("haskell", 1)]
