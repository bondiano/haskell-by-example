module Main where

import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as T
import Test.Hspec

import MySolutions
import TaskTracker

main :: IO ()
main = hspec $ do
  -- ===========================================================
  -- Упражнение 1: completeTask
  -- ===========================================================
  describe "Упражнение 1: completeTask" $ do
    it "завершает задачу со статусом Todo" $
      case completeTask (TaskId 1) exampleStore of
        Right store ->
          lookupTask (TaskId 1) store
            `shouldBe` Just (Task "Купить молоко" "" Medium Done)
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ show err

    it "завершает задачу со статусом InProgress" $
      case completeTask (TaskId 2) exampleStore of
        Right store ->
          lookupTask (TaskId 2) store
            `shouldBe` Just (Task "Написать отчёт" "" High Done)
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ show err

    it "ошибка AlreadyDone для уже завершённой задачи" $
      completeTask (TaskId 3) exampleStore
        `shouldBe` Left (AlreadyDone (TaskId 3))

    it "ошибка TaskNotFound для несуществующей задачи" $
      completeTask (TaskId 99) exampleStore
        `shouldBe` Left (TaskNotFound (TaskId 99))

    it "ошибка TaskNotFound в пустом хранилище" $
      completeTask (TaskId 1) emptyStore
        `shouldBe` Left (TaskNotFound (TaskId 1))

  -- ===========================================================
  -- Упражнение 2: deleteTask
  -- ===========================================================
  describe "Упражнение 2: deleteTask" $ do
    it "удаляет существующую задачу" $
      case deleteTask (TaskId 1) exampleStore of
        Right (TaskStore m) -> Map.size m `shouldBe` 2
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ show err

    it "задача исчезает из хранилища после удаления" $
      case deleteTask (TaskId 1) exampleStore of
        Right store -> lookupTask (TaskId 1) store `shouldBe` Nothing
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ show err

    it "ошибка при удалении несуществующей задачи" $
      deleteTask (TaskId 99) exampleStore
        `shouldBe` Left (TaskNotFound (TaskId 99))

    it "ошибка при удалении из пустого хранилища" $
      deleteTask (TaskId 1) emptyStore
        `shouldBe` Left (TaskNotFound (TaskId 1))

  -- ===========================================================
  -- Упражнение 3: processCommands
  -- ===========================================================
  describe "Упражнение 3: processCommands" $ do
    let cfg = AppConfig Medium 10

    it "пустой список команд — хранилище без изменений" $
      processCommands cfg [] emptyStore `shouldBe` Right emptyStore

    it "AddCmd добавляет задачу с приоритетом по умолчанию" $
      case processCommands cfg [AddCmd "Новая задача"] emptyStore of
        Right store -> do
          let (TaskStore m) = store
          Map.size m `shouldBe` 1
          -- Задача должна иметь приоритет Medium (по умолчанию)
          case Map.elems m of
            [task] -> taskPriority task `shouldBe` Medium
            _ -> expectationFailure "Ожидали одну задачу"
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ show err

    it "CompleteCmd завершает существующую задачу" $
      case processCommands cfg [CompleteCmd (TaskId 1)] exampleStore of
        Right store ->
          lookupTask (TaskId 1) store
            `shouldBe` Just (Task "Купить молоко" "" Medium Done)
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ show err

    it "CompleteCmd для несуществующей задачи — ошибка" $
      processCommands cfg [CompleteCmd (TaskId 99)] emptyStore
        `shouldBe` Left (TaskNotFound (TaskId 99))

    it "несколько AddCmd создают несколько задач" $
      case processCommands cfg [AddCmd "Первая", AddCmd "Вторая"] emptyStore of
        Right (TaskStore m) -> Map.size m `shouldBe` 2
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ show err

    it "ошибка останавливает обработку" $
      processCommands
        cfg
        [AddCmd "Задача", CompleteCmd (TaskId 99), AddCmd "Не добавится"]
        emptyStore
        `shouldBe` Left (TaskNotFound (TaskId 99))

  -- ===========================================================
  -- Упражнение 4: safeHead и firstPlusSecond
  -- ===========================================================
  describe "Упражнение 4: safeHead" $ do
    it "первый элемент непустого списка" $
      safeHead [1, 2, 3 :: Int] `shouldBe` Just 1

    it "Nothing для пустого списка" $
      safeHead ([] :: [Int]) `shouldBe` Nothing

    it "работает со строками" $
      safeHead ["hello", "world"] `shouldBe` Just "hello"

  describe "Упражнение 4: firstPlusSecond" $ do
    it "сумма первых двух элементов" $
      firstPlusSecond [10, 20, 30] `shouldBe` Just 30

    it "Nothing для одного элемента" $
      firstPlusSecond [5] `shouldBe` Nothing

    it "Nothing для пустого списка" $
      firstPlusSecond [] `shouldBe` Nothing

    it "работает с отрицательными числами" $
      firstPlusSecond [-1, 1] `shouldBe` Just 0

  -- ===========================================================
  -- Упражнение 5: validateTask
  -- ===========================================================
  describe "Упражнение 5: validateTask" $ do
    it "валидная задача проходит проверку" $
      validateTask (Task "Тест" "" Medium Todo)
        `shouldBe` Right (Task "Тест" "" Medium Todo)

    it "пустое название → ошибка" $
      validateTask (Task "" "" High InProgress)
        `shouldBe` Left "Пустое название"

    it "название длиннее 200 символов → ошибка" $
      validateTask (Task (T.pack (replicate 201 'x')) "" Low Todo)
        `shouldBe` Left "Название слишком длинное"

    it "название ровно 200 символов — допустимо" $
      let title = T.pack (replicate 200 'x')
       in validateTask (Task title "" Low Todo)
            `shouldBe` Right (Task title "" Low Todo)

  -- ===========================================================
  -- Упражнение 6: allTaskCombinations
  -- ===========================================================
  describe "Упражнение 6: allTaskCombinations" $ do
    it "содержит 9 элементов (3×3)" $
      length allTaskCombinations `shouldBe` 9

    it "первый элемент — (Low, Todo)" $
      head allTaskCombinations `shouldBe` (Low, Todo)

    it "последний элемент — (High, Done)" $
      last allTaskCombinations `shouldBe` (High, Done)

    it "содержит (Medium, InProgress)" $
      (Medium, InProgress) `elem` allTaskCombinations `shouldBe` True

  -- ===========================================================
  -- Упражнение 7: safeLookupChain
  -- ===========================================================
  describe "Упражнение 7: safeLookupChain" $ do
    let m = Map.fromList [("a", "b"), ("b", "c"), ("c", "d")]

    it "один ключ — простой lookup" $
      safeLookupChain ["a"] m `shouldBe` Just "b"

    it "два ключа — оба ищутся, возвращается последний результат" $
      safeLookupChain ["a", "b"] m `shouldBe` Just "c"

    it "три ключа" $
      safeLookupChain ["a", "b", "c"] m `shouldBe` Just "d"

    it "несуществующий ключ в цепочке → Nothing" $
      safeLookupChain ["a", "x"] m `shouldBe` Nothing

    it "пустой список ключей → Nothing" $
      safeLookupChain [] m `shouldBe` (Nothing :: Maybe String)

    it "первый ключ не найден → Nothing" $
      safeLookupChain ["z"] m `shouldBe` Nothing
