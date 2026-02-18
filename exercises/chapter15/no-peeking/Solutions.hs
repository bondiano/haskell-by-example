module Solutions where

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
-- ============================================================

-- | Вычисление выражения без поддержки переменных.
--
-- Для бинарных операций используется аппликативный стиль:
-- @(+) <$> eval a <*> eval b@ — вычисляет оба аргумента
-- и применяет операцию. Ошибки автоматически «всплывают»
-- благодаря монаде Either.
eval :: Expr -> Either String Double
eval (Lit n)     = Right n
eval (Add a b)   = (+) <$> eval a <*> eval b
eval (Sub a b)   = (-) <$> eval a <*> eval b
eval (Mul a b)   = (*) <$> eval a <*> eval b
eval (Div a b)   = do
  x <- eval a
  y <- eval b
  if y == 0 then Left "division by zero" else Right (x / y)
eval (Neg a)     = negate <$> eval a
eval (Var _)     = Left "variables not supported"
eval (Let _ _ _) = Left "let bindings not supported"

-- ============================================================
-- Упражнение 2: Оптимизатор AST
-- ============================================================

-- | Оптимизация выражения по алгебраическим тождествам.
--
-- Стратегия: сначала рекурсивно оптимизируем поддеревья,
-- затем применяем правила упрощения к корню.
-- Это гарантирует, что правила применяются «снизу вверх».
optimize :: Expr -> Expr
optimize (Lit n)   = Lit n
optimize (Var x)   = Var x
optimize (Add a b) = case (optimize a, optimize b) of
  (Lit 0, x) -> x
  (x, Lit 0) -> x
  (a', b')   -> Add a' b'
optimize (Sub a b) = case (optimize a, optimize b) of
  (x, Lit 0) -> x
  (a', b')   -> Sub a' b'
optimize (Mul a b) = case (optimize a, optimize b) of
  (Lit 0, _) -> Lit 0
  (_, Lit 0) -> Lit 0
  (Lit 1, x) -> x
  (x, Lit 1) -> x
  (a', b')   -> Mul a' b'
optimize (Div a b) = Div (optimize a) (optimize b)
optimize (Neg a)   = case optimize a of
  Neg x -> x
  a'    -> Neg a'
optimize (Let x e b) = Let x (optimize e) (optimize b)

-- ============================================================
-- Упражнение 3: Парсер JSON
-- ============================================================

-- | Парсер JSON-значения.
--
-- Структура — цепочка альтернатив (<|>).
-- Для ключевых слов (null, true, false) используем keyword,
-- чтобы не совпадать с началом идентификатора.
parseJsonValue :: Parser JValue
parseJsonValue =
      JNull       <$  keyword "null"
  <|> JBool True  <$  keyword "true"
  <|> JBool False <$  keyword "false"
  <|> JNumber     <$> lexeme (try L.float <|> L.decimal)
  <|> JString     <$> pStringLit
  <|> JArray      <$> between (symbol "[") (symbol "]")
                       (parseJsonValue `sepBy` symbol ",")
  <|> JObject     <$> between (symbol "{") (symbol "}")
                       (pPair `sepBy` symbol ",")
  where
    pStringLit = lexeme $ char '"' *> manyTill L.charLiteral (char '"')
    pPair      = (,) <$> pStringLit <*> (symbol ":" *> parseJsonValue)

-- | Разбирает строку как JSON.
parseJson :: String -> Either String JValue
parseJson input = case parse (sc *> parseJsonValue <* eof) "" input of
  Left err  -> Left (errorBundlePretty err)
  Right val -> Right val

-- ============================================================
-- Упражнение 4: Вычислитель с переменными
-- ============================================================

-- | Вычисление выражения с поддержкой переменных.
--
-- Окружение (Map String Double) хранит привязки переменных.
-- При Let x e b: вычисляем e, расширяем окружение и вычисляем b.
evalWithVars :: Map String Double -> Expr -> Either String Double
evalWithVars env = go
  where
    go (Lit n)     = Right n
    go (Var x)     = case Map.lookup x env of
                       Just v  -> Right v
                       Nothing -> Left ("undefined variable: " ++ x)
    go (Add a b)   = (+) <$> go a <*> go b
    go (Sub a b)   = (-) <$> go a <*> go b
    go (Mul a b)   = (*) <$> go a <*> go b
    go (Div a b)   = do
      x <- go a
      y <- go b
      if y == 0 then Left "division by zero" else Right (x / y)
    go (Neg a)     = negate <$> go a
    go (Let x e b) = do
      v <- go e
      evalWithVars (Map.insert x v env) b
