module Main where

import Data.Map.Strict qualified as Map
import Test.Hspec

import MySolutions
import TaskTracker

main :: IO ()
main = hspec $ do
  -- ===========================================================
  -- Упражнение 1: deleteTaskPure
  -- ===========================================================
  describe "Упражнение 1: deleteTaskPure" $ do
    it "удаляет существующую задачу" $
      case deleteTaskPure (TaskId 1) exampleStore of
        Right (TaskStore m) -> Map.member (TaskId 1) m `shouldBe` False
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ show err

    it "размер уменьшается на 1 после удаления" $
      case deleteTaskPure (TaskId 1) exampleStore of
        Right (TaskStore m) -> Map.size m `shouldBe` 2
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ show err

    it "ошибка при удалении несуществующей задачи" $
      deleteTaskPure (TaskId 99) exampleStore
        `shouldBe` Left (TaskNotFound (TaskId 99))

    it "ошибка при удалении из пустого хранилища" $
      deleteTaskPure (TaskId 1) emptyStore
        `shouldBe` Left (TaskNotFound (TaskId 1))

  -- ===========================================================
  -- Упражнение 2: listTasksPure
  -- ===========================================================
  describe "Упражнение 2: listTasksPure" $ do
    it "возвращает все задачи из хранилища" $
      length (listTasksPure exampleStore) `shouldBe` 3

    it "пустое хранилище → пустой список" $
      listTasksPure emptyStore `shouldBe` []

    it "содержит правильные задачи" $
      let tasks = listTasksPure exampleStore
       in map fst tasks `shouldBe` [TaskId 1, TaskId 2, TaskId 3]

  -- ===========================================================
  -- Упражнение 3: runCalc
  -- ===========================================================
  describe "Упражнение 3: runCalc" $ do
    it "запускает простое вычисление" $
      runCalc (pure 42) `shouldBe` Right (42 :: Int, [])

    it "начальный журнал пуст" $
      case runCalc (pure "hello") of
        Right (_, log') -> log' `shouldBe` []
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ err

  -- ===========================================================
  -- Упражнение 4: calcDivide
  -- ===========================================================
  describe "Упражнение 4: calcDivide" $ do
    it "делит числа и записывает в журнал" $
      case runCalc (calcDivide 10 2) of
        Right (result, log') -> do
          result `shouldBe` 5.0
          length log' `shouldBe` 1
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ err

    it "деление на ноль — ошибка" $
      runCalc (calcDivide 10 0) `shouldBe` Left "Деление на ноль"

    it "журнал содержит запись об операции" $
      case runCalc (calcDivide 10 2) of
        Right (_, log') -> head log' `shouldBe` "10.0 / 2.0 = 5.0"
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ err

    it "несколько делений — несколько записей" $
      case runCalc (calcDivide 10 2 >> calcDivide 6 3) of
        Right (result, log') -> do
          result `shouldBe` 2.0
          length log' `shouldBe` 2
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ err

    it "ошибка в середине — всё вычисление падает" $
      runCalc (calcDivide 10 2 >> calcDivide 5 0 >> calcDivide 1 1)
        `shouldBe` Left "Деление на ноль"

  -- ===========================================================
  -- Упражнение 5: calcHistory
  -- ===========================================================
  describe "Упражнение 5: calcHistory" $ do
    it "пустой журнал в начале" $
      runCalc calcHistory `shouldBe` Right ([] :: [String], [])

    it "журнал после одного деления" $
      case runCalc (calcDivide 10 2 >> calcHistory) of
        Right (history, _) -> history `shouldBe` ["10.0 / 2.0 = 5.0"]
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ err

    it "журнал после двух делений" $
      case runCalc (calcDivide 10 2 >> calcDivide 6 3 >> calcHistory) of
        Right (history, _) -> length history `shouldBe` 2
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ err

  -- ===========================================================
  -- Упражнение 6: calcChain
  -- ===========================================================
  describe "Упражнение 6: calcChain" $ do
    it "результат цепочки 100 / 5 / 4 = 5.0" $
      case runCalc calcChain of
        Right (result, _) -> result `shouldBe` 5.0
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ err

    it "журнал содержит две записи" $
      case runCalc calcChain of
        Right (_, log') -> length log' `shouldBe` 2
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ err

    it "первая запись — 100 / 5" $
      case runCalc calcChain of
        Right (_, log') -> head log' `shouldBe` "100.0 / 5.0 = 20.0"
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ err

    it "вторая запись — 20 / 4" $
      case runCalc calcChain of
        Right (_, log') -> log' !! 1 `shouldBe` "20.0 / 4.0 = 5.0"
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ err
