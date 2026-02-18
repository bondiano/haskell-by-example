module Data.AddressBook
  ( -- * Валидация
    Validation(..)
  , Errors
  , isSuccess
  , isFailure
  , errorCount
    -- * Типы адресной книги
  , Address(..)
  , Person(..)
    -- * Валидаторы
  , nonEmpty
  , eitherNonEmpty
  , validateAddress
  ) where

-- | Результат валидации с накоплением ошибок.
--
-- В отличие от 'Either', при комбинировании через '<*>'
-- ошибки не теряются, а объединяются через 'Semigroup'.
data Validation e a
  = Failure e    -- ^ Ошибки
  | Success a    -- ^ Успешный результат
  deriving stock (Show, Eq)

instance Functor (Validation e) where
  fmap _ (Failure e) = Failure e
  fmap f (Success a) = Success (f a)

instance Semigroup e => Applicative (Validation e) where
  pure = Success
  Failure e1 <*> Failure e2 = Failure (e1 <> e2)  -- накапливает!
  Failure e  <*> _          = Failure e
  _          <*> Failure e  = Failure e
  Success f  <*> Success a  = Success (f a)

-- | Список строк с описаниями ошибок.
type Errors = [String]

-- | Проверить, является ли результат успешным.
isSuccess :: Validation e a -> Bool
isSuccess (Success _) = True
isSuccess _           = False

-- | Проверить, является ли результат ошибочным.
isFailure :: Validation e a -> Bool
isFailure (Failure _) = True
isFailure _           = False

-- | Количество ошибок в результате валидации.
errorCount :: Validation [a] b -> Int
errorCount (Failure es) = length es
errorCount _            = 0

-- | Адрес.
data Address = Address
  { street :: String
  , city   :: String
  , state  :: String
  } deriving stock (Show, Eq)

-- | Человек.
data Person = Person
  { firstName :: String
  , lastName  :: String
  , address   :: Address
  } deriving stock (Show, Eq)

-- | Проверяет, что строка не пуста.
--
-- >>> nonEmpty "Имя" "Иван"
-- Success "Иван"
--
-- >>> nonEmpty "Имя" ""
-- Failure ["Имя не может быть пустым"]
nonEmpty :: String -> String -> Validation Errors String
nonEmpty field "" = Failure [field <> " не может быть пустым"]
nonEmpty _ value  = Success value

-- | Проверяет, что строка не пуста (версия для 'Either').
-- Останавливается на первой ошибке при комбинировании через '<*>'.
eitherNonEmpty :: String -> String -> Either String String
eitherNonEmpty field "" = Left (field <> " не может быть пустым")
eitherNonEmpty _ value  = Right value

-- | Валидация адреса. Все поля должны быть непустыми.
--
-- >>> validateAddress "Ленина 1" "Москва" "МО"
-- Success (Address {street = "Ленина 1", city = "Москва", state = "МО"})
--
-- >>> validateAddress "" "" ""
-- Failure ["Улица не может быть пустым","Город не может быть пустым","Регион не может быть пустым"]
validateAddress :: String -> String -> String -> Validation Errors Address
validateAddress s c st =
  Address <$> nonEmpty "Улица" s
          <*> nonEmpty "Город" c
          <*> nonEmpty "Регион" st
