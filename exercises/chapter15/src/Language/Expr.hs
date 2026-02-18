module Language.Expr
  ( Expr(..)
  , prettyExpr
  ) where

-- | АСД (абстрактное синтаксическое дерево) арифметических выражений
-- с переменными и let-привязками.
data Expr
  = Lit Double            -- ^ Числовой литерал: @42@, @3.14@
  | Var String            -- ^ Переменная: @x@, @foo@
  | Add Expr Expr         -- ^ Сложение: @a + b@
  | Sub Expr Expr         -- ^ Вычитание: @a - b@
  | Mul Expr Expr         -- ^ Умножение: @a * b@
  | Div Expr Expr         -- ^ Деление: @a / b@
  | Neg Expr              -- ^ Унарный минус: @-a@
  | Let String Expr Expr  -- ^ Let-привязка: @let x = e1 in e2@
  deriving (Show, Eq)

-- | Преобразование AST в строку с полной расстановкой скобок.
--
-- >>> prettyExpr (Add (Lit 1) (Mul (Lit 2) (Lit 3)))
-- "(1 + (2 * 3))"
--
-- >>> prettyExpr (Let "x" (Lit 5) (Add (Var "x") (Lit 3)))
-- "let x = 5 in (x + 3)"
prettyExpr :: Expr -> String
prettyExpr (Lit n)
  | n == fromIntegral (round n :: Integer) = show (round n :: Integer)
  | otherwise = show n
prettyExpr (Var x)     = x
prettyExpr (Add a b)   = "(" ++ prettyExpr a ++ " + " ++ prettyExpr b ++ ")"
prettyExpr (Sub a b)   = "(" ++ prettyExpr a ++ " - " ++ prettyExpr b ++ ")"
prettyExpr (Mul a b)   = "(" ++ prettyExpr a ++ " * " ++ prettyExpr b ++ ")"
prettyExpr (Div a b)   = "(" ++ prettyExpr a ++ " / " ++ prettyExpr b ++ ")"
prettyExpr (Neg a)     = "(-" ++ prettyExpr a ++ ")"
prettyExpr (Let x e b) = "let " ++ x ++ " = " ++ prettyExpr e ++ " in " ++ prettyExpr b
