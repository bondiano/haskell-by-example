module Main where

import Test.Hspec
import Database.Persist
import Database.Persist.Sql (toSqlKey)
import Data.Text (Text)

import Data.Todo
import MySolutions

main :: IO ()
main = hspec $ do
  describe "insertTodo (упражнение 1)" $ do
    it "вставляет задачу с completed = False" $ withTestDb $ \pool -> do
      todoId <- runDB pool $ insertTodo "Купить молоко"
      mTodo <- runDB pool $ get todoId
      mTodo `shouldBe` Just (Todo "Купить молоко" False)

    it "вставляет несколько задач" $ withTestDb $ \pool -> do
      _ <- runDB pool $ insertTodo "Задача 1"
      _ <- runDB pool $ insertTodo "Задача 2"
      _ <- runDB pool $ insertTodo "Задача 3"
      todos <- runDB pool $ selectList ([] :: [Filter Todo]) []
      length todos `shouldBe` 3

    it "возвращает уникальный ключ" $ withTestDb $ \pool -> do
      id1 <- runDB pool $ insertTodo "Первая"
      id2 <- runDB pool $ insertTodo "Вторая"
      id1 `shouldSatisfy` (/= id2)

  describe "toggleTodo (упражнение 2)" $ do
    it "переключает False -> True" $ withTestDb $ \pool -> do
      todoId <- runDB pool $ insertTodo "Задача"
      runDB pool $ toggleTodo todoId
      mTodo <- runDB pool $ get todoId
      fmap todoCompleted mTodo `shouldBe` Just True

    it "переключает True -> False" $ withTestDb $ \pool -> do
      todoId <- runDB pool $ insertTodo "Задача"
      runDB pool $ toggleTodo todoId
      runDB pool $ toggleTodo todoId
      mTodo <- runDB pool $ get todoId
      fmap todoCompleted mTodo `shouldBe` Just False

    it "не меняет другие задачи" $ withTestDb $ \pool -> do
      id1 <- runDB pool $ insertTodo "Задача 1"
      id2 <- runDB pool $ insertTodo "Задача 2"
      runDB pool $ toggleTodo id1
      mTodo2 <- runDB pool $ get id2
      fmap todoCompleted mTodo2 `shouldBe` Just False

    it "ничего не делает для несуществующего ключа" $ withTestDb $ \pool -> do
      _ <- runDB pool $ insertTodo "Задача"
      runDB pool $ toggleTodo (toSqlKey 999)
      todos <- runDB pool $ selectList ([] :: [Filter Todo]) []
      length todos `shouldBe` 1

  describe "filteredTodos (упражнение 3)" $ do
    it "возвращает только завершённые" $ withTestDb $ \pool -> do
      id1 <- runDB pool $ insertTodo "Задача 1"
      _ <- runDB pool $ insertTodo "Задача 2"
      runDB pool $ update id1 [TodoCompleted =. True]
      done <- runDB pool $ filteredTodos True
      length done `shouldBe` 1
      (todoTitle . entityVal . head) done `shouldBe` "Задача 1"

    it "возвращает только незавершённые" $ withTestDb $ \pool -> do
      id1 <- runDB pool $ insertTodo "Задача 1"
      _ <- runDB pool $ insertTodo "Задача 2"
      runDB pool $ update id1 [TodoCompleted =. True]
      pending <- runDB pool $ filteredTodos False
      length pending `shouldBe` 1
      (todoTitle . entityVal . head) pending `shouldBe` "Задача 2"

    it "пустой результат, если нет совпадений" $ withTestDb $ \pool -> do
      _ <- runDB pool $ insertTodo "Задача 1"
      done <- runDB pool $ filteredTodos True
      done `shouldBe` []

    it "пустая БД — пустой список" $ withTestDb $ \pool -> do
      done <- runDB pool $ filteredTodos True
      done `shouldBe` []

  describe "archiveDone (упражнение 4)" $ do
    it "удаляет завершённые задачи" $ withTestDb $ \pool -> do
      id1 <- runDB pool $ insertTodo "Задача 1"
      _ <- runDB pool $ insertTodo "Задача 2"
      runDB pool $ update id1 [TodoCompleted =. True]
      n <- runDB pool archiveDone
      n `shouldBe` 1
      todos <- runDB pool $ selectList ([] :: [Filter Todo]) []
      length todos `shouldBe` 1

    it "возвращает 0, если нечего удалять" $ withTestDb $ \pool -> do
      _ <- runDB pool $ insertTodo "Задача 1"
      n <- runDB pool archiveDone
      n `shouldBe` 0

    it "сохраняет незавершённые задачи" $ withTestDb $ \pool -> do
      _ <- runDB pool $ insertTodo "Задача 1"
      _ <- runDB pool $ insertTodo "Задача 2"
      _ <- runDB pool archiveDone
      todos <- runDB pool $ selectList ([] :: [Filter Todo]) []
      length todos `shouldBe` 2

    it "удаляет все, если все завершены" $ withTestDb $ \pool -> do
      id1 <- runDB pool $ insertTodo "Задача 1"
      id2 <- runDB pool $ insertTodo "Задача 2"
      runDB pool $ update id1 [TodoCompleted =. True]
      runDB pool $ update id2 [TodoCompleted =. True]
      n <- runDB pool archiveDone
      n `shouldBe` 2
      todos <- runDB pool $ selectList ([] :: [Filter Todo]) []
      length todos `shouldBe` 0
