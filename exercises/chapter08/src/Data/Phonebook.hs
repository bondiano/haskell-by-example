module Data.Phonebook
  ( Phonebook
  , exampleBook
  ) where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map

-- | Телефонная книга: город → (имя → телефон).
type Phonebook = Map String (Map String String)

-- | Пример телефонной книги для упражнений.
--
-- >>> Map.lookup "Москва" exampleBook >>= Map.lookup "Алиса"
-- Just "+7-495-111-1111"
exampleBook :: Phonebook
exampleBook = Map.fromList
  [ ("Москва", Map.fromList
      [ ("Алиса",  "+7-495-111-1111")
      , ("Борис",  "+7-495-222-2222")
      ])
  , ("Петербург", Map.fromList
      [ ("Виктор", "+7-812-333-3333")
      , ("Галина", "+7-812-444-4444")
      ])
  , ("Казань", Map.fromList
      [ ("Динар",  "+7-843-555-5555")
      ])
  ]
