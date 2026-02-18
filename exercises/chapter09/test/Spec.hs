module Main where

import Test.Hspec
import Data.IORef
import AddressBook
import MySolutions

main :: IO ()
main = hspec $ do
  describe "findByName (предоставлено)" $ do
    it "находит по точному имени" $
      length (findByName "Иван Петров" exampleBook) `shouldBe` 1

    it "не находит отсутствующее имя" $
      findByName "Нет Такого" exampleBook `shouldBe` []

  describe "deleteEntry (упражнение 1)" $ do
    it "удаляет запись по имени" $
      length (deleteEntry "Иван Петров" exampleBook) `shouldBe` 2

    it "удалённого имени больше нет" $
      findByName "Иван Петров" (deleteEntry "Иван Петров" exampleBook)
        `shouldBe` []

    it "не меняет книгу при отсутствии имени" $
      deleteEntry "Нет Такого" exampleBook `shouldBe` exampleBook

    it "удаляет все записи с одинаковым именем" $ do
      let book = [Entry "A" "1" "a", Entry "B" "2" "b", Entry "A" "3" "c"]
      deleteEntry "A" book `shouldBe` [Entry "B" "2" "b"]

  describe "saveAddressBook / loadAddressBook (упражнение 2)" $ do
    it "round-trip: save и load" $ do
      let book = [Entry "Тест" "123" "test@example.com"]
      let path = "/tmp/hbe-ch08-test.dat"
      saveAddressBook path book
      loaded <- loadAddressBook path
      loaded `shouldBe` book

    it "round-trip с несколькими записями" $ do
      let path = "/tmp/hbe-ch08-test2.dat"
      saveAddressBook path exampleBook
      loaded <- loadAddressBook path
      loaded `shouldBe` exampleBook

    it "round-trip с пустой книгой" $ do
      let path = "/tmp/hbe-ch08-test3.dat"
      saveAddressBook path []
      loaded <- loadAddressBook path
      loaded `shouldBe` []

  describe "fuzzySearch (упражнение 3)" $ do
    it "находит по подстроке имени" $
      length (fuzzySearch "Петр" exampleBook) `shouldBe` 1

    it "регистронезависимый поиск" $
      length (fuzzySearch "мария" exampleBook) `shouldBe` 1

    it "пустой запрос — все записи" $
      fuzzySearch "" exampleBook `shouldBe` exampleBook

    it "нет совпадений — пустой список" $
      fuzzySearch "xyz" exampleBook `shouldBe` []

    it "находит несколько совпадений" $ do
      let book = [Entry "Иванов" "1" "a", Entry "Иванова" "2" "b", Entry "Петров" "3" "c"]
      length (fuzzySearch "иван" book) `shouldBe` 2

  describe "recordState / undoLastChange (упражнение 4)" $ do
    it "undo возвращает предыдущее состояние" $ do
      ref <- newIORef ([] :: [AddressBook])
      let s1 = [Entry "A" "1" "a"]
      let s2 = [Entry "A" "1" "a", Entry "B" "2" "b"]
      recordState ref s1
      recordState ref s2
      result <- undoLastChange ref
      result `shouldBe` Just s1

    it "undo пустой истории возвращает Nothing" $ do
      ref <- newIORef ([] :: [AddressBook])
      result <- undoLastChange ref
      result `shouldBe` Nothing

    it "undo единственного состояния возвращает Nothing" $ do
      ref <- newIORef ([] :: [AddressBook])
      recordState ref [Entry "A" "1" "a"]
      result <- undoLastChange ref
      result `shouldBe` Nothing

    it "двойной undo" $ do
      ref <- newIORef ([] :: [AddressBook])
      let s1 = [Entry "A" "1" "a"]
      let s2 = s1 <> [Entry "B" "2" "b"]
      let s3 = s2 <> [Entry "C" "3" "c"]
      recordState ref s1
      recordState ref s2
      recordState ref s3
      r1 <- undoLastChange ref
      r1 `shouldBe` Just s2
      r2 <- undoLastChange ref
      r2 `shouldBe` Just s1
