{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Main where

import Control.Monad.Logger (runNoLoggingT)
import Data.Aeson (encode, object, (.=))
import Data.ByteString.Lazy qualified as LBS
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as T
import Database.Persist hiding (get)
import Database.Persist.Sqlite hiding (get)
import Network.HTTP.Types
import Network.Wai (Application)
import Network.Wai.Test (SResponse, simpleStatus)
import Servant
import Test.Hspec
import Test.Hspec.Wai
import Test.Hspec.Wai.JSON

import API
import MySolutions
import TaskTracker

-- ── Test Application ────────────────────────────────────────

-- Создаём in-memory базу для тестов
testApp :: IO Application
testApp = do
  pool <- runNoLoggingT $ createSqlitePool ":memory:" 1
  runNoLoggingT $ runSqlPool (runMigration migrateAll) pool
  pure $ serve taskAPI (taskServer pool)

-- Вспомогательные функции для тестов
createTestTask :: Application -> Text -> Text -> WaiSession st SResponse
createTestTask app title priority =
  request
    methodPost
    "/tasks"
    [("Content-Type", "application/json")]
    ( encode $
        object
          [ "title" .= title
          , "priority" .= priority
          ]
    )

-- ── Main Test Suite ─────────────────────────────────────────

main :: IO ()
main = hspec $ do
  -- ── Unit Tests (Pure Functions) ──────────────────────────

  describe "Unit Tests - Pure Functions" $ do
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

      it "находит несколько совпадений" $
        let tasks =
              [ Task "Haskell задача" Low Todo
              , Task "Задача по Haskell" High InProgress
              , Task "Другое" Medium Done
              ]
         in length (searchByTitle "задач" tasks) `shouldBe` 2

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

    describe "Упражнение 6: entityToResponsePure" $ do
      it "конвертирует задачу в ответ" $ do
        let resp = entityToResponsePure 1 todoTask
        responseId resp `shouldBe` 1
        responseTitle resp `shouldBe` "Купить молоко"
        responsePriority resp `shouldBe` "low"
        responseStatus resp `shouldBe` "todo"

      it "конвертирует задачу InProgress" $ do
        let resp = entityToResponsePure 42 inProgTask
        responseId resp `shouldBe` 42
        responsePriority resp `shouldBe` "high"
        responseStatus resp `shouldBe` "in_progress"

      it "конвертирует задачу Done" $ do
        let resp = entityToResponsePure 7 doneTask
        responsePriority resp `shouldBe` "medium"
        responseStatus resp `shouldBe` "done"

    describe "Priority/Status conversions" $ do
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

  -- ── Integration Tests (Servant API) ──────────────────────

  describe "Integration Tests - Servant API" $ do
    app <- runIO testApp

    with (return app) $ do
      describe "GET /tasks" $ do
        it "возвращает пустой список изначально" $ do
          get "/tasks" `shouldRespondWith` [json|[]|]

      describe "POST /tasks" $ do
        it "создаёт новую задачу" $ do
          let body = encode $ object ["title" .= ("Купить молоко" :: Text), "priority" .= ("low" :: Text)]
          request methodPost "/tasks" [("Content-Type", "application/json")] body
            `shouldRespondWith` 200

        it "валидирует пустой заголовок" $ do
          let body = encode $ object ["title" .= ("" :: Text)]
          request methodPost "/tasks" [("Content-Type", "application/json")] body
            `shouldRespondWith` 400

        it "валидирует приоритет" $ do
          let body = encode $ object ["title" .= ("Test" :: Text), "priority" .= ("urgent" :: Text)]
          request methodPost "/tasks" [("Content-Type", "application/json")] body
            `shouldRespondWith` 400

      describe "GET /tasks/:id" $ do
        it "возвращает 404 для несуществующей задачи" $ do
          get "/tasks/999" `shouldRespondWith` 404

      describe "DELETE /tasks/:id" $ do
        it "возвращает 404 для несуществующей задачи" $ do
          request methodDelete "/tasks/999" [] "" `shouldRespondWith` 404

      describe "PATCH /tasks/:id/complete" $ do
        it "возвращает 404 для несуществующей задачи" $ do
          request methodPatch "/tasks/999/complete" [] "" `shouldRespondWith` 404

      describe "GET /stats" $ do
        it "возвращает статистику" $ do
          get "/stats" `shouldRespondWith` 200

  -- ── End-to-End Workflow Test ─────────────────────────────

  describe "End-to-End Workflow" $ do
    app <- runIO testApp

    with (return app) $ do
      it "полный цикл работы с задачами" $ do
        -- Создаём задачу
        createResp <- createTestTask app "Тестовая задача" "high"
        liftIO $ statusCode (simpleStatus createResp) `shouldBe` 200

        -- Проверяем список
        listResp <- get "/tasks"
        liftIO $ statusCode (simpleStatus listResp) `shouldBe` 200

        -- Завершаем задачу
        completeResp <- request methodPatch "/tasks/1/complete" [] ""
        liftIO $ statusCode (simpleStatus completeResp) `shouldBe` 200

        -- Проверяем статистику
        statsResp <- get "/stats"
        liftIO $ statusCode (simpleStatus statsResp) `shouldBe` 200

        -- Удаляем задачу
        deleteResp <- request methodDelete "/tasks/1" [] ""
        liftIO $ statusCode (simpleStatus deleteResp) `shouldBe` 204
