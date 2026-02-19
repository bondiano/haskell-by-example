{-# HLINT ignore "Functor law" #-}
module Main where

import Data.Text (Text)
import Data.Text qualified as T
import Test.Hspec

import MySolutions
import TaskTracker

main :: IO ()
main = hspec $ do
  -- ===========================================================
  -- Validation: Functor
  -- ===========================================================
  describe "Validation Functor" $ do
    it "fmap над Success применяет функцию" $
      fmap (+ 1) (Success 5 :: Validation [String] Int) `shouldBe` Success 6

    it "fmap над Failure не меняет ошибку" $
      fmap (+ 1) (Failure ["err"] :: Validation [String] Int) `shouldBe` Failure ["err"]

    it "закон identity: fmap id == id" $
      fmap id (Success 42 :: Validation [String] Int) `shouldBe` Success 42

    it "закон композиции: fmap (f . g) == fmap f . fmap g" $
      let val = Success 3 :: Validation [String] Int
       in fmap ((* 2) . (+ 1)) val `shouldBe` (fmap (* 2) . fmap (+ 1)) val

  -- ===========================================================
  -- Validation: Applicative
  -- ===========================================================
  describe "Validation Applicative" $ do
    it "pure оборачивает значение в Success" $
      (pure 42 :: Validation [String] Int) `shouldBe` Success 42

    it "Success <*> Success применяет функцию" $
      (Success (+ 1) <*> Success 5 :: Validation [String] Int) `shouldBe` Success 6

    it "Failure <*> Success сохраняет ошибку" $
      (Failure ["e1"] <*> Success 5 :: Validation [String] Int) `shouldBe` Failure ["e1"]

    it "Success <*> Failure сохраняет ошибку" $
      (Success (+ 1) <*> Failure ["e2"] :: Validation [String] Int) `shouldBe` Failure ["e2"]

    it "Failure <*> Failure объединяет ошибки" $
      (Failure ["e1"] <*> Failure ["e2"] :: Validation [String] Int)
        `shouldBe` Failure ["e1", "e2"]

    it "несколько Failure собирают все ошибки" $
      let f = Failure ["a"] :: Validation [String] (Int -> Int -> Int)
          x = Failure ["b"] :: Validation [String] Int
          y = Failure ["c"] :: Validation [String] Int
       in (f <*> x <*> y) `shouldBe` Failure ["a", "b", "c"]

  -- ===========================================================
  -- Упражнение 1: validateTitle
  -- ===========================================================
  describe "Упражнение 1: validateTitle" $ do
    it "корректный заголовок → Success" $
      validateTitle "Купить молоко" `shouldBe` Success "Купить молоко"

    it "пустой заголовок → Failure" $
      validateTitle "" `shouldBe` Failure ["Заголовок не может быть пустым"]

    it "заголовок длиннее 100 символов → Failure" $
      validateTitle (T.replicate 101 "x")
        `shouldBe` Failure ["Заголовок не может быть длиннее 100 символов"]

    it "заголовок ровно 100 символов → Success" $
      validateTitle (T.replicate 100 "x")
        `shouldBe` Success (T.replicate 100 "x")

  -- ===========================================================
  -- Упражнение 2: validatePriority
  -- ===========================================================
  describe "Упражнение 2: validatePriority" $ do
    it "парсит \"low\" как Low" $
      validatePriority "low" `shouldBe` Success Low

    it "парсит \"medium\" как Medium" $
      validatePriority "medium" `shouldBe` Success Medium

    it "парсит \"high\" как High" $
      validatePriority "high" `shouldBe` Success High

    it "регистронезависимый: \"HIGH\"" $
      validatePriority "HIGH" `shouldBe` Success High

    it "регистронезависимый: \"Medium\"" $
      validatePriority "Medium" `shouldBe` Success Medium

    it "неизвестный приоритет → Failure" $
      validatePriority "urgent" `shouldBe` Failure ["Неизвестный приоритет: urgent"]

    it "пустая строка → Failure" $
      validatePriority "" `shouldBe` Failure ["Неизвестный приоритет: "]

  -- ===========================================================
  -- Упражнение 3: validateTaskInput
  -- ===========================================================
  describe "Упражнение 3: validateTaskInput" $ do
    it "все поля валидны → Success Task" $
      validateTaskInput "Купить молоко" "Из магазина" "high"
        `shouldBe` Success (Task "Купить молоко" "Из магазина" High Todo)

    it "невалидный заголовок → одна ошибка" $
      validateTaskInput "" "Описание" "low"
        `shouldBe` Failure ["Заголовок не может быть пустым"]

    it "невалидный приоритет → одна ошибка" $
      validateTaskInput "Задача" "Описание" "urgent"
        `shouldBe` Failure ["Неизвестный приоритет: urgent"]

    it "оба поля невалидны → все ошибки собираются" $
      validateTaskInput "" "Описание" "urgent"
        `shouldBe` Failure
          [ "Заголовок не может быть пустым"
          , "Неизвестный приоритет: urgent"
          ]

  -- ===========================================================
  -- Упражнение 4: Labelled Functor
  -- ===========================================================
  describe "Упражнение 4: Labelled Functor" $ do
    it "fmap применяет функцию к значению" $
      fmap (+ 1) (Labelled "x" 5) `shouldBe` Labelled "x" 6

    it "fmap сохраняет метку" $
      fmap show (Labelled "координата" (3 :: Int)) `shouldBe` Labelled "координата" "3"

    it "закон identity" $
      fmap id (Labelled "m" 42) `shouldBe` Labelled "m" (42 :: Int)

  -- ===========================================================
  -- Упражнение 5: RoseTree Functor
  -- ===========================================================
  describe "Упражнение 5: RoseTree Functor" $ do
    it "fmap над листом (без потомков)" $
      fmap (+ 1) (RoseNode 1 []) `shouldBe` RoseNode 2 ([] :: [RoseTree Int])

    it "fmap над деревом с потомками" $
      fmap (* 2) (RoseNode 1 [RoseNode 2 [], RoseNode 3 []])
        `shouldBe` RoseNode 2 [RoseNode 4 [], RoseNode 6 []]

    it "fmap над вложенным деревом" $
      fmap (+ 10) (RoseNode 1 [RoseNode 2 [RoseNode 3 []]])
        `shouldBe` RoseNode 11 [RoseNode 12 [RoseNode 13 []]]

    it "закон identity" $
      let tree = RoseNode 1 [RoseNode 2 [], RoseNode 3 [RoseNode 4 []]]
       in fmap id tree `shouldBe` (tree :: RoseTree Int)

  -- ===========================================================
  -- Упражнение 6: Labelled Applicative
  -- ===========================================================
  describe "Упражнение 6: Labelled Applicative" $ do
    it "pure создаёт Labelled с пустой меткой" $
      (pure 42 :: Labelled Int) `shouldBe` Labelled "" 42

    it "<*> применяет функцию и объединяет метки" $
      (Labelled "f" (+ 1) <*> Labelled "x" 5) `shouldBe` Labelled "fx" 6

    it "<*> с пустыми метками" $
      (Labelled "" (* 2) <*> Labelled "" 3) `shouldBe` Labelled "" (6 :: Int)

    it "liftA2 объединяет метки" $
      let add = Labelled "сумма:" (+)
          x = Labelled "[1]" (1 :: Int)
          y = Labelled "[2]" 2
       in (add <*> x <*> y) `shouldBe` Labelled "сумма:[1][2]" 3
