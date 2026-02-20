module TaskTracker where

import Data.Kind (Type)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)

-- | Идентификатор задачи.
newtype TaskId = TaskId Int
  deriving (Show, Eq, Ord)

-- | Приоритет задачи.
data Priority = Low | Medium | High
  deriving (Show, Eq, Ord)

-- | Статус задачи.
data Status = Todo | InProgress | Done
  deriving (Show, Eq, Ord)

-- | Задача трекера.
data Task = Task
  { taskTitle :: Text
  , taskDescription :: Text
  , taskPriority :: Priority
  , taskStatus :: Status
  }
  deriving (Show, Eq)

-- | Примеры задач для тестирования.
exampleTasks :: [Task]
exampleTasks =
  [ Task "Купить молоко" "" Low Todo
  , Task "Написать отчёт" "" High InProgress
  , Task "Полить цветы" "" Medium Done
  , Task "Подготовить презентацию" "" High Todo
  ]

-- =====================================================
-- Упражнение 1: GADT Expr — типобезопасные выражения
-- =====================================================

{- | Типобезопасное выражение.
  GADT позволяет задать разные типы возвращаемого значения
  для каждого конструктора.
-}
data Expr a where
  LitInt :: Int -> Expr Int
  LitBool :: Bool -> Expr Bool
  Add :: Expr Int -> Expr Int -> Expr Int
  If :: Expr Bool -> Expr a -> Expr a -> Expr a
  -- Упражнение 2: расширение
  Equal :: Expr Int -> Expr Int -> Expr Bool
  Not :: Expr Bool -> Expr Bool

deriving instance (Show a) => Show (Expr a)
deriving instance (Eq a) => Eq (Expr a)

-- =====================================================
-- Упражнение 3: QueryBuilder с фантомными типами
-- =====================================================

-- | Состояния билдера запросов.
data Building

data Ready

{- | Типобезопасный конструктор запросов.
  Фантомный параметр s гарантирует, что execute можно вызвать
  только после build.
-}
data QueryBuilder (s :: Type) where
  NewQuery :: QueryBuilder Building
  WithFilter :: String -> QueryBuilder Building -> QueryBuilder Building
  Built :: QueryBuilder Building -> QueryBuilder Ready

deriving instance Show (QueryBuilder s)

-- =====================================================
-- Упражнение 4: SafeList с DataKinds
-- =====================================================

-- | Маркер пустоты списка на уровне типов.
data Emptiness = Empty | NonEmpty

-- | Список, который знает на уровне типов — пуст он или нет.
data SafeList (e :: Emptiness) a where
  Nil :: SafeList 'Empty a
  Cons :: a -> SafeList e a -> SafeList 'NonEmpty a

deriving instance (Show a) => Show (SafeList e a)

-- =====================================================
-- Упражнение 5: Nat и семейство типов Add
-- =====================================================

-- | Натуральные числа Пеано (на уровне типов).
data Nat = Z | S Nat
  deriving (Show, Eq)

-- | Семейство типов для сложения натуральных чисел.
type family AddNat (n :: Nat) (m :: Nat) :: Nat where
  AddNat 'Z m = m
  AddNat ('S n) m = 'S (AddNat n m)

-- =====================================================
-- Упражнение 6: Ассоциированное семейство типов HasKey
-- =====================================================

{- | Класс типов с ассоциированным семейством типов.
  Определяет «ключ» для данного типа.
-}
class HasKey a where
  type Key a
  getKey :: a -> Key a
