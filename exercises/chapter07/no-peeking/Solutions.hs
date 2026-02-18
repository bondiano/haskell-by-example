module Solutions where

import Data.AddressBook
import Data.Char (isDigit)

-- Упражнение 1: валидатор телефонного номера

validatePhoneNumber :: String -> Validation Errors String
validatePhoneNumber phone =
  check (not $ null phone) "Телефон не может быть пустым"
  *> check (all isDigit phone) "Телефон должен содержать только цифры"
  *> check (length phone >= 7) "Телефон должен содержать не менее 7 символов"
  *> pure phone
  where
    check True  _ = Success ()
    check False e = Failure [e]

-- Упражнение 2: комбинирование валидаторов

validatePerson :: String -> String -> String -> String -> String -> Validation Errors Person
validatePerson first last_ street city st =
  Person <$> nonEmpty "Имя" first
         <*> nonEmpty "Фамилия" last_
         <*> validateAddress street city st

-- Упражнение 3: traverse с индексом

traverseWithIndex :: Applicative f => (Int -> a -> f b) -> [a] -> f [b]
traverseWithIndex f = go 0
  where
    go _ []     = pure []
    go i (x:xs) = (:) <$> f i x <*> go (i + 1) xs

-- Упражнение 4: валидация через Either (fail-fast)

eitherValidateAddress :: String -> String -> String -> Either String Address
eitherValidateAddress s c st =
  Address <$> eitherNonEmpty "Улица" s
          <*> eitherNonEmpty "Город" c
          <*> eitherNonEmpty "Регион" st

validatePersonEither :: String -> String -> String -> String -> String -> Either String Person
validatePersonEither first last_ street city st =
  Person <$> eitherNonEmpty "Имя" first
         <*> eitherNonEmpty "Фамилия" last_
         <*> eitherValidateAddress street city st
