module Main where

import Test.Hspec
import Euler (answer)
import MySolutions (diagonal, circleArea, collatzLength)

main :: IO ()
main = hspec $ do
  describe "Euler — сумма кратных" $ do
    it "ниже 10 равна 23" $
      answer 10 `shouldBe` 23

    it "ниже 1000 равна 233168" $
      answer 1000 `shouldBe` 233168

  describe "diagonal" $ do
    it "диагональ 3×4 равна 5" $
      diagonal 3 4 `shouldBe` 5.0

    it "диагональ 5×12 равна 13" $
      diagonal 5 12 `shouldBe` 13.0

  describe "circleArea" $ do
    it "площадь круга с радиусом 1" $
      circleArea 1 `shouldSatisfy` (\a -> abs (a - pi) < 1e-9)

    it "площадь круга с радиусом 10" $
      circleArea 10 `shouldSatisfy` (\a -> abs (a - 100 * pi) < 1e-9)

  describe "collatzLength" $ do
    it "длина цепочки для 1 равна 0" $
      collatzLength 1 `shouldBe` 0

    it "длина цепочки для 2 равна 1" $
      collatzLength 2 `shouldBe` 1

    it "длина цепочки для 6 равна 8" $
      collatzLength 6 `shouldBe` 8

    it "длина цепочки для 27 равна 111" $
      collatzLength 27 `shouldBe` 111
