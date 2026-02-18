module Solutions where

import Data.AddressBook (AddressBook, Entry(..), Address(..))
import Data.Maybe (listToMaybe)
import Data.List (nubBy)

-- | Найти запись по названию улицы.
findEntryByStreet :: String -> AddressBook -> Maybe Entry
findEntryByStreet streetName = listToMaybe . filter (\e -> street (address e) == streetName)

-- | Проверить, есть ли запись с данным именем и фамилией в адресной книге.
entryExists :: String -> String -> AddressBook -> Bool
entryExists first last = any (\e -> firstName e == first && lastName e == last)

-- | Удалить дубликаты по имени и фамилии (сохраняет первое вхождение).
removeDuplicates :: AddressBook -> AddressBook
removeDuplicates = nubBy sameName
  where
    sameName e1 e2 = firstName e1 == firstName e2 && lastName e1 == lastName e2
