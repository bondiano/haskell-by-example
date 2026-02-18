module AddressBook
  ( Entry(..)
  , AddressBook
  , showEntry
  , findByName
  , insertEntry
  , exampleBook
  ) where

-- | Запись в адресной книге.
data Entry = Entry
  { entryName  :: String
  , entryPhone :: String
  , entryEmail :: String
  } deriving stock (Show, Eq, Read)

-- | Адресная книга — список записей.
type AddressBook = [Entry]

-- | Отформатировать запись для вывода.
showEntry :: Entry -> String
showEntry Entry{..} =
  entryName <> " | " <> entryPhone <> " | " <> entryEmail

-- | Найти записи по точному совпадению имени.
findByName :: String -> AddressBook -> [Entry]
findByName name = filter (\e -> entryName e == name)

-- | Добавить запись в начало книги.
insertEntry :: Entry -> AddressBook -> AddressBook
insertEntry = (:)

-- | Пример адресной книги для тестирования.
exampleBook :: AddressBook
exampleBook =
  [ Entry "Иван Петров"    "+7-900-123-4567" "ivan@example.com"
  , Entry "Мария Сидорова" "+7-900-765-4321" "maria@example.com"
  , Entry "Алексей Козлов" "+7-900-111-2233" "alex@example.com"
  ]
