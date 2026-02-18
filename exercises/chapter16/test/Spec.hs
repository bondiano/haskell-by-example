{-# OPTIONS_GHC -Wno-orphans #-}

module Main where

import Test.Hspec
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set

import Data.Expr.Typed
import Data.Vec
import Data.Container
import MySolutions

main :: IO ()
main = hspec $ do
  describe "eval (упражнение 1)" $ do
    it "целочисленный литерал" $
      eval (ILit 42) `shouldBe` 42

    it "булев литерал" $
      eval (BLit True) `shouldBe` True

    it "сложение" $
      eval (Add (ILit 3) (ILit 4)) `shouldBe` 7

    it "равенство (True)" $
      eval (Eql (ILit 5) (ILit 5)) `shouldBe` True

    it "равенство (False)" $
      eval (Eql (ILit 1) (ILit 2)) `shouldBe` False

    it "условное выражение (then)" $
      eval (If (BLit True) (ILit 1) (ILit 2)) `shouldBe` 1

    it "условное выражение (else)" $
      eval (If (BLit False) (ILit 1) (ILit 2)) `shouldBe` 2

    it "отрицание" $
      eval (Not (BLit True)) `shouldBe` False

    it "логическое и" $
      eval (And (BLit True) (BLit False)) `shouldBe` False

    it "больше" $
      eval (Gt (ILit 5) (ILit 3)) `shouldBe` True

    it "сложное выражение" $
      eval (If (And (Gt (ILit 10) (ILit 5)) (Not (BLit False)))
               (Add (ILit 1) (ILit 2))
               (ILit 0))
        `shouldBe` 3

  describe "prettyExpr (упражнение 2)" $ do
    it "целочисленный литерал" $
      prettyExpr (ILit 42) `shouldBe` "42"

    it "булев литерал" $
      prettyExpr (BLit True) `shouldBe` "True"

    it "сложение" $
      prettyExpr (Add (ILit 1) (ILit 2)) `shouldBe` "(1 + 2)"

    it "равенство" $
      prettyExpr (Eql (ILit 1) (ILit 2)) `shouldBe` "(1 == 2)"

    it "условное выражение" $
      prettyExpr (If (BLit True) (ILit 1) (ILit 2))
        `shouldBe` "(if True then 1 else 2)"

    it "отрицание" $
      prettyExpr (Not (BLit True)) `shouldBe` "(not True)"

    it "логическое и" $
      prettyExpr (And (BLit True) (BLit False))
        `shouldBe` "(True && False)"

    it "больше" $
      prettyExpr (Gt (ILit 3) (ILit 2)) `shouldBe` "(3 > 2)"

    it "вложенное выражение" $
      prettyExpr (Add (Add (ILit 1) (ILit 2)) (ILit 3))
        `shouldBe` "((1 + 2) + 3)"

  describe "Container (упражнение 3)" $ do
    it "список: empty и insert" $ do
      let xs = insert (3 :: Int) (insert 2 (insert 1 (empty :: [Int])))
      toList xs `shouldBe` [1, 2, 3]

    it "список: containerFromList" $
      containerFromList [1, 2, 3 :: Int] `shouldBe` [1, 2, 3 :: Int]

    it "Set: containerFromList сортирует" $
      toList (containerFromList [3, 1, 2 :: Int] :: Set.Set Int)
        `shouldBe` [1, 2, 3]

    it "Set: insert дубликат" $ do
      let s = insert (1 :: Int) (insert 1 (empty :: Set.Set Int))
      toList s `shouldBe` [1]

    it "Map: containerFromList" $ do
      let m = containerFromList [("a", 1), ("b", 2)] :: Map.Map String Int
      Map.toList m `shouldBe` [("a", 1), ("b", 2)]

    it "Map: insert перезаписывает" $ do
      let m = insert ("a", 2) (insert ("a", 1) (empty :: Map.Map String Int))
      toList m `shouldBe` [("a", 2)]

  describe "Vec (упражнение 4)" $ do
    it "vhead" $
      vhead (VCons 1 VNil) `shouldBe` (1 :: Int)

    it "vhead длинного вектора" $
      vhead (VCons 'a' (VCons 'b' (VCons 'c' VNil))) `shouldBe` 'a'

    it "vtail" $
      vtail (VCons 1 (VCons 2 VNil)) `shouldBe` VCons (2 :: Int) VNil

    it "vtail до пустого" $
      vtail (VCons 'x' VNil) `shouldBe` (VNil :: Vec 'Zero Char)

    it "vzip" $
      vzip (VCons 1 (VCons 2 VNil)) (VCons 'a' (VCons 'b' VNil))
        `shouldBe` VCons (1 :: Int, 'a') (VCons (2, 'b') VNil)

    it "vzip пустых" $
      vzip (VNil :: Vec 'Zero Int) (VNil :: Vec 'Zero Char)
        `shouldBe` VNil

    it "vappend VNil" $
      vappend VNil (VCons 1 (VCons 2 VNil))
        `shouldBe` VCons (1 :: Int) (VCons 2 VNil)

    it "vappend двух непустых" $
      vappend (VCons 1 (VCons 2 VNil)) (VCons 3 VNil)
        `shouldBe` VCons (1 :: Int) (VCons 2 (VCons 3 VNil))

    it "vappend к VNil" $
      vappend (VCons 'a' VNil) VNil
        `shouldBe` VCons 'a' VNil
