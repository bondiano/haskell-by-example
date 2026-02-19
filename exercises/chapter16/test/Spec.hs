module Main where

import Control.Concurrent (threadDelay)
import Control.Concurrent.Async (mapConcurrently_)
import Control.Concurrent.MVar
import Control.Concurrent.STM
import Test.Hspec

import MySolutions

main :: IO ()
main = hspec $ do
  describe "Упражнение 1: Counter (MVar)" $ do
    it "новый счётчик начинается с 0" $ do
      c <- newCounter
      getCount c `shouldReturn` 0

    it "инкремент увеличивает счётчик" $ do
      c <- newCounter
      increment c
      increment c
      increment c
      getCount c `shouldReturn` 3

    it "1000 конкурентных инкрементов" $ do
      c <- newCounter
      mapConcurrently_ (\_ -> increment c) [1 .. 1000 :: Int]
      getCount c `shouldReturn` 1000

  describe "Упражнение 2: withTimeout" $ do
    it "быстрое действие возвращает Just" $ do
      result <- withTimeout 1_000_000 (pure (42 :: Int))
      result `shouldBe` Just 42

    it "медленное действие возвращает Nothing" $ do
      result <- withTimeout 50_000 (threadDelay 1_000_000 >> pure (42 :: Int))
      result `shouldBe` Nothing

  describe "Упражнение 3: parallelSum" $ do
    it "сумма пустого списка" $
      parallelSum [] `shouldReturn` 0

    it "сумма одного элемента" $
      parallelSum [42] `shouldReturn` 42

    it "сумма нескольких элементов" $
      parallelSum [1, 2, 3, 4, 5] `shouldReturn` 15

    it "сумма с отрицательными числами" $
      parallelSum [10, -3, 5, -2] `shouldReturn` 10

  describe "Упражнение 4: STM банковские переводы" $ do
    it "создание счёта с начальным балансом" $ do
      acc <- newAccount 100
      bal <- readTVarIO acc
      bal `shouldBe` 100

    it "deposit увеличивает баланс" $ do
      acc <- newAccount 100
      atomically $ deposit acc 50
      readTVarIO acc `shouldReturn` 150

    it "withdraw уменьшает баланс" $ do
      acc <- newAccount 100
      atomically $ withdraw acc 30
      readTVarIO acc `shouldReturn` 70

    it "transfer перемещает средства между счетами" $ do
      acc1 <- newAccount 100
      acc2 <- newAccount 100
      atomically $ transfer acc1 acc2 30
      bal1 <- readTVarIO acc1
      bal2 <- readTVarIO acc2
      bal1 `shouldBe` 70
      bal2 `shouldBe` 130

    it "сумма балансов сохраняется после перевода" $ do
      acc1 <- newAccount 200
      acc2 <- newAccount 300
      atomically $ transfer acc1 acc2 50
      bal1 <- readTVarIO acc1
      bal2 <- readTVarIO acc2
      (bal1 + bal2) `shouldBe` 500

  describe "Упражнение 5: parallelMap" $ do
    it "применяет функцию к каждому элементу" $
      parallelMap (pure . (+ 1)) [1, 2, 3 :: Int] `shouldReturn` [2, 3, 4]

    it "пустой список" $
      parallelMap (pure . (+ 1)) ([] :: [Int]) `shouldReturn` []

    it "сохраняет порядок элементов" $
      parallelMap (pure . show) [1, 2, 3 :: Int] `shouldReturn` ["1", "2", "3"]

    it "работает с IO-функциями" $ do
      results <-
        parallelMap
          ( \x -> do
              threadDelay 1000
              pure (x * 2)
          )
          [1, 2, 3 :: Int]
      results `shouldBe` [2, 4, 6]

  describe "Упражнение 6: Logger (TChan)" $ do
    it "flushLog пустого логгера — пустой список" $ do
      logger <- newLogger
      msgs <- flushLog logger
      msgs `shouldBe` []

    it "логирует и получает сообщения" $ do
      logger <- newLogger
      logMessage logger "Первое"
      logMessage logger "Второе"
      logMessage logger "Третье"
      msgs <- flushLog logger
      msgs `shouldBe` ["Первое", "Второе", "Третье"]

    it "после flush канал пуст" $ do
      logger <- newLogger
      logMessage logger "Тест"
      _ <- flushLog logger
      msgs <- flushLog logger
      msgs `shouldBe` []

  describe "Упражнение 7: raceAll" $ do
    it "возвращает результат самого быстрого действия" $ do
      result <-
        raceAll
          [ threadDelay 500_000 >> pure "медленный"
          , threadDelay 10_000 >> pure "быстрый"
          , threadDelay 1_000_000 >> pure "очень медленный"
          ]
      result `shouldBe` "быстрый"

    it "работает с одним действием" $ do
      result <- raceAll [pure (42 :: Int)]
      result `shouldBe` 42
