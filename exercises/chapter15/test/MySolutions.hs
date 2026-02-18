module MySolutions where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Text.Megaparsec
import Text.Megaparsec.Char
import Text.Megaparsec.Char.Lexer qualified as L
import Language.Expr (Expr(..))
import Language.Expr.Parser (Parser, sc, lexeme, symbol, keyword)
import Language.Json (JValue(..))

-- ============================================================
-- Упражнение 1: Вычислитель выражений (без переменных)
--
-- Реализуйте функцию eval, которая вычисляет арифметические выражения.
-- Обрабатывайте только: Lit, Add, Sub, Mul, Div, Neg.
-- Для Var и Let возвращайте Left с сообщением об ошибке.
-- При делении на ноль возвращайте Left "division by zero".
-- ============================================================

-- | Вычисление выражения без поддержки переменных.
--
-- >>> eval (Add (Lit 1) (Lit 2))
-- Right 3.0
--
-- >>> eval (Div (Lit 10) (Lit 0))
-- Left "division by zero"
eval :: Expr -> Either String Double
eval = undefined

-- ============================================================
-- Упражнение 2: Оптимизатор AST
--
-- Реализуйте функцию optimize, которая упрощает выражения
-- по алгебраическим правилам. Применяйте правила рекурсивно
-- (сначала оптимизируйте поддеревья, потом корень).
--
-- Правила:
--   0 + x  →  x          x + 0  →  x
--   0 * x  →  Lit 0      x * 0  →  Lit 0
--   1 * x  →  x          x * 1  →  x
--   x - 0  →  x
--   Neg (Neg x)  →  x
-- ============================================================

-- | Оптимизация выражения по алгебраическим тождествам.
--
-- >>> optimize (Add (Lit 0) (Var "x"))
-- Var "x"
--
-- >>> optimize (Mul (Lit 1) (Add (Lit 0) (Var "y")))
-- Var "y"
optimize :: Expr -> Expr
optimize = undefined

-- ============================================================
-- Упражнение 3: Парсер JSON
--
-- Реализуйте парсер JSON-подмножества на megaparsec.
-- Поддерживаемые значения: null, true, false, числа, строки,
-- массивы и объекты.
--
-- Используйте утилиты из Language.Expr.Parser:
--   sc, lexeme, symbol, keyword
--
-- Полезные комбинаторы megaparsec:
--   between, sepBy, manyTill
--   char, string, digitChar, letterChar
--   L.decimal, L.float, L.charLiteral
-- ============================================================

-- | Парсер JSON-значения.
parseJsonValue :: Parser JValue
parseJsonValue = undefined

-- | Разбирает строку как JSON.
--
-- >>> parseJson "{\"a\": [1, true, null]}"
-- Right (JObject [("a",JArray [JNumber 1.0,JBool True,JNull])])
parseJson :: String -> Either String JValue
parseJson input = case parse (sc *> parseJsonValue <* eof) "" input of
  Left err  -> Left (errorBundlePretty err)
  Right val -> Right val

-- ============================================================
-- Упражнение 4 (продвинутое): Вычислитель с переменными
--
-- Расширьте вычислитель для поддержки Var и Let.
--
-- Var x     — найти x в окружении. Если нет, Left "undefined variable: x".
-- Let x e b — вычислить e, добавить x=результат в окружение, вычислить b.
--
-- Используйте Map String Double как окружение (environment).
-- ============================================================

-- | Вычисление выражения с поддержкой переменных.
--
-- >>> evalWithVars Map.empty (Let "x" (Lit 5) (Add (Var "x") (Lit 3)))
-- Right 8.0
--
-- >>> evalWithVars Map.empty (Var "x")
-- Left "undefined variable: x"
evalWithVars :: Map String Double -> Expr -> Either String Double
evalWithVars = undefined
