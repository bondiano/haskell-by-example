module Main where

import Test.Hspec
import Control.Lens (view, over, traversed, (^..))

import Data.Company
import MySolutions

sampleAddress :: Address
sampleAddress = Address "Москва" "Тверская" "101000"

samplePerson :: Person
samplePerson = Person "Иван" 30 sampleAddress

main :: IO ()
main = hspec $ do
  describe "getCity (упражнение 1)" $ do
    it "извлекает город из Person" $
      getCity samplePerson `shouldBe` "Москва"

  describe "setCity (упражнение 1)" $ do
    it "устанавливает город" $
      getCity (setCity "Санкт-Петербург" samplePerson)
        `shouldBe` "Санкт-Петербург"

    it "не меняет другие поля" $ do
      let updated = setCity "Казань" samplePerson
      _personName updated `shouldBe` "Иван"
      _personAge updated `shouldBe` 30
      _street (_personAddress updated) `shouldBe` "Тверская"

  describe "upperName (упражнение 1)" $ do
    it "переводит имя в верхний регистр" $
      _personName (upperName samplePerson) `shouldBe` "ИВАН"

    it "не меняет другие поля" $ do
      let updated = upperName samplePerson
      _personAge updated `shouldBe` 30
      getCity updated `shouldBe` "Москва"

  describe "raiseSalary (упражнение 2)" $ do
    it "повышает все зарплаты" $ do
      let updated = raiseSalary 10000 exampleCompany
      let salaries = updated ^.. companyDepartments . traversed
                              . departmentEmployees . traversed
                              . employeeSalary
      salaries `shouldBe` [110000, 100000, 95000]

    it "работает с пустой компанией" $ do
      let empty' = Company "Empty" []
      raiseSalary 5000 empty' `shouldBe` Company "Empty" []

    it "сохраняет имена" $ do
      let updated = raiseSalary 1000 exampleCompany
      let names = updated ^.. companyDepartments . traversed
                            . departmentEmployees . traversed
                            . employeeName
      names `shouldBe` ["Алиса", "Борис", "Вера"]

  describe "rightValues (упражнение 3)" $ do
    it "извлекает Right-значения" $
      rightValues [Left "a", Right 1, Left "b", Right 2]
        `shouldBe` [1, 2]

    it "пустой список" $
      rightValues [] `shouldBe` []

    it "все Left" $
      rightValues [Left "x", Left "y"] `shouldBe` []

    it "все Right" $
      rightValues [Right 10, Right 20] `shouldBe` [10, 20]

  describe "myView (упражнение 4)" $ do
    it "fstL" $
      myView fstL (1 :: Int, 'a') `shouldBe` 1

    it "sndL" $
      myView sndL (1 :: Int, 'a') `shouldBe` 'a'

  describe "mySet (упражнение 4)" $ do
    it "fstL" $
      mySet fstL 10 (1 :: Int, 'a') `shouldBe` (10, 'a')

    it "sndL" $
      mySet sndL 'z' (1 :: Int, 'a') `shouldBe` (1, 'z')

  describe "myOver (упражнение 4)" $ do
    it "fstL" $
      myOver fstL (+ 1) (1 :: Int, 'a') `shouldBe` (2, 'a')

    it "sndL" $
      myOver sndL (const 'z') (1 :: Int, 'a') `shouldBe` (1, 'z')

  describe "композиция MyLens (упражнение 4)" $ do
    it "sndL . fstL — доступ к вложенному полю" $
      myView (sndL . fstL) (1 :: Int, ("hello", True))
        `shouldBe` "hello"

    it "mySet на вложенном поле" $
      mySet (sndL . fstL) "world" (1 :: Int, ("hello", True))
        `shouldBe` (1, ("world", True))
