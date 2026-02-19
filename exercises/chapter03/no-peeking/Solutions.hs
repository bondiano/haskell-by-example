module Solutions where

import AddressBook (Address (..), AddressBook, Entry (..))
import Data.List (find, nubBy)
import TaskTracker (Priority (..), Status (..), Task (..), TaskList)

-- | Найти запись по названию улицы.
findEntryByStreet :: String -> AddressBook -> Maybe Entry
findEntryByStreet streetName = find (\e -> street (address e) == streetName)

-- | Проверить, есть ли запись с данным именем и фамилией.
entryExists :: String -> String -> AddressBook -> Bool
entryExists first last = any (\e -> firstName e == first && lastName e == last)

-- | Удалить дубликаты по имени и фамилии (сохранить первое вхождение).
removeDuplicates :: AddressBook -> AddressBook
removeDuplicates = nubBy sameName
 where
  sameName e1 e2 = firstName e1 == firstName e2 && lastName e1 == lastName e2

-- | Описать статус задачи на русском языке.
describeStatus :: Status -> String
describeStatus Todo = "[ ] К выполнению"
describeStatus InProgress = "[~] В работе"
describeStatus Done = "[x] Готово"

-- | Срочная задача: высокий приоритет И не завершена.
isUrgent :: Task -> Bool
isUrgent task = taskPriority task == High && taskStatus task /= Done

-- | Перевести статус в следующий: Todo → InProgress → Done → Done.
nextStatus :: Status -> Status
nextStatus Todo = InProgress
nextStatus InProgress = Done
nextStatus Done = Done

-- | Описать список задач: "N задач(и), из них M срочных"
describeTasks :: TaskList -> String
describeTasks tasks =
  show (length tasks) ++ " задач(и), из них " ++ show urgentCount ++ " срочных"
 where
  urgentCount = length (filter isUrgent tasks)
