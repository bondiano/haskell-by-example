module Main where

import Data.Map.Strict qualified as Map
import Test.Hspec

import MySolutions
import TaskTracker

main :: IO ()
main = hspec $ do
  describe "Упражнение 1: deleteTaskSafe" $ do
    it "удаляет существующую задачу" $
      deleteTaskSafe (TaskId 1) exampleStore
        `shouldBe` Right
          ( TaskStore $
              Map.fromList
                [ (TaskId 2, Task "Написать отчёт" High InProgress)
                , (TaskId 3, Task "Полить цветы" Low Done)
                ]
          )

    it "ошибка при удалении несуществующей задачи" $
      deleteTaskSafe (TaskId 99) exampleStore
        `shouldBe` Left (TaskNotFound (TaskId 99))

    it "удаление из пустого хранилища — ошибка" $
      deleteTaskSafe (TaskId 1) emptyStore
        `shouldBe` Left (TaskNotFound (TaskId 1))

    it "после удаления размер уменьшается на 1" $
      case deleteTaskSafe (TaskId 2) exampleStore of
        Right (TaskStore m) -> Map.size m `shouldBe` 2
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ show err

  describe "Упражнение 2: updateTitle" $ do
    it "обновляет название существующей задачи" $
      case updateTitle (TaskId 1) "Купить хлеб" exampleStore of
        Right store ->
          lookupTask (TaskId 1) store
            `shouldBe` Just (Task "Купить хлеб" Medium Todo)
        Left err -> expectationFailure $ "Ожидали Right, получили: " ++ show err

    it "ошибка при пустом названии" $
      updateTitle (TaskId 1) "" exampleStore
        `shouldBe` Left (InvalidInput "Пустое название")

    it "ошибка при несуществующей задаче" $
      updateTitle (TaskId 99) "Тест" exampleStore
        `shouldBe` Left (TaskNotFound (TaskId 99))

    it "пустое название проверяется раньше существования задачи" $
      updateTitle (TaskId 99) "" exampleStore
        `shouldBe` Left (InvalidInput "Пустое название")

  describe "Упражнение 3: safeDiv" $ do
    it "делит без остатка" $
      safeDiv 10 2 `shouldBe` Right 5

    it "делит с остатком (целочисленное)" $
      safeDiv 10 3 `shouldBe` Right 3

    it "деление на ноль — ошибка" $
      safeDiv 10 0 `shouldBe` Left "Деление на ноль"

    it "деление нуля на число" $
      safeDiv 0 5 `shouldBe` Right 0

    it "деление отрицательных чисел" $
      safeDiv (-10) 2 `shouldBe` Right (-5)

  describe "Упражнение 4: parsePriority" $ do
    it "парсит \"low\" как Low" $
      parsePriority "low" `shouldBe` Right Low

    it "парсит \"medium\" как Medium" $
      parsePriority "medium" `shouldBe` Right Medium

    it "парсит \"high\" как High" $
      parsePriority "high" `shouldBe` Right High

    it "регистронезависимый: \"HIGH\"" $
      parsePriority "HIGH" `shouldBe` Right High

    it "регистронезависимый: \"Medium\"" $
      parsePriority "Medium" `shouldBe` Right Medium

    it "неизвестный приоритет — ошибка" $
      parsePriority "urgent" `shouldBe` Left "Неизвестный приоритет: urgent"

    it "пустая строка — ошибка" $
      parsePriority "" `shouldBe` Left "Неизвестный приоритет: "

  describe "Упражнение 5: chainOperations" $ do
    it "пустой список операций — без изменений" $
      chainOperations [] exampleStore `shouldBe` Right exampleStore

    it "одна успешная операция" $
      let op = Right . addTask (TaskId 4) (Task "Новая" Low Todo)
       in case chainOperations [op] emptyStore of
            Right store ->
              lookupTask (TaskId 4) store
                `shouldBe` Just (Task "Новая" Low Todo)
            Left err -> expectationFailure $ "Ожидали Right, получили: " ++ show err

    it "несколько операций применяются последовательно" $
      let op1 = Right . addTask (TaskId 1) (Task "Первая" Low Todo)
          op2 = Right . addTask (TaskId 2) (Task "Вторая" High Todo)
       in case chainOperations [op1, op2] emptyStore of
            Right (TaskStore m) -> Map.size m `shouldBe` 2
            Left err -> expectationFailure $ "Ожидали Right, получили: " ++ show err

    it "останавливается на первой ошибке" $
      let op1 = Right . addTask (TaskId 1) (Task "Первая" Low Todo)
          op2 _ = Left (InvalidInput "Ошибка!")
          op3 = Right . addTask (TaskId 3) (Task "Третья" High Todo)
       in chainOperations [op1, op2, op3] emptyStore
            `shouldBe` Left (InvalidInput "Ошибка!")

    it "ошибка в первой операции — всё останавливается" $
      let op1 _ = Left (TaskNotFound (TaskId 42))
          op2 = Right . addTask (TaskId 1) (Task "Не должна добавиться" Low Todo)
       in chainOperations [op1, op2] emptyStore
            `shouldBe` Left (TaskNotFound (TaskId 42))
