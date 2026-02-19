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
