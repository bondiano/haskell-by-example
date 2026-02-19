module Main where

import AddressBook
import MySolutions (
  describeStatus,
  describeTasks,
  entryExists,
  findEntryByStreet,
  isUrgent,
  nextStatus,
  removeDuplicates,
 )
import TaskTracker
import Test.Hspec

main :: IO ()
main = hspec $ do
  -- Тесты адресной книги
  describe "findEntryByStreet" $ do
    it "находит запись по улице" $
      fmap firstName (findEntryByStreet "123 Main St" exampleBook)
        `shouldBe` Just "John"

    it "находит другую запись по улице" $
      fmap firstName (findEntryByStreet "456 Oak Ave" exampleBook)
        `shouldBe` Just "Jane"

    it "возвращает Nothing для несуществующей улицы" $
      findEntryByStreet "999 Unknown Rd" exampleBook `shouldBe` Nothing

    it "возвращает Nothing для пустой книги" $
      findEntryByStreet "123 Main St" [] `shouldBe` Nothing

  describe "entryExists" $ do
    it "возвращает True для существующей записи" $
      entryExists "John" "Smith" exampleBook `shouldBe` True

    it "возвращает True для другой существующей записи" $
      entryExists "Jane" "Doe" exampleBook `shouldBe` True

    it "возвращает False для несуществующей записи" $
      entryExists "Bob" "Jones" exampleBook `shouldBe` False

    it "возвращает False для пустой книги" $
      entryExists "John" "Smith" [] `shouldBe` False

  describe "removeDuplicates" $ do
    it "удаляет дубликаты по имени и фамилии" $
      length (removeDuplicates exampleBook) `shouldBe` 2

    it "сохраняет первое вхождение" $ do
      let result = removeDuplicates exampleBook
      case findEntryByStreet "123 Main St" result of
        Just e -> firstName e `shouldBe` "John"
        Nothing -> expectationFailure "Первая запись John Smith должна остаться"

    it "не меняет книгу без дубликатов" $ do
      let book = [Entry "A" "B" (Address "1" "2" "3")]
      removeDuplicates book `shouldBe` book

    it "возвращает пустой список для пустого входа" $
      removeDuplicates [] `shouldBe` []

  -- Тесты паттерн-матчинга по статусу
  describe "describeStatus" $ do
    it "описывает Todo" $
      describeStatus Todo `shouldBe` "[ ] К выполнению"

    it "описывает InProgress" $
      describeStatus InProgress `shouldBe` "[~] В работе"

    it "описывает Done" $
      describeStatus Done `shouldBe` "[x] Готово"

  describe "isUrgent" $ do
    it "True для High + Todo" $
      isUrgent (Task "A" "" High Todo) `shouldBe` True

    it "True для High + InProgress" $
      isUrgent (Task "A" "" High InProgress) `shouldBe` True

    it "False для High + Done" $
      isUrgent (Task "A" "" High Done) `shouldBe` False

    it "False для Medium + Todo" $
      isUrgent (Task "A" "" Medium Todo) `shouldBe` False

    it "False для Low + Todo" $
      isUrgent (Task "A" "" Low Todo) `shouldBe` False

  describe "nextStatus" $ do
    it "Todo переходит в InProgress" $
      nextStatus Todo `shouldBe` InProgress

    it "InProgress переходит в Done" $
      nextStatus InProgress `shouldBe` Done

    it "Done остаётся Done" $
      nextStatus Done `shouldBe` Done

  describe "describeTasks" $ do
    it "описывает exampleTasks" $
      describeTasks exampleTasks `shouldBe` "4 задач(и), из них 2 срочных"

    it "описывает пустой список" $
      describeTasks [] `shouldBe` "0 задач(и), из них 0 срочных"

    it "описывает список без срочных" $ do
      let tasks = [Task "A" "" Low Todo, Task "B" "" Medium Done]
      describeTasks tasks `shouldBe` "2 задач(и), из них 0 срочных"

    it "описывает список только из срочных" $ do
      let tasks = [Task "A" "" High Todo, Task "B" "" High InProgress]
      describeTasks tasks `shouldBe` "2 задач(и), из них 2 срочных"
