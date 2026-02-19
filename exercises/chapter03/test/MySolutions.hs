module MySolutions where

import AddressBook (Address (..), AddressBook, Entry (..))
import Data.List (nubBy)
import Data.Maybe (listToMaybe)
import TaskTracker (Priority (..), Status (..), Task (..), TaskList)

-- | Найти запись по названию улицы.
findEntryByStreet :: String -> AddressBook -> Maybe Entry
findEntryByStreet = undefined

-- | Проверить, есть ли запись с данным именем и фамилией.
entryExists :: String -> String -> AddressBook -> Bool
entryExists = undefined

-- | Удалить дубликаты по имени и фамилии (сохранить первое вхождение).
removeDuplicates :: AddressBook -> AddressBook
removeDuplicates = undefined

{- | Описать статус задачи на русском языке.
Todo → "[ ] К выполнению", InProgress → "[~] В работе", Done → "[x] Готово"
-}
describeStatus :: Status -> String
describeStatus = undefined

-- | Срочная задача: высокий приоритет И не завершена.
isUrgent :: Task -> Bool
isUrgent = undefined

-- | Перевести статус в следующий: Todo → InProgress → Done → Done.
nextStatus :: Status -> Status
nextStatus = undefined

{- | Описать список задач: "N задач(и), из них M срочных"
Срочная = High приоритет И статус не Done.
-}
describeTasks :: TaskList -> String
describeTasks = undefined
