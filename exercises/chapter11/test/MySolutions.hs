module MySolutions where

import Data.Text (Text)
import Data.Text qualified as T

import TaskTracker

-- ============================================================
-- Упражнение 3 (определяем первым, т.к. остальные зависят от него):
-- Тип Validation
--
-- Определите тип данных Validation e a с двумя конструкторами:
--   Failure e  — ошибка
--   Success a  — успешный результат
--
-- Реализуйте инстансы:
--   - Functor  (fmap применяет функцию к Success, Failure не меняется)
--   - Applicative (pure = Success; Failure комбинирует ошибки через <>)
--
-- Ключевое отличие от Either: при двух Failure ошибки
-- объединяются через Semigroup (<>), а не берётся первая.
-- ============================================================

data Validation e a = Failure e | Success a
  deriving (Show, Eq)

instance Functor (Validation e) where
  fmap = undefined

instance (Semigroup e) => Applicative (Validation e) where
  pure = undefined
  (<*>) = undefined

-- ============================================================
-- Упражнение 1: Валидация заголовка
--
-- Заголовок задачи не должен быть пустым и не длиннее 100 символов.
-- При ошибке верните Failure со списком сообщений об ошибках.
--
-- Подсказка: используйте T.null и T.length из Data.Text.
-- ============================================================

{- | Валидация заголовка задачи.

>>> validateTitle ""
Failure ["Заголовок не может быть пустым"]

>>> validateTitle "Купить молоко"
Success "Купить молоко"

>>> validateTitle (T.replicate 101 "x")
Failure ["Заголовок не может быть длиннее 100 символов"]
-}
validateTitle :: Text -> Validation [Text] Text
validateTitle = undefined

-- ============================================================
-- Упражнение 2: Валидация приоритета
--
-- Преобразуйте строку в приоритет (регистронезависимо).
-- "low" → Low, "medium" → Medium, "high" → High.
-- Иначе: Failure ["Неизвестный приоритет: ..."]
--
-- Подсказка: используйте T.toLower из Data.Text.
-- ============================================================

{- | Парсинг приоритета из текста.

>>> validatePriority "high"
Success High

>>> validatePriority "LOW"
Success Low

>>> validatePriority "urgent"
Failure ["Неизвестный приоритет: urgent"]
-}
validatePriority :: Text -> Validation [Text] Priority
validatePriority = undefined

-- ============================================================
-- Упражнение 3 (продолжение): validateTaskInput
--
-- Соберите Task из трёх текстовых полей, используя
-- Applicative-стиль:
--   Task <$> validateTitle title
--        <*> pure description
--        <*> validatePriority priority
--        <*> pure Todo
--
-- Если есть несколько ошибок, они все собираются в один список.
-- ============================================================

{- | Валидация и создание задачи.

>>> validateTaskInput "Купить молоко" "Из магазина" "high"
Success (Task {taskTitle = "Купить молоко", ...})

>>> validateTaskInput "" "Описание" "urgent"
Failure ["Заголовок не может быть пустым","Неизвестный приоритет: urgent"]
-}
validateTaskInput :: Text -> Text -> Text -> Validation [Text] Task
validateTaskInput = undefined

-- ============================================================
-- Упражнение 4: Labelled Functor
--
-- Определите тип Labelled a = Labelled String a
-- и реализуйте инстанс Functor.
-- fmap применяет функцию к значению, метка остаётся прежней.
-- ============================================================

data Labelled a = Labelled String a
  deriving (Show, Eq)

instance Functor Labelled where
  fmap = undefined

-- ============================================================
-- Упражнение 5: RoseTree Functor
--
-- Определите тип дерева:
--   data RoseTree a = RoseNode a [RoseTree a]
-- Реализуйте инстанс Functor (рекурсивный fmap).
-- ============================================================

data RoseTree a = RoseNode a [RoseTree a]
  deriving (Show, Eq)

instance Functor RoseTree where
  fmap = undefined

-- ============================================================
-- Упражнение 6: Labelled Applicative
--
-- Реализуйте инстанс Applicative для Labelled.
--   pure x = Labelled "" x
--   Labelled l1 f <*> Labelled l2 x = Labelled (l1 <> l2) (f x)
-- ============================================================

instance Applicative Labelled where
  pure = undefined
  (<*>) = undefined
