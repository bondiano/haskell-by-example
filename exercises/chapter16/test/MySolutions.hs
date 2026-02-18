{-# OPTIONS_GHC -Wno-orphans #-}

module MySolutions where

import Data.List (foldl')
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set

import Data.Expr.Typed
import Data.Vec
import Data.Container

-- Упражнение 1: вычислитель выражений
--
-- Реализуйте eval :: Expr a -> a.
-- При матчинге на ILit компилятор знает, что a ~ Int.
-- При матчинге на BLit — a ~ Bool. И так далее.
-- Функция тотальна: все случаи покрыты, типы гарантированы.

eval :: Expr a -> a
eval = undefined

-- Упражнение 2: красивая печать выражений
--
-- Реализуйте prettyExpr :: Expr a -> String.
-- Формат:
--   ILit n   → show n
--   BLit b   → show b
--   Add x y  → "(x + y)"
--   Eql x y  → "(x == y)"
--   If c t e → "(if c then t else e)"
--   Not x    → "(not x)"
--   And x y  → "(x && y)"
--   Gt x y   → "(x > y)"

prettyExpr :: Expr a -> String
prettyExpr = undefined

-- Упражнение 3: Container с ассоциированным семейством типов
--
-- Напишите экземпляры Container для:
--   [a]       — Elem [a] = a
--   Set a     — Elem (Set a) = a
--   Map k v   — Elem (Map k v) = (k, v)
--
-- Затем реализуйте containerFromList через foldl', insert и empty.

-- instance Container [a] where ...
-- instance Ord a => Container (Set.Set a) where ...
-- instance Ord k => Container (Map.Map k v) where ...

containerFromList :: Container c => [Elem c] -> c
containerFromList = undefined

-- Упражнение 4: вектор с длиной в типе
--
-- Реализуйте операции на Vec n a:
--   vhead   — голова непустого вектора (тотальная!)
--   vtail   — хвост непустого вектора
--   vzip    — поэлементное объединение (длины совпадают по типу)
--   vappend — конкатенация (длина результата = Add n m)

vhead :: Vec ('Succ n) a -> a
vhead = undefined

vtail :: Vec ('Succ n) a -> Vec n a
vtail = undefined

vzip :: Vec n a -> Vec n b -> Vec n (a, b)
vzip = undefined

vappend :: Vec n a -> Vec m a -> Vec (Add n m) a
vappend = undefined
