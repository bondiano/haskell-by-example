module Main where

import MySolutions hiding (describe)
import MySolutions qualified as Sol
import TaskTracker
import Test.Hspec

main :: IO ()
main = hspec $ do
  describe "Упражнение 1: Describable Priority" $ do
    it "describe Low возвращает \"Низкий приоритет\"" $
      Sol.describe Low `shouldBe` "Низкий приоритет"
    it "describe Medium возвращает \"Средний приоритет\"" $
      Sol.describe Medium `shouldBe` "Средний приоритет"
    it "describe High возвращает \"Высокий приоритет\"" $
      Sol.describe High `shouldBe` "Высокий приоритет"

  describe "Упражнение 2: Describable Status" $ do
    it "describe Todo возвращает \"К выполнению\"" $
      Sol.describe Todo `shouldBe` "К выполнению"
    it "describe InProgress возвращает \"В работе\"" $
      Sol.describe InProgress `shouldBe` "В работе"
    it "describe Done возвращает \"Выполнено\"" $
      Sol.describe Done `shouldBe` "Выполнено"

  describe "Упражнение 3: Describable Task" $ do
    it "форматирует задачу в виде \"[приоритет] название — статус\"" $ do
      let task = Task "Релиз" "Подготовить" High InProgress
      Sol.describe task `shouldBe` "[Высокий приоритет] Релиз — В работе"
    it "форматирует задачу с низким приоритетом" $ do
      let task = Task "Уборка" "" Low Todo
      Sol.describe task `shouldBe` "[Низкий приоритет] Уборка — К выполнению"
    it "форматирует завершённую задачу" $ do
      let task = Task "Отчёт" "Квартальный" Medium Done
      Sol.describe task `shouldBe` "[Средний приоритет] Отчёт — Выполнено"

  describe "Упражнение 4: compareTasks" $ do
    it "задача с высоким приоритетом идёт перед задачей с низким" $ do
      let high = Task "A" "" High Todo
          low = Task "B" "" Low Todo
      compareTasks high low `shouldBe` LT
    it "задача с низким приоритетом идёт после задачи с высоким" $ do
      let high = Task "A" "" High Todo
          low = Task "B" "" Low Todo
      compareTasks low high `shouldBe` GT
    it "при одинаковом приоритете — Todo перед Done" $ do
      let todo = Task "A" "" High Todo
          done = Task "B" "" High Done
      compareTasks todo done `shouldBe` LT
    it "при одинаковом приоритете и статусе — EQ" $ do
      let a = Task "A" "" Medium InProgress
          b = Task "B" "" Medium InProgress
      compareTasks a b `shouldBe` EQ

  describe "Упражнение 5: sortTasks" $ do
    it "сортирует задачи: сначала High, потом Medium, потом Low" $ do
      let tasks =
            [ Task "Low task" "" Low Todo
            , Task "High task" "" High Todo
            , Task "Medium task" "" Medium Todo
            ]
      map taskTitle (sortTasks tasks)
        `shouldBe` ["High task", "Medium task", "Low task"]
    it "при одинаковом приоритете сортирует по статусу" $ do
      let tasks =
            [ Task "Done" "" High Done
            , Task "Todo" "" High Todo
            , Task "InProg" "" High InProgress
            ]
      map taskTitle (sortTasks tasks)
        `shouldBe` ["Todo", "InProg", "Done"]

  describe "Упражнение 6: allPriorities" $ do
    it "возвращает [Low, Medium, High]" $
      allPriorities `shouldBe` [Low, Medium, High]
    it "содержит три элемента" $
      length allPriorities `shouldBe` 3

  describe "Упражнение 7: cyclePriority" $ do
    it "Low → Medium" $
      cyclePriority Low `shouldBe` Medium
    it "Medium → High" $
      cyclePriority Medium `shouldBe` High
    it "High → Low (цикл)" $
      cyclePriority High `shouldBe` Low

  describe "Упражнение 8: Name newtype" $ do
    it "Name поддерживает Show" $
      show (Name "Alice") `shouldBe` "Name \"Alice\""
    it "Name поддерживает Eq" $
      Name "Bob" `shouldBe` Name "Bob"
    it "разные Name не равны" $
      Name "Alice" `shouldNotBe` Name "Bob"

  describe "Упражнение 9: Summarizable TaskStats" $ do
    it "summary для статистики" $ do
      let stats = TaskStats 10 3 5 2
      summary stats `shouldBe` "10 задач: 5 выполнено"
    it "detailedSummary по умолчанию совпадает с summary" $ do
      let stats = TaskStats 5 2 1 3
      detailedSummary stats `shouldBe` summary stats
    it "summary для нулевой статистики" $ do
      let stats = TaskStats 0 0 0 0
      summary stats `shouldBe` "0 задач: 0 выполнено"
