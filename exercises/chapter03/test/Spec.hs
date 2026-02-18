module Main where

import Test.Hspec
import Data.AddressBook
import MySolutions (findEntryByStreet, entryExists, removeDuplicates)

addressMoscow :: Address
addressMoscow = Address
  { street = "ул. Пушкина, 10"
  , city   = "Москва"
  , state  = "Москва"
  }

addressSpb :: Address
addressSpb = Address
  { street = "Невский пр., 28"
  , city   = "Санкт-Петербург"
  , state  = "Санкт-Петербург"
  }

ivan :: Entry
ivan = Entry
  { firstName = "Иван"
  , lastName  = "Петров"
  , address   = addressMoscow
  }

anna :: Entry
anna = Entry
  { firstName = "Анна"
  , lastName  = "Сидорова"
  , address   = addressSpb
  }

ivanDup :: Entry
ivanDup = Entry
  { firstName = "Иван"
  , lastName  = "Петров"
  , address   = addressSpb
  }

book :: AddressBook
book = insertEntry ivan $ insertEntry anna emptyBook

bookWithDup :: AddressBook
bookWithDup = insertEntry ivanDup book

main :: IO ()
main = hspec $ do
  describe "showEntry / showAddress" $ do
    it "форматирует адрес" $
      showAddress addressMoscow `shouldBe` "ул. Пушкина, 10, Москва, Москва"

    it "форматирует запись" $
      showEntry ivan `shouldBe` "Петров, Иван: ул. Пушкина, 10, Москва, Москва"

  describe "insertEntry / findEntry" $ do
    it "находит существующую запись" $
      findEntry "Иван" "Петров" book `shouldBe` Just ivan

    it "возвращает Nothing для несуществующей записи" $
      findEntry "Пётр" "Иванов" book `shouldBe` Nothing

  describe "findEntryByStreet" $ do
    it "находит запись по улице" $
      findEntryByStreet "Невский пр., 28" book `shouldBe` Just anna

    it "возвращает Nothing для несуществующей улицы" $
      findEntryByStreet "ул. Ленина, 1" book `shouldBe` Nothing

  describe "entryExists" $ do
    it "возвращает True для существующей записи" $
      entryExists "Анна" "Сидорова" book `shouldBe` True

    it "возвращает False для несуществующей записи" $
      entryExists "Пётр" "Иванов" book `shouldBe` False

  describe "removeDuplicates" $ do
    it "удаляет дубликаты по имени и фамилии" $
      length (removeDuplicates bookWithDup) `shouldBe` 2

    it "сохраняет первую запись из дубликатов" $
      removeDuplicates bookWithDup `shouldBe` [ivanDup, anna]

    it "не меняет книгу без дубликатов" $
      removeDuplicates book `shouldBe` book
