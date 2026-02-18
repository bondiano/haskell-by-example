module Language.Expr.Parser
  ( -- * Тип парсера
    Parser
    -- * Парсинг выражений
  , parseExpr
  , pExpr
    -- * Лексические утилиты (для повторного использования в упражнениях)
  , sc
  , lexeme
  , symbol
  , keyword
  , identifier
  , number
  , parens
  ) where

import Data.Void (Void)
import Control.Monad (guard)
import Text.Megaparsec
import Text.Megaparsec.Char
import Text.Megaparsec.Char.Lexer qualified as L
import Control.Monad.Combinators.Expr

import Language.Expr (Expr(..))

-- | Тип парсера: без пользовательских ошибок, вход — @String@.
type Parser = Parsec Void String

------------------------------------------------------------
-- Лексер
------------------------------------------------------------

-- | Пропуск пробельных символов (без комментариев).
sc :: Parser ()
sc = L.space space1 empty empty

-- | Обёртка: парсит значение и съедает пробелы после него.
lexeme :: Parser a -> Parser a
lexeme = L.lexeme sc

-- | Парсит точную строку-символ и съедает пробелы.
symbol :: String -> Parser String
symbol = L.symbol sc

-- | Парсит ключевое слово (не может быть частью идентификатора).
--
-- @keyword "let"@ совпадёт с @"let "@ и @"let("@, но не с @"letter"@.
keyword :: String -> Parser ()
keyword w = lexeme (string w *> notFollowedBy alphaNumChar)

-- | Парсит идентификатор: начинается с буквы, далее буквы и цифры.
-- Ключевые слова @let@ и @in@ не являются допустимыми идентификаторами.
identifier :: Parser String
identifier = lexeme $ try $ do
  name <- (:) <$> letterChar <*> many alphaNumChar
  guard (name `notElem` reservedWords)
  pure name
  where
    reservedWords = ["let", "in"]

-- | Парсит числовой литерал (целое или дробное).
number :: Parser Double
number = lexeme $ try L.float <|> L.decimal

-- | Парсит содержимое в круглых скобках.
parens :: Parser a -> Parser a
parens = between (symbol "(") (symbol ")")

------------------------------------------------------------
-- Парсер выражений
------------------------------------------------------------

-- | Парсер выражения верхнего уровня.
pExpr :: Parser Expr
pExpr = try pLet <|> pArith

-- | Парсер let-привязки: @let x = e1 in e2@.
pLet :: Parser Expr
pLet = Let
  <$> (keyword "let" *> identifier)
  <*> (symbol "=" *> pExpr)
  <*> (keyword "in" *> pExpr)

-- | Парсер арифметического выражения с учётом приоритета операторов.
--
-- Приоритет (от высшего к низшему):
--
-- 1. Унарный минус: @-x@
-- 2. Умножение, деление: @*@, @\/@
-- 3. Сложение, вычитание: @+@, @-@
pArith :: Parser Expr
pArith = makeExprParser pTerm operatorTable

-- | Парсер атомарного выражения: скобки, число или переменная.
pTerm :: Parser Expr
pTerm = parens pExpr
    <|> Lit <$> number
    <|> Var <$> identifier

-- | Таблица операторов для makeExprParser.
operatorTable :: [[Operator Parser Expr]]
operatorTable =
  [ [ Prefix (Neg <$ symbol "-") ]
  , [ InfixL (Mul <$ symbol "*"), InfixL (Div <$ symbol "/") ]
  , [ InfixL (Add <$ symbol "+"), InfixL (Sub <$ symbol "-") ]
  ]

-- | Разбирает строку в выражение.
--
-- >>> parseExpr "2 + 3 * 4"
-- Right (Add (Lit 2.0) (Mul (Lit 3.0) (Lit 4.0)))
--
-- >>> parseExpr "let x = 5 in x + 1"
-- Right (Let "x" (Lit 5.0) (Add (Var "x") (Lit 1.0)))
parseExpr :: String -> Either String Expr
parseExpr input = case parse (sc *> pExpr <* eof) "" input of
  Left err  -> Left (errorBundlePretty err)
  Right ast -> Right ast
