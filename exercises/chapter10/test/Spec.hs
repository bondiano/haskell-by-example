module Main where

import Test.Hspec
import Test.QuickCheck

import MySolutions
import TaskTracker

main :: IO ()
main = hspec $ do
  describe "Упражнение 1: тесты addTask" addTaskSpec

  describe "Упражнение 2: тесты filterTasks" filterTasksSpec

  describe "Упражнение 3: свойства трекера (QuickCheck)" trackerProperties

  describe "Упражнение 4: тесты reverse" reverseSpec

  describe "Упражнение 5: тесты Map.lookup" lookupSpec

  describe "Упражнение 6: свойство фильтрации" $
    it "результат filterTasks — подмножество входного списка" $
      property prop_filterSubset

  describe "Упражнение 7: свойства сортировки" $ do
    it "отсортированный список упорядочен" $
      property prop_sortOrdered

    it "сортировка идемпотентна" $
      property prop_sortIdempotent
