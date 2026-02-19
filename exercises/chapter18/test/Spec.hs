module Main where

import Data.Text (Text)
import Data.Text qualified as T
import Test.Hspec
import Text.Megaparsec (errorBundlePretty, parse)

import MySolutions (
  executeQuery,
  matchFilter,
  pFilterExpr,
  pQuery,
  parseQuery,
  prettyQuery,
 )
import TaskTracker

main :: IO ()
main = hspec $ do
  -- Тестовые данные
  let task1 = Task "Купить молоко" Low Todo ["дом", "покупки"]
      task2 = Task "Написать отчёт" High InProgress ["работа"]
      task3 = Task "Полить цветы" Medium Done ["дом"]
      task4 = Task "Подготовить презентацию" High Todo ["работа", "важное"]
      task5 = Task "Забрать посылку" Low Done ["дом"]
      tasks = [task1, task2, task3, task4, task5]

  describe "Упражнение 1: pFilterExpr" $ do
    it "парсит status:done" $
      parse pFilterExpr "" "status:done"
        `shouldBe` Right (StatusFilter "done")

    it "парсит status:todo" $
      parse pFilterExpr "" "status:todo"
        `shouldBe` Right (StatusFilter "todo")

    it "парсит status:in-progress" $
      parse pFilterExpr "" "status:in-progress"
        `shouldBe` Right (StatusFilter "in-progress")

    it "парсит priority:high" $
      parse pFilterExpr "" "priority:high"
        `shouldBe` Right (PriorityFilter "high")

    it "парсит priority:low" $
      parse pFilterExpr "" "priority:low"
        `shouldBe` Right (PriorityFilter "low")

    it "парсит tag:work" $
      parse pFilterExpr "" "tag:work"
        `shouldBe` Right (TagFilter "work")

    it "парсит tag с кириллицей" $
      parse pFilterExpr "" "tag:работа"
        `shouldBe` Right (TagFilter "работа")

  describe "Упражнение 2: pQuery" $ do
    it "парсит один фильтр" $
      parse pQuery "" "status:done"
        `shouldBe` Right (Query [StatusFilter "done"])

    it "парсит два фильтра через пробел" $
      parse pQuery "" "status:done priority:high"
        `shouldBe` Right (Query [StatusFilter "done", PriorityFilter "high"])

    it "парсит три фильтра" $
      parse pQuery "" "status:todo priority:low tag:дом"
        `shouldBe` Right (Query [StatusFilter "todo", PriorityFilter "low", TagFilter "дом"])

  describe "Упражнение 3: matchFilter" $ do
    it "StatusFilter \"todo\" совпадает с задачей Todo" $
      matchFilter (StatusFilter "todo") task1 `shouldBe` True

    it "StatusFilter \"done\" не совпадает с задачей Todo" $
      matchFilter (StatusFilter "done") task1 `shouldBe` False

    it "StatusFilter \"in-progress\" совпадает с задачей InProgress" $
      matchFilter (StatusFilter "in-progress") task2 `shouldBe` True

    it "StatusFilter \"done\" совпадает с задачей Done" $
      matchFilter (StatusFilter "done") task3 `shouldBe` True

    it "PriorityFilter \"high\" совпадает с High задачей" $
      matchFilter (PriorityFilter "high") task2 `shouldBe` True

    it "PriorityFilter \"high\" не совпадает с Low задачей" $
      matchFilter (PriorityFilter "high") task1 `shouldBe` False

    it "PriorityFilter \"low\" совпадает с Low задачей" $
      matchFilter (PriorityFilter "low") task1 `shouldBe` True

    it "PriorityFilter \"medium\" совпадает с Medium задачей" $
      matchFilter (PriorityFilter "medium") task3 `shouldBe` True

    it "TagFilter совпадает, если тег присутствует" $
      matchFilter (TagFilter "работа") task2 `shouldBe` True

    it "TagFilter не совпадает, если тега нет" $
      matchFilter (TagFilter "работа") task1 `shouldBe` False

    it "TagFilter \"дом\" совпадает с задачей с тегом дом" $
      matchFilter (TagFilter "дом") task1 `shouldBe` True

  describe "Упражнение 4: prettyQuery" $ do
    it "печатает один фильтр" $
      prettyQuery (Query [StatusFilter "done"]) `shouldBe` "status:done"

    it "печатает два фильтра через пробел" $
      prettyQuery (Query [StatusFilter "done", PriorityFilter "high"])
        `shouldBe` "status:done priority:high"

    it "печатает TagFilter" $
      prettyQuery (Query [TagFilter "работа"]) `shouldBe` "tag:работа"

    it "round-trip: parse → prettyQuery → parse" $ do
      let input = "status:todo priority:high tag:работа"
      case parse pQuery "" input of
        Left _ -> expectationFailure "Парсинг не должен был упасть"
        Right q -> parse pQuery "" (prettyQuery q) `shouldBe` Right q

  describe "Упражнение 5: parseQuery" $ do
    it "парсит валидный запрос" $
      parseQuery "status:done" `shouldBe` Right (Query [StatusFilter "done"])

    it "парсит сложный запрос" $
      parseQuery "priority:high tag:работа"
        `shouldBe` Right (Query [PriorityFilter "high", TagFilter "работа"])

    it "возвращает ошибку для невалидного ввода" $
      parseQuery "" `shouldSatisfy` isLeft

    it "возвращает ошибку для мусора" $
      parseQuery "какой-то мусор" `shouldSatisfy` isLeft

  describe "Упражнение 6: executeQuery" $ do
    it "фильтрует по статусу done" $
      executeQuery (Query [StatusFilter "done"]) tasks
        `shouldBe` [task3, task5]

    it "фильтрует по статусу todo" $
      executeQuery (Query [StatusFilter "todo"]) tasks
        `shouldBe` [task1, task4]

    it "фильтрует по приоритету high" $
      executeQuery (Query [PriorityFilter "high"]) tasks
        `shouldBe` [task2, task4]

    it "фильтрует по тегу дом" $
      executeQuery (Query [TagFilter "дом"]) tasks
        `shouldBe` [task1, task3, task5]

    it "AND-семантика: status:todo И priority:high" $
      executeQuery (Query [StatusFilter "todo", PriorityFilter "high"]) tasks
        `shouldBe` [task4]

    it "AND-семантика: status:done И tag:дом" $
      executeQuery (Query [StatusFilter "done", TagFilter "дом"]) tasks
        `shouldBe` [task3, task5]

    it "пустой результат при несовместимых фильтрах" $
      executeQuery (Query [StatusFilter "done", PriorityFilter "high"]) tasks
        `shouldBe` []

    it "пустой список задач — пустой результат" $
      executeQuery (Query [StatusFilter "done"]) [] `shouldBe` []

-- | Вспомогательная функция
isLeft :: Either a b -> Bool
isLeft (Left _) = True
isLeft (Right _) = False
