module Main where

import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as T
import Test.Hspec

import MySolutions
import TaskTracker

main :: IO ()
main = hspec $ do
  -- Тестовые данные
  let todoTask = Task "Купить молоко" Low Todo
      inProgTask = Task "Написать отчёт" High InProgress
      doneTask = Task "Полить цветы" Medium Done
      allTestTasks = [todoTask, inProgTask, doneTask]

  describe "Упражнение 1: handleCompleteLogic" $ do
    it "завершает задачу со статусом Todo" $
      handleCompleteLogic todoTask
        `shouldBe` Right todoTask{taskStatus = Done}

    it "завершает задачу со статусом InProgress" $
      handleCompleteLogic inProgTask
        `shouldBe` Right inProgTask{taskStatus = Done}

    it "ошибка для уже завершённой задачи" $
      handleCompleteLogic doneTask
        `shouldBe` Left "Задача уже выполнена"

    it "сохраняет название и приоритет" $
      case handleCompleteLogic todoTask of
        Right t -> do
          taskTitle t `shouldBe` "Купить молоко"
          taskPriority t `shouldBe` Low
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ T.unpack err

  describe "Упражнение 2: computeStatsMap" $ do
    it "считает по статусам" $ do
      let stats = computeStatsMap allTestTasks
      Map.lookup "todo" stats `shouldBe` Just 1
      Map.lookup "in_progress" stats `shouldBe` Just 1
      Map.lookup "done" stats `shouldBe` Just 1

    it "пустой список — пустая карта или нули" $ do
      let stats = computeStatsMap []
      Map.findWithDefault 0 "todo" stats `shouldBe` 0
      Map.findWithDefault 0 "in_progress" stats `shouldBe` 0
      Map.findWithDefault 0 "done" stats `shouldBe` 0

    it "несколько задач одного статуса" $ do
      let tasks = [todoTask, todoTask{taskTitle = "Ещё одна"}, doneTask]
          stats = computeStatsMap tasks
      Map.lookup "todo" stats `shouldBe` Just 2
      Map.lookup "done" stats `shouldBe` Just 1

  describe "Упражнение 3: paginate" $ do
    it "первая страница" $
      paginate 1 3 [1 .. 10 :: Int] `shouldBe` [1, 2, 3]

    it "вторая страница" $
      paginate 2 3 [1 .. 10 :: Int] `shouldBe` [4, 5, 6]

    it "последняя неполная страница" $
      paginate 4 3 [1 .. 10 :: Int] `shouldBe` [10]

    it "страница за пределами списка" $
      paginate 5 3 [1 .. 10 :: Int] `shouldBe` []

    it "пустой список" $
      paginate 1 10 ([] :: [Int]) `shouldBe` []

    it "perPage = 1" $
      paginate 3 1 [1 .. 5 :: Int] `shouldBe` [3]

  describe "Упражнение 4: searchByTitle" $ do
    it "находит по подстроке" $
      searchByTitle "молоко" allTestTasks `shouldBe` [todoTask]

    it "регистронезависимый поиск" $
      searchByTitle "МОЛОКО" allTestTasks `shouldBe` [todoTask]

    it "находит несколько совпадений" $ do
      let tasks =
            [ Task "Haskell задача" Low Todo
            , Task "Задача по Haskell" High InProgress
            , Task "Другое" Medium Done
            ]
      length (searchByTitle "задач" tasks) `shouldBe` 2

    it "пустой запрос — все задачи" $
      searchByTitle "" allTestTasks `shouldBe` allTestTasks

    it "нет совпадений" $
      searchByTitle "xyz123" allTestTasks `shouldBe` []

  describe "Упражнение 5: validatePriority" $ do
    it "нормализует HIGH → high" $
      validatePriority "HIGH" `shouldBe` Right "high"

    it "нормализует Low → low" $
      validatePriority "Low" `shouldBe` Right "low"

    it "нормализует medium → medium" $
      validatePriority "medium" `shouldBe` Right "medium"

    it "нормализует MeDiUm → medium" $
      validatePriority "MeDiUm" `shouldBe` Right "medium"

    it "отклоняет неизвестный приоритет" $
      validatePriority "urgent" `shouldBe` Left "Неизвестный приоритет: urgent"

    it "отклоняет пустую строку" $
      validatePriority "" `shouldBe` Left "Неизвестный приоритет: "

  describe "Упражнение 6: entityToResponse" $ do
    it "конвертирует задачу в ответ" $ do
      let resp = entityToResponse 1 todoTask
      responseId resp `shouldBe` 1
      responseTitle resp `shouldBe` "Купить молоко"
      responsePriority resp `shouldBe` "low"
      responseStatus resp `shouldBe` "todo"

    it "конвертирует задачу InProgress" $ do
      let resp = entityToResponse 42 inProgTask
      responseId resp `shouldBe` 42
      responsePriority resp `shouldBe` "high"
      responseStatus resp `shouldBe` "in_progress"

    it "конвертирует задачу Done" $ do
      let resp = entityToResponse 7 doneTask
      responsePriority resp `shouldBe` "medium"
      responseStatus resp `shouldBe` "done"

  describe "Упражнение 7: priorityToText / textToPriority" $ do
    it "priorityToText Low" $
      priorityToText Low `shouldBe` "low"

    it "priorityToText Medium" $
      priorityToText Medium `shouldBe` "medium"

    it "priorityToText High" $
      priorityToText High `shouldBe` "high"

    it "textToPriority \"low\"" $
      textToPriority "low" `shouldBe` Right Low

    it "textToPriority \"HIGH\" (регистронезависимый)" $
      textToPriority "HIGH" `shouldBe` Right High

    it "textToPriority неизвестное значение" $
      textToPriority "critical" `shouldBe` Left "Неизвестный приоритет: critical"

    it "round-trip: textToPriority . priorityToText" $ do
      textToPriority (priorityToText Low) `shouldBe` Right Low
      textToPriority (priorityToText Medium) `shouldBe` Right Medium
      textToPriority (priorityToText High) `shouldBe` Right High

  describe "Упражнение 8: statusToText / textToStatus" $ do
    it "statusToText Todo" $
      statusToText Todo `shouldBe` "todo"

    it "statusToText InProgress" $
      statusToText InProgress `shouldBe` "in_progress"

    it "statusToText Done" $
      statusToText Done `shouldBe` "done"

    it "textToStatus \"todo\"" $
      textToStatus "todo" `shouldBe` Right Todo

    it "textToStatus \"IN_PROGRESS\" (регистронезависимый)" $
      textToStatus "IN_PROGRESS" `shouldBe` Right InProgress

    it "textToStatus \"Done\" (регистронезависимый)" $
      textToStatus "Done" `shouldBe` Right Done

    it "textToStatus неизвестное значение" $
      textToStatus "pending" `shouldBe` Left "Неизвестный статус: pending"

    it "round-trip: textToStatus . statusToText" $ do
      textToStatus (statusToText Todo) `shouldBe` Right Todo
      textToStatus (statusToText InProgress) `shouldBe` Right InProgress
      textToStatus (statusToText Done) `shouldBe` Right Done
