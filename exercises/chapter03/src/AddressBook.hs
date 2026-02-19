module AddressBook where

import Data.List (find)

-- | Адресная книга — список записей.
type AddressBook = [Entry]

-- | Запись адресной книги.
data Entry = Entry
  { firstName :: String
  , lastName :: String
  , address :: Address
  }
  deriving (Show, Eq)

-- | Адрес.
data Address = Address
  { street :: String
  , city :: String
  , state :: String
  }
  deriving (Show, Eq)

-- | Найти запись по имени и фамилии.
findEntry :: String -> String -> AddressBook -> Maybe Entry
findEntry first last =
  find (\e -> firstName e == first && lastName e == last)

-- | Примеры записей для тестирования.
exampleBook :: AddressBook
exampleBook =
  [ Entry "John" "Smith" (Address "123 Main St" "NY" "NY")
  , Entry "Jane" "Doe" (Address "456 Oak Ave" "LA" "CA")
  , Entry "John" "Smith" (Address "789 Pine Rd" "SF" "CA")
  ]
