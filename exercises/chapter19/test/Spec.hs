module Main where

import MySolutions
import TaskTracker
import Test.Hspec

main :: IO ()
main = hspec $ do
  -- Тестовые данные
  let task1 = Task "Купить молоко" Low Todo
      task2 = Task "Написать отчёт" High InProgress
      task3 = Task "Полить цветы" Medium Done
      task4 = Task "Подготовить презентацию" High Todo

  describe "Упражнение 1: eval (базовый)" $ do
    it "вычисляет LitInt 42" $
      eval (LitInt 42) `shouldBe` 42

    it "вычисляет LitBool True" $
      eval (LitBool True) `shouldBe` True

    it "вычисляет LitBool False" $
      eval (LitBool False) `shouldBe` False

    it "вычисляет Add (LitInt 1) (LitInt 2)" $
      eval (Add (LitInt 1) (LitInt 2)) `shouldBe` 3

    it "вычисляет вложенный Add" $
      eval (Add (Add (LitInt 1) (LitInt 2)) (LitInt 3)) `shouldBe` 6

    it "вычисляет If True" $
      eval (If (LitBool True) (LitInt 1) (LitInt 2)) `shouldBe` 1

    it "вычисляет If False" $
      eval (If (LitBool False) (LitInt 1) (LitInt 2)) `shouldBe` 2

    it "вычисляет вложенный If" $
      eval (If (LitBool True) (If (LitBool False) (LitInt 10) (LitInt 20)) (LitInt 30))
        `shouldBe` 20

  describe "Упражнение 2: evalFull (с Equal и Not)" $ do
    it "Equal: одинаковые числа" $
      evalFull (Equal (LitInt 5) (LitInt 5)) `shouldBe` True

    it "Equal: разные числа" $
      evalFull (Equal (LitInt 3) (LitInt 7)) `shouldBe` False

    it "Equal: результат сложения" $
      evalFull (Equal (Add (LitInt 2) (LitInt 3)) (LitInt 5)) `shouldBe` True

    it "Not True" $
      evalFull (Not (LitBool True)) `shouldBe` False

    it "Not False" $
      evalFull (Not (LitBool False)) `shouldBe` True

    it "Not (Equal ...)" $
      evalFull (Not (Equal (LitInt 1) (LitInt 2))) `shouldBe` True

    it "If с Equal условием" $
      evalFull (If (Equal (LitInt 1) (LitInt 1)) (LitInt 100) (LitInt 200))
        `shouldBe` 100

    it "If с Not условием" $
      evalFull (If (Not (LitBool True)) (LitInt 100) (LitInt 200))
        `shouldBe` 200

    it "evalFull также обрабатывает базовые выражения" $
      evalFull (Add (LitInt 10) (LitInt 20)) `shouldBe` 30

  describe "Упражнение 3: QueryBuilder" $ do
    it "newQuery создаёт пустой билдер" $
      show newQuery `shouldBe` "NewQuery"

    it "addFilter добавляет фильтр" $
      show (addFilter "test" newQuery) `shouldBe` "WithFilter \"test\" NewQuery"

    it "buildQuery финализирует билдер" $
      show (buildQuery newQuery) `shouldBe` "Built NewQuery"

    it "execute на пустом запросе возвращает все задачи" $
      execute (buildQuery newQuery) exampleTasks
        `shouldBe` exampleTasks

    it "execute фильтрует по подстроке в заголовке" $
      execute (buildQuery (addFilter "молоко" newQuery)) exampleTasks
        `shouldBe` [task1]

    it "execute с несколькими фильтрами (AND)" $
      execute (buildQuery (addFilter "Подготовить" (addFilter "презентацию" newQuery))) exampleTasks
        `shouldBe` [task4]

    it "execute без совпадений — пустой список" $
      execute (buildQuery (addFilter "Несуществующая" newQuery)) exampleTasks
        `shouldBe` []

  describe "Упражнение 4: SafeList и safeHead" $ do
    it "safeHead (Cons 1 Nil) == 1" $
      safeHead (Cons (1 :: Int) Nil) `shouldBe` 1

    it "safeHead (Cons 'a' (Cons 'b' Nil)) == 'a'" $
      safeHead (Cons 'a' (Cons 'b' Nil)) `shouldBe` 'a'

    it "safeHead (Cons \"hello\" Nil) == \"hello\"" $
      safeHead (Cons "hello" Nil) `shouldBe` ("hello" :: String)

    it "safeHead (Cons True (Cons False Nil)) == True" $
      safeHead (Cons True (Cons False Nil)) `shouldBe` True

  describe "Упражнение 5: addNat" $ do
    it "Z + Z = Z" $
      addNat Z Z `shouldBe` Z

    it "Z + S Z = S Z" $
      addNat Z (S Z) `shouldBe` S Z

    it "S Z + Z = S Z" $
      addNat (S Z) Z `shouldBe` S Z

    it "S Z + S Z = S (S Z)" $
      addNat (S Z) (S Z) `shouldBe` S (S Z)

    it "S (S Z) + S (S (S Z)) = S (S (S (S (S Z))))" $
      addNat (S (S Z)) (S (S (S Z))) `shouldBe` S (S (S (S (S Z))))

  describe "Упражнение 6: HasKey" $ do
    it "getKey для Task возвращает taskTitle" $
      getKey task1 `shouldBe` "Купить молоко"

    it "getKey для другой Task" $
      getKey task2 `shouldBe` "Написать отчёт"

    it "getKey для кортежа (Int, String)" $
      getKey (42 :: Int, "hello" :: String) `shouldBe` (42 :: Int)

    it "getKey для кортежа (String, Int)" $
      getKey ("ключ" :: String, 100 :: Int) `shouldBe` ("ключ" :: String)

    it "getKey для кортежа (Bool, Char)" $
      getKey (True, 'x') `shouldBe` True
