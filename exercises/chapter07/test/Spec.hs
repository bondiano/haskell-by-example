module Main where

import Test.Hspec
import Data.Either (isLeft)
import Data.AddressBook
import MySolutions

main :: IO ()
main = hspec $ do
  describe "validateAddress (предоставлено)" $ do
    it "валидный адрес" $
      validateAddress "Ленина 1" "Москва" "МО"
        `shouldBe` Success (Address "Ленина 1" "Москва" "МО")

    it "все поля пустые — три ошибки" $
      errorCount (validateAddress "" "" "") `shouldBe` 3

  describe "validatePhoneNumber (упражнение 1)" $ do
    it "корректный номер" $
      validatePhoneNumber "1234567" `shouldBe` Success "1234567"

    it "длинный номер тоже корректен" $
      validatePhoneNumber "12345678901" `shouldBe` Success "12345678901"

    it "пустой номер — ошибка" $
      validatePhoneNumber "" `shouldSatisfy` isFailure

    it "содержит буквы — ошибка" $
      validatePhoneNumber "123abc7" `shouldSatisfy` isFailure

    it "слишком короткий — ошибка" $
      validatePhoneNumber "123" `shouldSatisfy` isFailure

    it "короткий с буквами — две ошибки (накопление)" $
      errorCount (validatePhoneNumber "ab") `shouldBe` 2

  describe "validatePerson (упражнение 2)" $ do
    it "все поля валидны" $
      validatePerson "Иван" "Петров" "Ленина 1" "Москва" "МО"
        `shouldBe` Success (Person "Иван" "Петров" (Address "Ленина 1" "Москва" "МО"))

    it "пустое имя — одна ошибка" $
      errorCount (validatePerson "" "Петров" "Ленина 1" "Москва" "МО") `shouldBe` 1

    it "пустые имя и фамилия — две ошибки" $
      errorCount (validatePerson "" "" "Ленина 1" "Москва" "МО") `shouldBe` 2

    it "все поля пустые — пять ошибок (все накопились)" $
      errorCount (validatePerson "" "" "" "" "") `shouldBe` 5

  describe "traverseWithIndex (упражнение 3)" $ do
    it "пустой список" $
      traverseWithIndex (\_ x -> Just x) ([] :: [Int]) `shouldBe` Just []

    it "сохраняет индексы" $
      traverseWithIndex (\i x -> Just (i, x)) ["a", "b", "c"]
        `shouldBe` Just [(0, "a"), (1, "b"), (2, "c")]

    it "Nothing прерывает обход" $
      traverseWithIndex (\_ x -> if x > 0 then Just x else Nothing) [1, 0, 3 :: Int]
        `shouldBe` Nothing

    it "с Validation — ошибки накапливаются" $
      traverseWithIndex
        (\i s -> if null (s :: String) then Failure [show i] else Success s)
        ["a", "", "c", ""]
        `shouldBe` Failure ["1", "3"]

  describe "eitherValidateAddress (упражнение 4)" $ do
    it "валидный адрес" $
      eitherValidateAddress "Ленина 1" "Москва" "МО"
        `shouldBe` Right (Address "Ленина 1" "Москва" "МО")

    it "все пустые — только первая ошибка (fail-fast)" $
      eitherValidateAddress "" "" "" `shouldSatisfy` isLeft

  describe "validatePersonEither (упражнение 4)" $ do
    it "все поля валидны" $
      validatePersonEither "Иван" "Петров" "Ленина 1" "Москва" "МО"
        `shouldBe` Right (Person "Иван" "Петров" (Address "Ленина 1" "Москва" "МО"))

    it "все пустые — только первая ошибка (fail-fast)" $
      validatePersonEither "" "" "" "" "" `shouldSatisfy` isLeft

    it "контраст: Validation собирает 5 ошибок, Either — 1" $ do
      let v = validatePerson "" "" "" "" ""
          e = validatePersonEither "" "" "" "" ""
      errorCount v `shouldBe` 5
      e `shouldSatisfy` isLeft
