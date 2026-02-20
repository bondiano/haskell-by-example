module MySolutions where

import TaskTracker

{- | Упражнение 1: Вычисление типобезопасных выражений (базовое).
  Реализуйте eval для LitInt, LitBool, Add, If.
  GADT гарантирует, что Add принимает только Expr Int,
  а If требует Expr Bool в качестве условия.
-}
eval :: Expr a -> a
eval = undefined

{- | Упражнение 2: Расширенный eval — добавьте обработку Equal и Not.
  Equal сравнивает два Expr Int и возвращает Expr Bool.
  Not инвертирует Expr Bool.
  (Объедините с eval — здесь отдельная функция для тестирования.)
-}
evalFull :: Expr a -> a
evalFull = undefined

{- | Упражнение 3: QueryBuilder — создание, добавление фильтров, сборка.
  newQuery — начальный пустой билдер.
  addFilter — добавление строки-фильтра.
  build — финализация (переход Building → Ready).
  execute — применение к списку задач (упрощённо: фильтр по подстроке в заголовке).
-}
newQuery :: QueryBuilder Building
newQuery = undefined

addFilter :: String -> QueryBuilder Building -> QueryBuilder Building
addFilter = undefined

buildQuery :: QueryBuilder Building -> QueryBuilder Ready
buildQuery = undefined

execute :: QueryBuilder Ready -> [Task] -> [Task]
execute = undefined

{- | Упражнение 4: SafeList — безопасный head без Maybe.
  safeHead принимает только непустой SafeList.
  Благодаря GADT компилятор не позволит вызвать safeHead на Nil.
-}
safeHead :: SafeList 'NonEmpty a -> a
safeHead = undefined

{- | Упражнение 5: Проверка семейства типов AddNat на уровне значений (compile-time).
  Эта функция нужна только для проверки того, что AddNat компилируется.
  Реализуйте функцию сложения натуральных чисел на уровне значений
  (обычная рекурсия, не связана с type family, но аналогична).
-}
addNat :: Nat -> Nat -> Nat
addNat = undefined

-- | Упражнение 6: Реализация HasKey для Task и кортежа.
instance HasKey Task where
  type Key Task = String
  getKey = undefined

instance HasKey (k, v) where
  type Key (k, v) = k
  getKey = undefined

{- ────────────────────────────────────────────────────────────────
   🚀 Challenging Exercises (★★★) — Продвинутые

   Эти упражнения требуют глубокого понимания GADT и type families.
   Они не обязательны для прохождения главы, но дадут вам реальный
   опыт работы с advanced Haskell features.
   ──────────────────────────────────────────────────────────────── -}

{- | Challenge 1: Условные выражения с GADT (★★★)
  Расширьте Expr новым конструктором:

  IfThenElse :: Expr Bool -> Expr a -> Expr a -> Expr a

  Условное выражение с проверкой типов на compile-time!
  Условие должно быть Bool, оба branch'а — одного типа.

  Затем обновите eval, чтобы обрабатывать IfThenElse.

  Пример:
  eval (IfThenElse (LitBool True) (LitInt 42) (LitInt 0)) == 42
-}
-- Добавьте конструктор в Expr и реализуйте eval для него

{- | Challenge 2: Equality с ограничением Eq (★★★)
  Расширьте Expr новым конструктором:

  Equal :: Eq a => Expr a -> Expr a -> Expr Bool

  Это СЛОЖНО: нужно добавить constraint Eq в GADT!
  Equal сравнивает два выражения одного типа и возвращает Bool.

  Обновите eval для обработки Equal.

  Пример:
  eval (Equal (LitInt 5) (Add (LitInt 2) (LitInt 3))) == True
-}
-- Добавьте конструктор Equal с constraint в Expr

{- | Challenge 3: Let-биндинги с Environment (★★★)
  Расширьте DSL локальными переменными:

  Let :: String -> Expr a -> Expr b -> Expr b
  Var :: String -> Expr a  -- переменная

  Это ОЧЕНЬ СЛОЖНО: нужен Environment для хранения значений!

  Подсказка: определите Environment как GADT или Data.Dynamic,
  измените сигнатуру eval:

  eval :: Env -> Expr a -> a

  где Env хранит пары (String, значение).

  Пример:
  eval emptyEnv (Let "x" (LitInt 10) (Add (Var "x") (Var "x"))) == 20
-}
-- Это серьёзный вызов — именно так работают реальные DSL!
