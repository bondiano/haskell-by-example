module Solutions where

import Data.List (isInfixOf)
import TaskTracker

-- | Упражнение 1: Вычисление типобезопасных выражений (базовое).
eval :: Expr a -> a
eval (LitInt n) = n
eval (LitBool b) = b
eval (Add e1 e2) = eval e1 + eval e2
eval (If cond t f) = if eval cond then eval t else eval f
eval (Equal e1 e2) = eval e1 == eval e2
eval (Not e) = not (eval e)

-- | Упражнение 2: Расширенный eval с Equal и Not.
evalFull :: Expr a -> a
evalFull (LitInt n) = n
evalFull (LitBool b) = b
evalFull (Add e1 e2) = evalFull e1 + evalFull e2
evalFull (If cond t f) = if evalFull cond then evalFull t else evalFull f
evalFull (Equal e1 e2) = evalFull e1 == evalFull e2
evalFull (Not e) = not (evalFull e)

-- | Упражнение 3: QueryBuilder.
newQuery :: QueryBuilder Building
newQuery = NewQuery

addFilter :: String -> QueryBuilder Building -> QueryBuilder Building
addFilter = WithFilter

buildQuery :: QueryBuilder Building -> QueryBuilder Ready
buildQuery = Built

{- | execute — применение к списку задач.
  Упрощённая реализация: каждый фильтр — подстрока в заголовке задачи.
-}
execute :: QueryBuilder Ready -> [Task] -> [Task]
execute (Built qb) = filter (matchAll (collectFilters qb))
 where
  collectFilters :: QueryBuilder Building -> [String]
  collectFilters NewQuery = []
  collectFilters (WithFilter s rest) = s : collectFilters rest

  matchAll :: [String] -> Task -> Bool
  matchAll filters task = all (\f -> f `isInfixOf` taskTitle task) filters

-- | Упражнение 4: SafeList — безопасный head.
safeHead :: SafeList 'NonEmpty a -> a
safeHead (Cons x _) = x

-- | Упражнение 5: Сложение натуральных чисел на уровне значений.
addNat :: Nat -> Nat -> Nat
addNat Z m = m
addNat (S n) m = S (addNat n m)

-- | Упражнение 6: Реализация HasKey.
instance HasKey Task where
  type Key Task = Text
  getKey = taskTitle

instance HasKey (k, v) where
  type Key (k, v) = k
  getKey = fst
