module Main where

import MySolutions
import TaskTracker
import Test.Hspec

main :: IO ()
main = hspec $ do
  describe "Упражнение 1: computeStatsStrict" $ do
    it "корректная статистика для exampleTasks" $
      computeStatsStrict exampleTasks
        `shouldBe` TaskStats
          { totalTasks = 5
          , todoCount = 2
          , doneCount = 2
          , highPriority = 2
          }

    it "пустой список — все нули" $
      computeStatsStrict []
        `shouldBe` TaskStats 0 0 0 0

    it "один элемент — Todo High" $
      computeStatsStrict [Task "Тест" High Todo]
        `shouldBe` TaskStats 1 1 0 1

    it "один элемент — Done Low" $
      computeStatsStrict [Task "Тест" Low Done]
        `shouldBe` TaskStats 1 0 1 0

  describe "Упражнение 2: badSum и goodSum" $ do
    it "badSum и goodSum дают одинаковый результат на маленьком списке" $
      badSum [1 .. 100] `shouldBe` goodSum [1 .. 100]

    it "goodSum пустого списка — 0" $
      goodSum [] `shouldBe` 0

    it "goodSum одного элемента" $
      goodSum [42] `shouldBe` 42

    it "badSum [1..10] == 55" $
      badSum [1 .. 10] `shouldBe` 55

    it "goodSum [1..1000] == 500500" $
      goodSum [1 .. 1000] `shouldBe` 500500

  describe "Упражнение 3: ones" $ do
    it "первые 5 элементов — [1,1,1,1,1]" $
      take 5 ones `shouldBe` [1, 1, 1, 1, 1]

    it "первые 10 элементов — все единицы" $
      take 10 ones `shouldBe` replicate 10 1

    it "сумма первых 100 — 100" $
      sum (take 100 ones) `shouldBe` 100

  describe "Упражнение 4: fibs" $ do
    it "первые 8 чисел Фибоначчи" $
      take 8 fibs `shouldBe` [0, 1, 1, 2, 3, 5, 8, 13]

    it "первые 2 числа" $
      take 2 fibs `shouldBe` [0, 1]

    it "10-е число Фибоначчи (индекс 10)" $
      fibs !! 10 `shouldBe` 55

    it "20-е число Фибоначчи (индекс 20)" $
      fibs !! 20 `shouldBe` 6765

  describe "Упражнение 5: predictions" $ do
    it "правильные предсказания ленивости" $
      predictions `shouldBe` ["1", "error", "3", "1", "ok"]

    it "длина списка предсказаний — 5" $
      length predictions `shouldBe` 5

  describe "Упражнение 6: totalLengthStrict" $ do
    it "суммарная длина [\"abc\", \"de\", \"f\"] == 6" $
      totalLengthStrict ["abc", "de", "f"] `shouldBe` 6

    it "пустой список — 0" $
      totalLengthStrict [] `shouldBe` 0

    it "одна пустая строка — 0" $
      totalLengthStrict [""] `shouldBe` 0

    it "несколько строк" $
      totalLengthStrict ["hello", "world"] `shouldBe` 10

  describe "Упражнение 7: strictMap" $ do
    it "strictMap (+1) [1,2,3] == [2,3,4]" $
      strictMap (+ 1) [1, 2, 3] `shouldBe` [2, 3, 4]

    it "strictMap (*2) [10, 20] == [20, 40]" $
      strictMap (* 2) [10, 20] `shouldBe` [20, 40]

    it "strictMap show [1,2,3]" $
      strictMap show [1 :: Int, 2, 3] `shouldBe` ["1", "2", "3"]

    it "strictMap на пустом списке" $
      strictMap (+ 1) ([] :: [Int]) `shouldBe` []

  describe "Бонус: nats" $ do
    it "первые 5 натуральных чисел" $
      take 5 nats `shouldBe` [1, 2, 3, 4, 5]

    it "10-е натуральное число" $
      nats !! 9 `shouldBe` 10
