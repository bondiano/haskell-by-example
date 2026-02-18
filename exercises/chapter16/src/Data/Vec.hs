module Data.Vec
  ( Nat(..)
  , Vec(..)
  , Add
  ) where

import Data.Kind (Type)

-- | Натуральные числа на уровне типов.
data Nat = Zero | Succ Nat

-- | Сложение натуральных чисел (вычисление на уровне типов).
type family Add (a :: Nat) (b :: Nat) :: Nat where
  Add 'Zero     b = b
  Add ('Succ a) b = 'Succ (Add a b)

-- | Вектор с длиной, закодированной в типе.
--
-- @Vec 'Zero a@ — пустой вектор.
-- @Vec ('Succ n) a@ — непустой вектор.
data Vec (n :: Nat) (a :: Type) where
  VNil  :: Vec 'Zero a
  VCons :: a -> Vec n a -> Vec ('Succ n) a

deriving instance Show a => Show (Vec n a)
deriving instance Eq a => Eq (Vec n a)
