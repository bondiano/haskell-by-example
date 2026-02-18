module Language.Json
  ( JValue(..)
  , prettyJson
  ) where

-- | Тип, представляющий JSON-значение.
data JValue
  = JNull                       -- ^ @null@
  | JBool Bool                  -- ^ @true@ / @false@
  | JNumber Double              -- ^ @42@, @3.14@
  | JString String              -- ^ @"hello"@
  | JArray [JValue]             -- ^ @[1, 2, 3]@
  | JObject [(String, JValue)]  -- ^ @{"a": 1, "b": 2}@
  deriving (Show, Eq)

-- | Минимальный pretty-printer JSON (без отступов, однострочный).
--
-- >>> prettyJson (JObject [("name", JString "Alice"), ("age", JNumber 30)])
-- "{\"name\": \"Alice\", \"age\": 30}"
prettyJson :: JValue -> String
prettyJson JNull       = "null"
prettyJson (JBool b)   = if b then "true" else "false"
prettyJson (JNumber n)
  | n == fromIntegral (round n :: Integer) = show (round n :: Integer)
  | otherwise = show n
prettyJson (JString s) = "\"" ++ escapeString s ++ "\""
prettyJson (JArray xs) = "[" ++ commaSep (map prettyJson xs) ++ "]"
prettyJson (JObject ps) = "{" ++ commaSep (map pair ps) ++ "}"
  where
    pair (k, v) = "\"" ++ escapeString k ++ "\": " ++ prettyJson v

commaSep :: [String] -> String
commaSep []     = ""
commaSep [x]    = x
commaSep (x:xs) = x ++ ", " ++ commaSep xs

escapeString :: String -> String
escapeString = concatMap escapeChar
  where
    escapeChar '"'  = "\\\""
    escapeChar '\\' = "\\\\"
    escapeChar '\n' = "\\n"
    escapeChar '\t' = "\\t"
    escapeChar c    = [c]
