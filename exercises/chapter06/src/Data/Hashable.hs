module Data.Hashable
  ( Hashable(..)
  , combineHashes
  , Coord(..)
  ) where

-- | Класс типов для хэширования значений.
-- Минимальное определение: @hash@.
class Hashable a where
  hash :: a -> Int

-- | Комбинирование двух хэш-значений.
-- Использует множитель 31 — классический приём, дающий хорошее распределение.
combineHashes :: Int -> Int -> Int
combineHashes h1 h2 = h1 * 31 + h2

instance Hashable Int where
  hash = id

instance Hashable Bool where
  hash True  = 1
  hash False = 0

instance Hashable Char where
  hash = fromEnum

instance (Hashable a, Hashable b) => Hashable (a, b) where
  hash (a, b) = combineHashes (hash a) (hash b)

-- | Координата на плоскости.
-- Экземпляры 'Eq' и 'Show' не определены — это упражнение 1.
data Coord = Coord
  { coordX :: Double
  , coordY :: Double
  }
