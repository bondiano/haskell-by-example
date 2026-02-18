module Main where

import Test.Hspec
import Data.List (foldl')
import Data.Hashable
import MySolutions

main :: IO ()
main = hspec $ do
  describe "Coord Eq (упражнение 1)" $ do
    it "равные координаты" $
      (Coord 1.0 2.0 == Coord 1.0 2.0) `shouldBe` True

    it "разные координаты" $
      (Coord 1.0 2.0 == Coord 3.0 4.0) `shouldBe` False

    it "различие только по x" $
      (Coord 1.0 2.0 == Coord 9.0 2.0) `shouldBe` False

    it "различие только по y" $
      (Coord 1.0 2.0 == Coord 1.0 9.0) `shouldBe` False

  describe "Coord Show (упражнение 1)" $ do
    it "форматирует как (x, y)" $
      show (Coord 1.0 2.0) `shouldBe` "(1.0, 2.0)"

    it "форматирует отрицательные координаты" $
      show (Coord (-3.5) 0.0) `shouldBe` "(-3.5, 0.0)"

  describe "Hashable Maybe (упражнение 2)" $ do
    it "Nothing хэшируется в 0" $
      hash (Nothing :: Maybe Int) `shouldBe` 0

    it "Just 5" $
      hash (Just (5 :: Int)) `shouldBe` combineHashes 1 5

    it "Just True" $
      hash (Just True :: Maybe Bool) `shouldBe` combineHashes 1 1

  describe "Hashable Either (упражнение 2)" $ do
    it "Left 3" $
      hash (Left 3 :: Either Int Bool) `shouldBe` combineHashes 0 3

    it "Right True" $
      hash (Right True :: Either Int Bool) `shouldBe` combineHashes 1 1

  describe "Hashable [] (упражнение 2)" $ do
    it "пустой список" $
      hash ([] :: [Int]) `shouldBe` 0

    it "один элемент" $
      hash [5 :: Int] `shouldBe` combineHashes 0 5

    it "несколько элементов" $
      hash [1, 2, 3 :: Int]
        `shouldBe` foldl' (\acc x -> combineHashes acc (hash x)) 0 [1, 2, 3 :: Int]

  describe "nubByHash (упражнение 3)" $ do
    it "удаляет дубликаты" $
      nubByHash [1, 2, 3, 1, 2 :: Int] `shouldBe` [1, 2, 3]

    it "сохраняет порядок первого вхождения" $
      nubByHash [3, 1, 2, 1, 3 :: Int] `shouldBe` [3, 1, 2]

    it "пустой список" $
      nubByHash ([] :: [Int]) `shouldBe` []

    it "без дубликатов — без изменений" $
      nubByHash [1, 2, 3 :: Int] `shouldBe` [1, 2, 3]

  describe "Brightness (упражнение 4)" $ do
    it "show" $
      show (Brightness 42) `shouldBe` "Brightness {getBrightness = 42}"

    it "равенство" $
      (Brightness 10 == Brightness 10) `shouldBe` True

    it "неравенство" $
      (Brightness 10 == Brightness 20) `shouldBe` False

    it "сложение (Num)" $
      Brightness 10 + Brightness 20 `shouldBe` Brightness 30

    it "хэширование" $
      hash (Brightness 42) `shouldBe` 42
