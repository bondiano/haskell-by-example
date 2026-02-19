module Solutions where

import Data.Text (Text)
import Data.Text qualified as T

import TaskTracker

-- ============================================================
-- Упражнение 3: Тип Validation и инстансы
-- ============================================================

data Validation e a = Failure e | Success a
  deriving (Show, Eq)

instance Functor (Validation e) where
  fmap _ (Failure e) = Failure e
  fmap f (Success a) = Success (f a)

instance (Semigroup e) => Applicative (Validation e) where
  pure = Success
  Failure e1 <*> Failure e2 = Failure (e1 <> e2)
  Failure e <*> _ = Failure e
  _ <*> Failure e = Failure e
  Success f <*> Success a = Success (f a)

-- ============================================================
-- Упражнение 1: Валидация заголовка
-- ============================================================

-- | Заголовок не может быть пустым и не длиннее 100 символов.
validateTitle :: Text -> Validation [Text] Text
validateTitle title
  | T.null title = Failure ["Заголовок не может быть пустым"]
  | T.length title > 100 = Failure ["Заголовок не может быть длиннее 100 символов"]
  | otherwise = Success title

-- ============================================================
-- Упражнение 2: Валидация приоритета
-- ============================================================

-- | Регистронезависимый парсинг приоритета.
validatePriority :: Text -> Validation [Text] Priority
validatePriority t =
  case T.toLower t of
    "low" -> Success Low
    "medium" -> Success Medium
    "high" -> Success High
    _ -> Failure ["Неизвестный приоритет: " <> t]

-- ============================================================
-- Упражнение 3 (продолжение): validateTaskInput
-- ============================================================

{- | Сборка Task из трёх текстовых полей через Applicative.
Ошибки из заголовка и приоритета объединяются.
-}
validateTaskInput :: Text -> Text -> Text -> Validation [Text] Task
validateTaskInput title description priority =
  Task
    <$> validateTitle title
    <*> pure description
    <*> validatePriority priority
    <*> pure Todo

-- ============================================================
-- Упражнение 4: Labelled Functor
-- ============================================================

data Labelled a = Labelled String a
  deriving (Show, Eq)

instance Functor Labelled where
  fmap f (Labelled label a) = Labelled label (f a)

-- ============================================================
-- Упражнение 5: RoseTree Functor
-- ============================================================

data RoseTree a = RoseNode a [RoseTree a]
  deriving (Show, Eq)

instance Functor RoseTree where
  fmap f (RoseNode a children) = RoseNode (f a) (map (fmap f) children)

-- ============================================================
-- Упражнение 6: Labelled Applicative
-- ============================================================

instance Applicative Labelled where
  pure = Labelled ""
  Labelled l1 f <*> Labelled l2 x = Labelled (l1 <> l2) (f x)
