module Data.Container
  ( Container(..)
  ) where

import Data.Kind (Type)

-- | Обобщённый контейнер с ассоциированным семейством типов @Elem@.
--
-- @Elem c@ определяет тип элементов контейнера @c@.
class Container c where
  type Elem c :: Type
  empty  :: c
  insert :: Elem c -> c -> c
  toList :: c -> [Elem c]
