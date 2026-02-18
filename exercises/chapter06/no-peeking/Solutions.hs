{-# OPTIONS_GHC -Wno-orphans #-}

module Solutions where

import Data.Hashable
import Data.List (foldl')

-- Упражнение 1: ручные экземпляры Eq и Show для Coord

instance Eq Coord where
  Coord x1 y1 == Coord x2 y2 = x1 == x2 && y1 == y2

instance Show Coord where
  show (Coord x y) = "(" <> show x <> ", " <> show y <> ")"

-- Упражнение 2: экземпляры Hashable для Maybe, Either, []

instance Hashable a => Hashable (Maybe a) where
  hash Nothing  = 0
  hash (Just a) = combineHashes 1 (hash a)

instance (Hashable a, Hashable b) => Hashable (Either a b) where
  hash (Left a)  = combineHashes 0 (hash a)
  hash (Right b) = combineHashes 1 (hash b)

instance Hashable a => Hashable [a] where
  hash = foldl' (\acc x -> combineHashes acc (hash x)) 0

-- Упражнение 3: удаление дубликатов

nubByHash :: (Eq a, Hashable a) => [a] -> [a]
nubByHash = go []
  where
    go _ []     = []
    go seen (x:xs)
      | x `elem` seen = go seen xs
      | otherwise      = x : go (x : seen) xs

-- Упражнение 4: DerivingStrategies для Brightness

newtype Brightness = Brightness { getBrightness :: Int }
  deriving stock (Show, Read)
  deriving newtype (Eq, Ord, Num, Hashable)
