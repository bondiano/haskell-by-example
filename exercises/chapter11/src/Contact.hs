module Contact
  ( Contact(..)
  , exampleContacts
  ) where

import Data.Aeson (ToJSON, FromJSON)
import GHC.Generics (Generic)

-- | Контакт с именем, телефоном и email.
data Contact = Contact
  { name  :: String
  , phone :: String
  , email :: String
  } deriving stock (Show, Eq, Generic)

instance ToJSON Contact
instance FromJSON Contact

-- | Пример списка контактов для тестирования.
exampleContacts :: [Contact]
exampleContacts =
  [ Contact "Иван Петров"    "+7-900-123-4567" "ivan@example.com"
  , Contact "Мария Сидорова" "+7-900-765-4321" "maria@example.com"
  , Contact "Алексей Козлов" "+7-900-111-2233" "alex@example.com"
  ]
