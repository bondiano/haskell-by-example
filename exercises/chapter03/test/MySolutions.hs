module MySolutions where

import Data.AddressBook (AddressBook, Entry(..), Address(..))
import Data.Maybe (listToMaybe)
import Data.List (nubBy)

findEntryByStreet :: String -> AddressBook -> Maybe Entry
findEntryByStreet = undefined

entryExists :: String -> String -> AddressBook -> Bool
entryExists = undefined

removeDuplicates :: AddressBook -> AddressBook
removeDuplicates = undefined
