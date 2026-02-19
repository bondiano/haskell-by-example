module Main where

import MySolutions (
  completeTask,
  findTaskByTitle,
  formatTasks,
  isHighPriority,
  mkTask,
  removeDuplicates,
  taskExists,
 )
import TaskTracker
import Test.Hspec

main :: IO ()
main = hspec $ do
  describe "mkTask" $ do
    it "создаёт задачу с заданным заголовком" $
      taskTitle (mkTask "Тест") `shouldBe` "Тест"

    it "устанавливает приоритет Medium" $
      taskPriority (mkTask "Тест") `shouldBe` Medium

    it "устанавливает статус Todo" $
      taskStatus (mkTask "Тест") `shouldBe` Todo

    it "устанавливает пустое описание" $
      taskDescription (mkTask "Тест") `shouldBe` ""

  describe "completeTask" $ do
    it "ставит статус Done" $
      taskStatus (completeTask (mkTask "Тест")) `shouldBe` Done

    it "не меняет заголовок" $
      taskTitle (completeTask (mkTask "Тест")) `shouldBe` "Тест"

    it "не меняет приоритет" $
      taskPriority (completeTask (mkTask "Тест")) `shouldBe` Medium

    it "не меняет описание" $ do
      let t = Task "A" "Описание" High InProgress
      taskDescription (completeTask t) `shouldBe` "Описание"

  describe "findTaskByTitle" $ do
    it "находит существующую задачу" $
      fmap taskTitle (findTaskByTitle "Написать отчёт" exampleTasks)
        `shouldBe` Just "Написать отчёт"

    it "возвращает первую найденную при дубликатах" $
      fmap taskDescription (findTaskByTitle "Купить молоко" exampleTasks)
        `shouldBe` Just "В магазине"

    it "возвращает Nothing для несуществующей задачи" $
      findTaskByTitle "Не существует" exampleTasks `shouldBe` Nothing

    it "возвращает Nothing для пустого списка" $
      findTaskByTitle "Тест" [] `shouldBe` Nothing

  describe "taskExists" $ do
    it "возвращает True для существующей задачи" $
      taskExists "Написать отчёт" exampleTasks `shouldBe` True

    it "возвращает False для несуществующей задачи" $
      taskExists "Не существует" exampleTasks `shouldBe` False

    it "возвращает False для пустого списка" $
      taskExists "Тест" [] `shouldBe` False

  describe "isHighPriority" $ do
    it "True для High" $
      isHighPriority (Task "A" "" High Todo) `shouldBe` True

    it "False для Medium" $
      isHighPriority (Task "A" "" Medium Todo) `shouldBe` False

    it "False для Low" $
      isHighPriority (Task "A" "" Low Todo) `shouldBe` False

  describe "formatTasks" $ do
    it "возвращает пустую строку для пустого списка" $
      formatTasks [] `shouldBe` ""

    it "форматирует одну задачу с переносом строки" $ do
      let t = mkTask "Тест"
      formatTasks [t] `shouldBe` show t ++ "\n"

    it "форматирует несколько задач через переносы строк" $ do
      let t1 = mkTask "A"
          t2 = mkTask "B"
      formatTasks [t1, t2] `shouldBe` show t1 ++ "\n" ++ show t2 ++ "\n"

  describe "removeDuplicates" $ do
    it "удаляет дубликаты по заголовку" $
      length (removeDuplicates exampleTasks) `shouldBe` 3

    it "сохраняет первое вхождение" $ do
      let result = removeDuplicates exampleTasks
      case findTaskByTitle "Купить молоко" result of
        Just t -> taskDescription t `shouldBe` "В магазине"
        Nothing -> expectationFailure "Задача не найдена"

    it "не меняет список без дубликатов" $ do
      let tasks = [mkTask "A", mkTask "B"]
      removeDuplicates tasks `shouldBe` tasks

    it "возвращает пустой список для пустого входа" $
      removeDuplicates [] `shouldBe` []
