module Solutions where

import AddressBook
import Data.IORef
import Data.Char (toLower)
import Data.List (isInfixOf)

-- Упражнение 1: удаление записи по имени

deleteEntry :: String -> AddressBook -> AddressBook
deleteEntry name = filter (\e -> entryName e /= name)

-- Упражнение 2: сохранение и загрузка

saveAddressBook :: FilePath -> AddressBook -> IO ()
saveAddressBook path book = writeFile path (show book)

loadAddressBook :: FilePath -> IO AddressBook
loadAddressBook path = read <$> readFile path

-- Упражнение 3: нечёткий поиск

fuzzySearch :: String -> AddressBook -> [Entry]
fuzzySearch query = filter (isMatch . entryName)
  where
    q = map toLower query
    isMatch name = q `isInfixOf` map toLower name

-- Упражнение 4: undo через IORef

recordState :: IORef [AddressBook] -> AddressBook -> IO ()
recordState ref book = modifyIORef ref (book :)

undoLastChange :: IORef [AddressBook] -> IO (Maybe AddressBook)
undoLastChange ref = do
  history <- readIORef ref
  case history of
    (_:prev:rest) -> do
      writeIORef ref (prev : rest)
      return (Just prev)
    _ -> return Nothing
