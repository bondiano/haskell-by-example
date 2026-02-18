module Data.Person
  ( Person(..)
  , encodePerson
  , decodePerson
  ) where

-- | Простая запись для демонстрации round-trip тестирования.
data Person = Person
  { personName :: String
  , personAge  :: Int
  } deriving (Show, Eq)

-- | Кодирование Person в строку в формате @"имя;возраст"@.
--
-- Ограничение: имя не должно содержать символ @';'@,
-- иначе round-trip @decodePerson . encodePerson@ не гарантирован.
--
-- >>> encodePerson (Person "Alice" 30)
-- "Alice;30"
encodePerson :: Person -> String
encodePerson (Person name age) = name ++ ";" ++ show age

-- | Декодирование Person из строки формата @"имя;возраст"@.
--
-- >>> decodePerson "Alice;30"
-- Just (Person {personName = "Alice", personAge = 30})
-- >>> decodePerson "invalid"
-- Nothing
decodePerson :: String -> Maybe Person
decodePerson s = case break (== ';') s of
  (name, ';':rest) -> case reads rest of
    [(age, "")] -> Just (Person name age)
    _           -> Nothing
  _ -> Nothing
