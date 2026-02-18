{-# OPTIONS_GHC -Wno-orphans #-}

module MySolutions where

import Data.Hashable
import Data.List (foldl')

-- Упражнение 1: ручные экземпляры Eq и Show для Coord

instance Eq Coord where
  (==) = undefined

instance Show Coord where
  show = undefined

-- Упражнение 2: экземпляры Hashable для Maybe, Either, []

instance Hashable a => Hashable (Maybe a) where
  hash = undefined

instance (Hashable a, Hashable b) => Hashable (Either a b) where
  hash = undefined

instance Hashable a => Hashable [a] where
  hash = undefined

-- Упражнение 3: удаление дубликатов

nubByHash :: (Eq a, Hashable a) => [a] -> [a]
nubByHash = undefined

-- Упражнение 4: DerivingStrategies для Brightness

newtype Brightness = Brightness { getBrightness :: Int }

instance Show Brightness where
  show = undefined

instance Eq Brightness where
  (==) = undefined

instance Ord Brightness where
  compare = undefined

instance Num Brightness where
  (+) = undefined
  (*) = undefined
  abs = undefined
  signum = undefined
  fromInteger = undefined
  negate = undefined

instance Hashable Brightness where
  hash = undefined
