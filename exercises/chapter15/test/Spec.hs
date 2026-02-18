module Main where

import Test.Hspec
import Data.Either (isLeft)
import Data.Map.Strict qualified as Map
import Language.Expr (Expr(..))
import Language.Json (JValue(..))

import MySolutions

main :: IO ()
main = hspec $ do
  describe "Упражнение 1: вычислитель выражений" $ do
    it "вычисляет литерал" $
      eval (Lit 42) `shouldBe` Right 42
    it "вычисляет сложение" $
      eval (Add (Lit 1) (Lit 2)) `shouldBe` Right 3
    it "вычисляет вычитание" $
      eval (Sub (Lit 10) (Lit 4)) `shouldBe` Right 6
    it "вычисляет умножение" $
      eval (Mul (Lit 3) (Lit 7)) `shouldBe` Right 21
    it "вычисляет деление" $
      eval (Div (Lit 10) (Lit 4)) `shouldBe` Right 2.5
    it "вычисляет унарный минус" $
      eval (Neg (Lit 5)) `shouldBe` Right (-5)
    it "вычисляет вложенное выражение" $
      eval (Mul (Add (Lit 2) (Lit 3)) (Sub (Lit 10) (Lit 4)))
        `shouldBe` Right 30
    it "деление на ноль возвращает ошибку" $
      eval (Div (Lit 10) (Lit 0)) `shouldBe` Left "division by zero"
    it "переменная без окружения возвращает ошибку" $
      eval (Var "x") `shouldSatisfy` isLeft
    it "let без окружения возвращает ошибку" $
      eval (Let "x" (Lit 1) (Var "x")) `shouldSatisfy` isLeft

  describe "Упражнение 2: оптимизатор AST" $ do
    it "0 + x → x" $
      optimize (Add (Lit 0) (Var "x")) `shouldBe` Var "x"
    it "x + 0 → x" $
      optimize (Add (Var "x") (Lit 0)) `shouldBe` Var "x"
    it "0 * x → Lit 0" $
      optimize (Mul (Lit 0) (Var "x")) `shouldBe` Lit 0
    it "x * 0 → Lit 0" $
      optimize (Mul (Var "x") (Lit 0)) `shouldBe` Lit 0
    it "1 * x → x" $
      optimize (Mul (Lit 1) (Var "x")) `shouldBe` Var "x"
    it "x * 1 → x" $
      optimize (Mul (Var "x") (Lit 1)) `shouldBe` Var "x"
    it "x - 0 → x" $
      optimize (Sub (Var "x") (Lit 0)) `shouldBe` Var "x"
    it "Neg (Neg x) → x" $
      optimize (Neg (Neg (Var "x"))) `shouldBe` Var "x"
    it "рекурсивная оптимизация: 1 * (0 + y) → y" $
      optimize (Mul (Lit 1) (Add (Lit 0) (Var "y"))) `shouldBe` Var "y"
    it "не затрагивает выражения без упрощений" $
      optimize (Add (Var "x") (Var "y")) `shouldBe` Add (Var "x") (Var "y")

  describe "Упражнение 3: парсер JSON" $ do
    it "парсит null" $
      parseJson "null" `shouldBe` Right JNull
    it "парсит true" $
      parseJson "true" `shouldBe` Right (JBool True)
    it "парсит false" $
      parseJson "false" `shouldBe` Right (JBool False)
    it "парсит целое число" $
      parseJson "42" `shouldBe` Right (JNumber 42)
    it "парсит дробное число" $
      parseJson "3.14" `shouldBe` Right (JNumber 3.14)
    it "парсит строку" $
      parseJson "\"hello\"" `shouldBe` Right (JString "hello")
    it "парсит пустой массив" $
      parseJson "[]" `shouldBe` Right (JArray [])
    it "парсит массив значений" $
      parseJson "[1, true, null]" `shouldBe`
        Right (JArray [JNumber 1, JBool True, JNull])
    it "парсит пустой объект" $
      parseJson "{}" `shouldBe` Right (JObject [])
    it "парсит объект" $
      parseJson "{\"name\": \"Alice\", \"age\": 30}" `shouldBe`
        Right (JObject [("name", JString "Alice"), ("age", JNumber 30)])
    it "парсит вложенные структуры" $
      parseJson "{\"a\": [1, {\"b\": 2}]}" `shouldBe`
        Right (JObject [("a", JArray [JNumber 1, JObject [("b", JNumber 2)]])])

  describe "Упражнение 4: вычислитель с переменными" $ do
    it "вычисляет литерал" $
      evalWithVars Map.empty (Lit 42) `shouldBe` Right 42
    it "находит переменную в окружении" $
      evalWithVars (Map.singleton "x" 10) (Var "x") `shouldBe` Right 10
    it "ошибка для неизвестной переменной" $
      evalWithVars Map.empty (Var "x") `shouldBe` Left "undefined variable: x"
    it "вычисляет let-привязку" $
      evalWithVars Map.empty (Let "x" (Lit 5) (Add (Var "x") (Lit 3)))
        `shouldBe` Right 8
    it "let перекрывает внешнюю переменную" $
      evalWithVars (Map.singleton "x" 1) (Let "x" (Lit 99) (Var "x"))
        `shouldBe` Right 99
    it "вложенные let-привязки" $
      evalWithVars Map.empty
        (Let "x" (Lit 2) (Let "y" (Lit 3) (Mul (Var "x") (Var "y"))))
        `shouldBe` Right 6
    it "деление на ноль с переменными" $
      evalWithVars (Map.singleton "x" 0) (Div (Lit 1) (Var "x"))
        `shouldBe` Left "division by zero"
