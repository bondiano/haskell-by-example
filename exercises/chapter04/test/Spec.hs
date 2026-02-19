module Main where

import MySolutions (
  chunksOf,
  completionRate,
  computeStats,
  frequencies,
  myMap,
  myReverse,
  sortByPriority,
 )
import TaskTracker
import Test.Hspec

main :: IO ()
main = hspec $ do
  describe "computeStats" $ do
    it "считает статистику для exampleTasks" $ do
      let stats = computeStats exampleTasks
      totalTasks stats `shouldBe` 5
      todoCount stats `shouldBe` 2
      progressCount stats `shouldBe` 1
      doneCount stats `shouldBe` 2
      highCount stats `shouldBe` 2

    it "возвращает пустую статистику для пустого списка" $
      computeStats [] `shouldBe` emptyStats

    it "считает для одной задачи" $ do
      let stats = computeStats [Task "A" "" High Todo]
      totalTasks stats `shouldBe` 1
      todoCount stats `shouldBe` 1
      progressCount stats `shouldBe` 0
      doneCount stats `shouldBe` 0
      highCount stats `shouldBe` 1

  describe "completionRate" $ do
    it "вычисляет процент для exampleTasks" $
      completionRate exampleTasks `shouldSatisfy` (\r -> abs (r - 0.4) < 1e-9)

    it "возвращает 0.0 для пустого списка" $
      completionRate [] `shouldBe` 0.0

    it "возвращает 1.0 для полностью завершённого списка" $ do
      let tasks = [Task "A" "" Low Done, Task "B" "" Medium Done]
      completionRate tasks `shouldSatisfy` (\r -> abs (r - 1.0) < 1e-9)

    it "возвращает 0.0 для списка без завершённых" $ do
      let tasks = [Task "A" "" Low Todo, Task "B" "" Medium InProgress]
      completionRate tasks `shouldBe` 0.0

  describe "sortByPriority" $ do
    it "ставит High задачи первыми" $ do
      let sorted = sortByPriority exampleTasks
      taskPriority (head sorted) `shouldBe` High

    it "сохраняет все задачи" $
      length (sortByPriority exampleTasks) `shouldBe` length exampleTasks

    it "упорядочивает High > Medium > Low" $ do
      let tasks =
            [ Task "L" "" Low Todo
            , Task "H" "" High Todo
            , Task "M" "" Medium Todo
            ]
          sorted = sortByPriority tasks
      map taskTitle sorted `shouldBe` ["H", "M", "L"]

    it "не меняет порядок задач с одинаковым приоритетом" $ do
      let tasks =
            [ Task "A" "" High Todo
            , Task "B" "" High InProgress
            ]
          sorted = sortByPriority tasks
      map taskTitle sorted `shouldBe` ["A", "B"]

    it "возвращает пустой список для пустого входа" $
      sortByPriority [] `shouldBe` []

  describe "myReverse" $ do
    it "переворачивает список чисел" $
      myReverse [1, 2, 3 :: Int] `shouldBe` [3, 2, 1]

    it "переворачивает строку" $
      myReverse "hello" `shouldBe` "olleh"

    it "возвращает пустой список для пустого входа" $
      myReverse ([] :: [Int]) `shouldBe` []

    it "не меняет одноэлементный список" $
      myReverse [42 :: Int] `shouldBe` [42]

  describe "myMap" $ do
    it "применяет функцию к каждому элементу" $
      myMap (* 2) [1, 2, 3 :: Int] `shouldBe` [2, 4, 6]

    it "преобразует типы" $
      myMap show [1, 2, 3 :: Int] `shouldBe` ["1", "2", "3"]

    it "возвращает пустой список для пустого входа" $
      myMap (* 2) ([] :: [Int]) `shouldBe` []

    it "работает с отрицательными числами" $
      myMap negate [1, -2, 3 :: Int] `shouldBe` [-1, 2, -3]

  describe "frequencies" $ do
    it "подсчитывает частоты символов" $ do
      let result = frequencies "abracadabra"
      lookup 'a' result `shouldBe` Just 5
      lookup 'b' result `shouldBe` Just 2
      lookup 'r' result `shouldBe` Just 2
      lookup 'c' result `shouldBe` Just 1
      lookup 'd' result `shouldBe` Just 1

    it "подсчитывает частоты чисел" $ do
      let result = frequencies [1, 2, 1, 3, 2, 1 :: Int]
      lookup 1 result `shouldBe` Just 3
      lookup 2 result `shouldBe` Just 2
      lookup 3 result `shouldBe` Just 1

    it "возвращает пустой список для пустого входа" $
      frequencies ([] :: [Int]) `shouldBe` []

    it "возвращает единицу для уникальных элементов" $ do
      let result = frequencies [1, 2, 3 :: Int]
      all (\(_, c) -> c == 1) result `shouldBe` True

  describe "chunksOf" $ do
    it "разбивает на куски по 3" $
      chunksOf 3 [1, 2, 3, 4, 5, 6, 7 :: Int] `shouldBe` [[1, 2, 3], [4, 5, 6], [7]]

    it "разбивает на куски по 2" $
      chunksOf 2 [1, 2, 3, 4 :: Int] `shouldBe` [[1, 2], [3, 4]]

    it "возвращает пустой список для пустого входа" $
      chunksOf 3 ([] :: [Int]) `shouldBe` []

    it "возвращает один кусок для короткого списка" $
      chunksOf 5 [1, 2, 3 :: Int] `shouldBe` [[1, 2, 3]]

    it "разбивает по 1" $
      chunksOf 1 [1, 2, 3 :: Int] `shouldBe` [[1], [2], [3]]
