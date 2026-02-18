module Main where

import Test.Hspec
import Control.Monad.Writer
import Data.Map.Strict qualified as Map

import Data.Phonebook (exampleBook)
import Data.Chess (KnightPos)

import MySolutions

main :: IO ()
main = hspec $ do
  describe "Упражнение 1: safeLookup" $ do
    it "находит существующий телефон" $
      safeLookup "Москва" "Алиса" exampleBook
        `shouldBe` Just "+7-495-111-1111"
    it "находит телефон в другом городе" $
      safeLookup "Петербург" "Виктор" exampleBook
        `shouldBe` Just "+7-812-333-3333"
    it "Nothing при несуществующем городе" $
      safeLookup "Новосибирск" "Алиса" exampleBook
        `shouldBe` Nothing
    it "Nothing при несуществующем имени" $
      safeLookup "Москва" "Неизвестный" exampleBook
        `shouldBe` Nothing
    it "Nothing при обоих несуществующих" $
      safeLookup "Выдуманный" "Никто" exampleBook
        `shouldBe` Nothing

  describe "Упражнение 2: безопасная индексация" $ do
    it "safeIndex находит элемент" $
      safeIndex [10, 20, 30] 1 `shouldBe` Just (20 :: Int)
    it "safeIndex возвращает Nothing для отрицательного индекса" $
      safeIndex [10, 20, 30] (-1) `shouldBe` (Nothing :: Maybe Int)
    it "safeIndex возвращает Nothing для слишком большого индекса" $
      safeIndex [10, 20, 30] 5 `shouldBe` (Nothing :: Maybe Int)
    it "safeIndex для пустого списка" $
      safeIndex ([] :: [Int]) 0 `shouldBe` Nothing
    it "safeHead для непустого списка" $
      safeHead [1, 2, 3] `shouldBe` Just (1 :: Int)
    it "safeHead для пустого списка" $
      safeHead ([] :: [Int]) `shouldBe` Nothing
    it "thirdElement из первого подсписка" $
      thirdElement [[10, 20, 30, 40], [50, 60]] `shouldBe` Just (30 :: Int)
    it "thirdElement: подсписок слишком короткий" $
      thirdElement [[10, 20], [50, 60]] `shouldBe` (Nothing :: Maybe Int)
    it "thirdElement: пустой внешний список" $
      thirdElement ([] :: [[Int]]) `shouldBe` Nothing
    it "thirdElement: пустой первый подсписок" $
      thirdElement [[], [1, 2, 3]] `shouldBe` (Nothing :: Maybe Int)

  describe "Упражнение 3: ходы шахматного коня" $ do
    it "конь достигает (6,1) из (6,2) за 3 хода" $
      canReachIn 3 (6,2) (6,1) `shouldBe` True
    it "конь не достигает (7,3) из (6,2) за 3 хода" $
      canReachIn 3 (6,2) (7,3) `shouldBe` False
    it "конь на месте за 0 ходов" $
      canReachIn 0 (4,4) (4,4) `shouldBe` True
    it "конь не на месте за 0 ходов" $
      canReachIn 0 (4,4) (5,5) `shouldBe` False
    it "конь достигает (5,6) из (4,4) за 1 ход" $
      canReachIn 1 (4,4) (5,6) `shouldBe` True
    it "конь не достигает (4,5) из (4,4) за 1 ход" $
      canReachIn 1 (4,4) (4,5) `shouldBe` False

  describe "Упражнение 4: collatzLog" $ do
    it "collatzLog 1 — ноль шагов" $ do
      let (steps, logs) = runWriter (collatzLog 1)
      steps `shouldBe` 0
      logs `shouldBe` []
    it "collatzLog 2 — один шаг" $ do
      let (steps, logs) = runWriter (collatzLog 2)
      steps `shouldBe` 1
      logs `shouldBe` ["2 \8594 1"]
    it "collatzLog 6 — восемь шагов" $ do
      let (steps, logs) = runWriter (collatzLog 6)
      steps `shouldBe` 8
      length logs `shouldBe` 8
    it "collatzLog 6 — правильный лог" $ do
      let (_, logs) = runWriter (collatzLog 6)
      head logs `shouldBe` "6 \8594 3"
      last logs `shouldBe` "2 \8594 1"
    it "collatzLog 27 — 111 шагов" $ do
      let (steps, _) = runWriter (collatzLog 27)
      steps `shouldBe` 111
