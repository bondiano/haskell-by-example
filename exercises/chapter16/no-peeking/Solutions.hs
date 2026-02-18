{-# OPTIONS_GHC -Wno-orphans #-}

module Solutions where

import Data.List (foldl')
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set

import Data.Expr.Typed
import Data.Vec
import Data.Container

-- Упражнение 1: eval

eval :: Expr a -> a
eval (ILit n)   = n
eval (BLit b)   = b
eval (Add x y)  = eval x + eval y
eval (Eql x y)  = eval x == eval y
eval (If c t e) = if eval c then eval t else eval e
eval (Not x)    = not (eval x)
eval (And x y)  = eval x && eval y
eval (Gt x y)   = eval x > eval y

-- Упражнение 2: prettyExpr

prettyExpr :: Expr a -> String
prettyExpr (ILit n)   = show n
prettyExpr (BLit b)   = show b
prettyExpr (Add x y)  = "(" <> prettyExpr x <> " + " <> prettyExpr y <> ")"
prettyExpr (Eql x y)  = "(" <> prettyExpr x <> " == " <> prettyExpr y <> ")"
prettyExpr (If c t e) = "(if " <> prettyExpr c
                         <> " then " <> prettyExpr t
                         <> " else " <> prettyExpr e <> ")"
prettyExpr (Not x)    = "(not " <> prettyExpr x <> ")"
prettyExpr (And x y)  = "(" <> prettyExpr x <> " && " <> prettyExpr y <> ")"
prettyExpr (Gt x y)   = "(" <> prettyExpr x <> " > " <> prettyExpr y <> ")"

-- Упражнение 3: Container

instance Container [a] where
  type Elem [a] = a
  empty = []
  insert x xs = xs ++ [x]
  toList = id

instance Ord a => Container (Set.Set a) where
  type Elem (Set.Set a) = a
  empty = Set.empty
  insert = Set.insert
  toList = Set.toList

instance Ord k => Container (Map.Map k v) where
  type Elem (Map.Map k v) = (k, v)
  empty = Map.empty
  insert (k, v) = Map.insert k v
  toList = Map.toList

containerFromList :: Container c => [Elem c] -> c
containerFromList = foldl' (flip insert) empty

-- Упражнение 4: Vec

vhead :: Vec ('Succ n) a -> a
vhead (VCons x _) = x

vtail :: Vec ('Succ n) a -> Vec n a
vtail (VCons _ xs) = xs

vzip :: Vec n a -> Vec n b -> Vec n (a, b)
vzip VNil VNil = VNil
vzip (VCons a as) (VCons b bs) = VCons (a, b) (vzip as bs)

vappend :: Vec n a -> Vec m a -> Vec (Add n m) a
vappend VNil ys = ys
vappend (VCons x xs) ys = VCons x (vappend xs ys)
