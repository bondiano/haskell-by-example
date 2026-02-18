module Main where

import Test.Hspec
import Control.Concurrent (threadDelay)
import Control.Concurrent.Async (mapConcurrently)
import System.Directory (removeFile, getTemporaryDirectory)
import Concurrent (countWords, timed)
import MySolutions

main :: IO ()
main = hspec $ do
  describe "countWords (предоставлено)" $ do
    it "считает слова в строке" $
      countWords "hello world" `shouldBe` 2

    it "пустая строка — 0 слов" $
      countWords "" `shouldBe` 0

  describe "concurrentSum (упражнение 1)" $ do
    it "суммирует подсписки параллельно" $ do
      result <- concurrentSum [[1, 2, 3], [4, 5], [6]]
      result `shouldBe` 21

    it "пустой список подсписков" $ do
      result <- concurrentSum []
      result `shouldBe` 0

    it "один подсписок" $ do
      result <- concurrentSum [[10, 20, 30]]
      result `shouldBe` 60

    it "подсписки с нулями" $ do
      result <- concurrentSum [[0, 0], [0], [1]]
      result `shouldBe` 1

  describe "withTimeout (упражнение 2)" $ do
    it "быстрое действие возвращает Just" $ do
      result <- withTimeout 1_000_000 (return 42 :: IO Int)
      result `shouldBe` Just 42

    it "медленное действие возвращает Nothing" $ do
      result <- withTimeout 50_000 (threadDelay 1_000_000 >> return 42 :: IO Int)
      result `shouldBe` Nothing

  describe "concurrentWordCount (упражнение 3)" $ do
    it "считает слова в нескольких файлах" $ do
      tmpDir <- getTemporaryDirectory
      let f1 = tmpDir <> "/hbe-ch09-a.txt"
          f2 = tmpDir <> "/hbe-ch09-b.txt"
      writeFile f1 "один два три"
      writeFile f2 "четыре пять"
      result <- concurrentWordCount [f1, f2]
      lookup f1 result `shouldBe` Just 3
      lookup f2 result `shouldBe` Just 2
      removeFile f1
      removeFile f2

    it "пустой список файлов" $ do
      result <- concurrentWordCount []
      result `shouldBe` []

  describe "mapConcurrentlyLimited (упражнение 4)" $ do
    it "возвращает те же результаты, что и mapConcurrently" $ do
      let f x = return (x * 2) :: IO Int
      expected <- mapConcurrently f [1..10]
      result <- mapConcurrentlyLimited 3 f [1..10]
      result `shouldBe` expected

    it "ограничение 1 — последовательное выполнение" $ do
      let f x = threadDelay 10_000 >> return x :: IO Int
      result <- mapConcurrentlyLimited 1 f [1..5]
      result `shouldBe` [1..5]

    it "пустой вход" $ do
      result <- mapConcurrentlyLimited 2 (\x -> return (x :: Int)) []
      result `shouldBe` []
