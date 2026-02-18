module Main where

import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck

import Data.MergeSort (mergeSort, merge, sorted)
import Data.BST (BST(..), insert, member, toAscList, fromList, valid)
import Data.Person (Person(..), encodePerson, decodePerson)

import MySolutions

main :: IO ()
main = hspec $ do
  describe "Упражнение 1: свойства сортировки" $ do
    prop "mergeSort сохраняет длину списка" $
      prop_sortPreservesLength

    prop "mergeSort возвращает упорядоченный список" $
      prop_sortOrdered

    prop "mergeSort идемпотентна" $
      prop_sortIdempotent

  describe "Упражнение 2: генератор BST" $ do
    it "сгенерированные деревья удовлетворяют инварианту" $
      property prop_genBSTValid

    it "insert x => member x" $
      property prop_insertMember

  describe "Упражнение 3: round-trip кодирования" $ do
    it "decodePerson . encodePerson == Just" $
      property prop_encodeDecodeRoundTrip

  describe "Упражнение 4: слияние отсортированных списков" $ do
    it "merge двух отсортированных списков отсортирован" $
      property prop_mergeOrdered
