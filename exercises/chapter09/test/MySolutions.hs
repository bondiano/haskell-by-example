module MySolutions where

import AddressBook
import Data.IORef
import Data.Char (toLower)
import Data.List (isInfixOf)

-- Упражнение 1: удаление записи по имени
--
-- Удалить все записи с данным именем.

deleteEntry :: String -> AddressBook -> AddressBook
deleteEntry = undefined

-- Упражнение 2: сохранение и загрузка адресной книги
--
-- Используйте show/read для сериализации и writeFile/readFile для IO.

saveAddressBook :: FilePath -> AddressBook -> IO ()
saveAddressBook = undefined

loadAddressBook :: FilePath -> IO AddressBook
loadAddressBook = undefined

-- Упражнение 3: нечёткий поиск по имени
--
-- Регистронезависимый поиск по подстроке в имени.

fuzzySearch :: String -> AddressBook -> [Entry]
fuzzySearch = undefined

-- Упражнение 4: undo через IORef
--
-- IORef хранит стек состояний [AddressBook] (голова — текущее).
-- recordState — добавить состояние на вершину стека.
-- undoLastChange — убрать текущее и вернуть предыдущее.

recordState :: IORef [AddressBook] -> AddressBook -> IO ()
recordState = undefined

undoLastChange :: IORef [AddressBook] -> IO (Maybe AddressBook)
undoLastChange = undefined
