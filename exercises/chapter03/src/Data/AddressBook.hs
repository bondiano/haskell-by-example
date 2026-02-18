module Data.AddressBook where

import Data.Maybe (listToMaybe)

data Address = Address
  { street :: String
  , city   :: String
  , state  :: String
  } deriving (Show, Eq)

data Entry = Entry
  { firstName :: String
  , lastName  :: String
  , address   :: Address
  } deriving (Show, Eq)

type AddressBook = [Entry]

-- | Отформатировать адрес в строку.
showAddress :: Address -> String
showAddress addr =
  street addr <> ", " <> city addr <> ", " <> state addr

-- | Отформатировать запись адресной книги в строку.
showEntry :: Entry -> String
showEntry entry =
  lastName entry <> ", " <> firstName entry <> ": " <> showAddress (address entry)

-- | Пустая адресная книга.
emptyBook :: AddressBook
emptyBook = []

-- | Добавить запись в адресную книгу.
insertEntry :: Entry -> AddressBook -> AddressBook
insertEntry = (:)

-- | Найти запись по имени и фамилии.
findEntry :: String -> String -> AddressBook -> Maybe Entry
findEntry first last = listToMaybe . filter filterEntry
  where
    filterEntry entry = firstName entry == first && lastName entry == last
