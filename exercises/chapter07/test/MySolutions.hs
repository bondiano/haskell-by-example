module MySolutions where

import Data.AddressBook
import Data.Char (isDigit)

-- Упражнение 1: валидатор телефонного номера
--
-- Номер должен быть:
--   - непустым
--   - состоять только из цифр
--   - содержать не менее 7 символов

validatePhoneNumber :: String -> Validation Errors String
validatePhoneNumber = undefined

-- Упражнение 2: комбинирование валидаторов
--
-- Используйте <$> и <*> для комбинирования nonEmpty и validateAddress.

validatePerson :: String -> String -> String -> String -> String -> Validation Errors Person
validatePerson = undefined

-- Упражнение 3: traverse с индексом

traverseWithIndex :: Applicative f => (Int -> a -> f b) -> [a] -> f [b]
traverseWithIndex = undefined

-- Упражнение 4: валидация через Either (fail-fast)
--
-- Реализуйте те же проверки, что и в упражнениях 2,
-- но используя Either String вместо Validation Errors.

eitherValidateAddress :: String -> String -> String -> Either String Address
eitherValidateAddress = undefined

validatePersonEither :: String -> String -> String -> String -> String -> Either String Person
validatePersonEither = undefined
