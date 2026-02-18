module Main where

import Test.Hspec
import Data.Path
import MySolutions (allFiles, largestFile, whereIs, totalSize, strictFoldl)

main :: IO ()
main = hspec $ do
  describe "allPaths (предоставлено)" $ do
    it "корень содержит все узлы" $
      length (allPaths root) `shouldBe` 15

  describe "allFiles" $ do
    it "возвращает только файлы" $
      all (not . isDirectory) (allFiles root) `shouldBe` True

    it "находит 9 файлов в root" $
      length (allFiles root) `shouldBe` 9

    it "пустой каталог не содержит файлов" $
      allFiles (Directory "empty" []) `shouldBe` []

    it "одиночный файл возвращает себя" $
      allFiles (File "a" 10) `shouldBe` [File "a" 10]

  describe "largestFile" $ do
    it "находит самый большой файл в root" $ do
      let result = largestFile root
      fmap snd result `shouldBe` Just 34700
      fmap (filename . fst) result `shouldBe` Just "ls"

    it "возвращает Nothing для пустого каталога" $
      largestFile (Directory "empty" []) `shouldBe` Nothing

    it "работает с одним файлом" $
      largestFile (File "x" 42) `shouldBe` Just (File "x" 42, 42)

  describe "whereIs" $ do
    it "находит файл ls в /bin" $ do
      let result = whereIs root "ls"
      fmap filename result `shouldBe` Just "bin"

    it "находит файл hosts в /etc" $ do
      let result = whereIs root "hosts"
      fmap filename result `shouldBe` Just "etc"

    it "находит файл во вложенном каталоге" $ do
      let result = whereIs root "Main.hs"
      fmap filename result `shouldBe` Just "projects"

    it "возвращает Nothing для несуществующего файла" $
      whereIs root "cat" `shouldBe` Nothing

  describe "totalSize" $ do
    it "суммарный размер всех файлов в root" $
      totalSize root `shouldBe` 89660

    it "размер одного файла" $
      totalSize (File "x" 100) `shouldBe` 100

    it "пустой каталог имеет размер 0" $
      totalSize (Directory "empty" []) `shouldBe` 0

  describe "strictFoldl" $ do
    it "суммирует элементы списка" $
      strictFoldl (+) 0 [1..100] `shouldBe` (5050 :: Int)

    it "работает с пустым списком" $
      strictFoldl (+) 0 [] `shouldBe` (0 :: Int)

    it "произведение элементов" $
      strictFoldl (*) 1 [1..10] `shouldBe` (3628800 :: Int)

    it "конкатенация строк" $
      strictFoldl (\acc x -> acc ++ show x) "" [1..5]
        `shouldBe` "12345"

    it "работает на большом списке без переполнения стека" $
      strictFoldl (+) 0 [1..1000000] `shouldBe` (500000500000 :: Int)
