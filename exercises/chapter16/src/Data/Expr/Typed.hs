module Data.Expr.Typed
  ( Expr(..)
  ) where

-- | Типобезопасное выражение.
--
-- Каждый конструктор явно задаёт возвращаемый тип выражения.
-- При сопоставлении с образцом GHC «уточняет» переменную типа @a@.
data Expr a where
  -- | Целочисленный литерал.
  ILit :: Int -> Expr Int
  -- | Булев литерал.
  BLit :: Bool -> Expr Bool
  -- | Сложение двух целочисленных выражений.
  Add  :: Expr Int -> Expr Int -> Expr Int
  -- | Проверка на равенство. Требует @Eq a@.
  Eql  :: Eq a => Expr a -> Expr a -> Expr Bool
  -- | Условное выражение: @if c then t else e@.
  If   :: Expr Bool -> Expr a -> Expr a -> Expr a
  -- | Логическое отрицание.
  Not  :: Expr Bool -> Expr Bool
  -- | Логическое «и».
  And  :: Expr Bool -> Expr Bool -> Expr Bool
  -- | Сравнение «больше». Требует @Ord a@.
  Gt   :: Ord a => Expr a -> Expr a -> Expr Bool
