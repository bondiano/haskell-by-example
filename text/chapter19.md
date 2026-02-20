# GADTs и семейства типов

В [предыдущей главе](chapter18.md) мы построили язык запросов для трекера — парсер превращает текст в AST, а исполнитель фильтрует задачи. Но наш AST допускает бессмысленные комбинации: ничто не мешает написать `NotFilter (NotFilter (NotFilter ...))` или передать `ListValue` туда, где ожидается одно значение. Типы не защищают нас от семантических ошибок.

В этой главе мы выйдем за пределы обычных ADT и изучим инструменты для выражения более точных инвариантов на уровне типов. Мы увидим ограничения обычных ADT, познакомимся с **фантомными типами**, изучим **GADTs** (обобщённые алгебраические типы с индивидуальными сигнатурами конструкторов), разберём **DataKinds** (продвижение типов на уровень родов) и **семейства типов** (функции на уровне типов). Всё это применим в проекте — типобезопасном конструкторе запросов для трекера, где невалидные состояния отклоняются компилятором.

## Подготовка проекта

Код этой главы находится в `exercises/chapter19`. Соберите проект:

```text
$ cd exercises/chapter19
$ stack build
```

Расширения языка, используемые в этой главе:

```haskell
{-# LANGUAGE GADTs #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE StandaloneDeriving #-}
```

## Ограничения обычных ADT

### Проблема: конструктор не может ограничить тип результата

Вспомним тип выражения из [главы 3](chapter03.md):

```haskell
data Expr
  = LitInt Int
  | LitBool Bool
  | Add Expr Expr
  | If Expr Expr Expr
  deriving (Show)
```

Этот тип допускает бессмысленные выражения:

```haskell
-- Складываем булево значение с числом — типы не помешают!
badExpr :: Expr
badExpr = Add (LitBool True) (LitInt 42)

-- If с числом в условии
badIf :: Expr
badIf = If (LitInt 0) (LitBool True) (LitBool False)
```

Компилятор не жалуется — `Expr` одинаково представляет и числа, и булевы значения. Ошибка обнаружится только в рантайме при интерпретации.

```haskell
eval :: Expr -> Either String Int
eval (LitInt n)    = Right n
eval (LitBool _)   = Left "ожидалось число, получен Bool"  -- рантайм ошибка!
eval (Add e1 e2)   = (+) <$> eval e1 <*> eval e2
eval (If cond t f) = Left "нужна отдельная функция для Bool"
```

Мы хотели бы сказать компилятору: «`Add` принимает только выражения, возвращающие числа, а `If` — выражение с булевым условием». Обычные ADT этого не позволяют.

```admonish tip title="Знакомый аналог"
**TypeScript:** `type Expr = { kind: 'int', value: number } | { kind: 'bool', value: boolean } | { kind: 'add', left: Expr, right: Expr }` — та же проблема. TypeScript не может выразить «`add` принимает только `int`-выражения» без conditional types.
**Rust:** обычные enum имеют ту же проблему. Для типобезопасных выражений нужны generics с PhantomData.
```

## Фантомные типы

### Идея: добавить параметр типа, не используемый в данных

**Фантомный тип** — параметр типа, который не появляется ни в одном конструкторе, но используется для ограничений на уровне типов:

```haskell
-- 'a' — фантомный параметр: не используется в данных
data Expr a
  = LitInt Int
  | LitBool Bool
  | Add (Expr a) (Expr a)
  | If (Expr a) (Expr a) (Expr a)
```

Теперь `Expr Int` и `Expr Bool` — разные типы. Но проблема осталась: ничто не мешает пользователю написать `LitBool True :: Expr Int`. Фантомный тип — просто метка, компилятор не проверяет соответствие.

### Умные конструкторы

Можно *спрятать* настоящие конструкторы и экспортировать только «умные» функции:

```haskell
module Expr (Expr, litInt, litBool, add, ifThenElse) where

litInt :: Int -> Expr Int
litInt = LitInt

litBool :: Bool -> Expr Bool
litBool = LitBool

add :: Expr Int -> Expr Int -> Expr Int
add = Add

ifThenElse :: Expr Bool -> Expr a -> Expr a -> Expr a
ifThenElse = If
```

Теперь `add (litBool True) (litInt 42)` не скомпилируется — типы не совпадают! Но это хрупкое решение: внутри модуля по-прежнему можно нарушить инварианты. И `eval` не может использовать паттерн-матчинг по типу `a`.

## GADTs: обобщённые алгебраические типы данных

### Синтаксис

**GADTs** решают эту проблему, позволяя каждому конструктору явно указать тип результата:

```haskell
{-# LANGUAGE GADTs #-}

data Expr a where
  LitInt  :: Int -> Expr Int
  LitBool :: Bool -> Expr Bool
  Add     :: Expr Int -> Expr Int -> Expr Int
  If      :: Expr Bool -> Expr a -> Expr a -> Expr a
```

Ключевое отличие от обычного ADT: каждый конструктор имеет *свою* сигнатуру с указанием конкретного возвращаемого типа:

- `LitInt` возвращает `Expr Int` (не `Expr a`).
- `LitBool` возвращает `Expr Bool`.
- `Add` принимает *только* `Expr Int` и возвращает `Expr Int`.
- `If` принимает `Expr Bool` как условие.

### Типобезопасность на этапе компиляции

Теперь бессмысленные выражения просто *не компилируются*:

```haskell
-- Ошибка компиляции!
-- badExpr = Add (LitBool True) (LitInt 42)
--   • Couldn't match type 'Bool' with 'Int'
--     Expected: Expr Int
--       Actual: Expr Bool

-- OK:
goodExpr :: Expr Int
goodExpr = Add (LitInt 1) (LitInt 2)

-- OK: If с правильными типами
goodIf :: Expr Int
goodIf = If (LitBool True) (LitInt 1) (LitInt 2)
```

### Типобезопасный eval

С GADTs `eval` становится тотальной функцией — без `Either` и без рантайм-ошибок:

```haskell
eval :: Expr a -> a
eval (LitInt n)     = n           -- GHC знает: a ~ Int
eval (LitBool b)    = b           -- GHC знает: a ~ Bool
eval (Add e1 e2)    = eval e1 + eval e2  -- оба Int
eval (If cond t f)  = if eval cond then eval t else eval f
```

Это работает благодаря **уточнению типов** (type refinement): при паттерн-матчинге по `LitInt n` компилятор знает, что `a ~ Int`, и позволяет вернуть `n :: Int` как `a`.

```text
> eval (Add (LitInt 1) (LitInt 2))
3

> eval (If (LitBool True) (LitInt 10) (LitInt 20))
10
```

```admonish note title="Ключевое свойство GADTs"
При паттерн-матчинге по конструктору GADT компилятор *уточняет* переменные типа. Это позволяет писать функции, которые возвращают разные типы в зависимости от конструктора — без приведения типов и без рантайм-проверок.
```

### Deriving для GADTs

Обычный `deriving` не работает с GADTs. Нужен `StandaloneDeriving`:

```haskell
{-# LANGUAGE StandaloneDeriving #-}

deriving instance Show a => Show (Expr a)
deriving instance Eq a => Eq (Expr a)
```

При паттерн-матчинге по конструктору GADT компилятор уточняет переменную типа `a`, поэтому обычный `deriving` не работает — он не знает, как уточнение влияет на `a`. `StandaloneDeriving` позволяет написать ограничение явно: «выводи `Show (Expr a)`, если `Show a`».

## DataKinds: продвижение типов

### Проблема: фантомные типы слишком свободны

С GADTs мы ограничили `Expr a`, но `a` может быть *любым* типом: `Expr String`, `Expr [Maybe (IO ())]` — компилятор не жалуется, хотя такие типы бессмысленны. Мы хотим сказать: «`a` может быть только `Int` или `Bool`».

### DataKinds: типы становятся родами

Расширение `DataKinds` **продвигает** (promotes) типы данных на уровень родов (kinds):

```haskell
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}

-- Обычный тип данных
data ExprType = IntType | BoolType

-- С DataKinds 'IntType и 'BoolType становятся типами рода ExprType
-- (апостроф ' означает продвинутый конструктор)

data Expr (t :: ExprType) where
  LitInt  :: Int -> Expr 'IntType
  LitBool :: Bool -> Expr 'BoolType
  Add     :: Expr 'IntType -> Expr 'IntType -> Expr 'IntType
  If      :: Expr 'BoolType -> Expr t -> Expr t -> Expr t
```

Теперь `Expr 'IntType` и `Expr 'BoolType` — единственные допустимые типы. `Expr String` просто не скомпилируется:

```text
• Expected kind 'ExprType', but 'String' has kind '*'
```

```admonish note title="Уровни в Haskell"
Без DataKinds в Haskell три уровня:
- **Значения**: `42`, `True`, `Just "hello"` — живут в рантайме.
- **Типы**: `Int`, `Bool`, `Maybe String` — род (kind) `*` (или `Type`).
- **Роды**: `*`, `* -> *` — классифицируют типы.

DataKinds добавляет четвёртый уровень: обычные типы данных *продвигаются* на уровень родов, а их конструкторы становятся типами.
```

### Пример: безопасные состояния

DataKinds часто используются для кодирования состояний на уровне типов:

```haskell
data TaskState = Draft | Active | Completed

data Task (s :: TaskState) where
  MkDraft    :: Text -> Task 'Draft
  MkActive   :: Text -> Task 'Active
  MkComplete :: Text -> Task 'Completed

-- Можно завершить только активную задачу:
completeTask :: Task 'Active -> Task 'Completed
completeTask (MkActive title) = MkComplete title

-- Ошибка компиляции: нельзя завершить черновик!
-- bad = completeTask (MkDraft "test")
--   Couldn't match type ''Draft' with ''Active'
```

```admonish tip title="Знакомый аналог"
**TypeScript:** branded types с условными типами:
```typescript
type Draft = { __state: 'draft'; title: string }
type Active = { __state: 'active'; title: string }
function complete(task: Active): Completed { ... }
```

В Haskell с DataKinds это встроено в систему типов — без хаков и «брендирования».

## Семейства типов (Type Families)

### Функции на уровне типов

**Семейства типов** — функции, которые работают на уровне типов. Так же, как обычная функция превращает одно значение в другое, семейство типов превращает один тип в другой.

```haskell
{-# LANGUAGE TypeFamilies #-}

-- Закрытое семейство типов (closed type family)
type family HaskellType (t :: ExprType) where
  HaskellType 'IntType  = Int
  HaskellType 'BoolType = Bool
```

`HaskellType` — функция на уровне типов: `HaskellType 'IntType` *вычисляется* в `Int`, `HaskellType 'BoolType` — в `Bool`.

Теперь `eval` можно написать так:

```haskell
eval :: Expr t -> HaskellType t
eval (LitInt n)     = n      -- HaskellType 'IntType ~ Int
eval (LitBool b)    = b      -- HaskellType 'BoolType ~ Bool
eval (Add e1 e2)    = eval e1 + eval e2
eval (If cond t f)  = if eval cond then eval t else eval f
```

### Открытые семейства типов

Закрытые семейства (с `where`) определяют все случаи в одном месте — как `case` в обычном коде. Открытые семейства позволяют добавлять случаи в разных модулях:

```haskell
-- Открытое семейство: случаи добавляются инстансами
type family Pretty a :: Symbol  -- Symbol — тип-уровневая строка

type instance Pretty Int  = "целое число"
type instance Pretty Bool = "логическое значение"
```

```admonish warning title="Когда использовать какое семейство"
- **Закрытые** семейства типов — когда все случаи известны заранее. Аналог: `case` или закрытый `data`. Используйте по умолчанию.
- **Открытые** семейства типов — когда пользователи вашей библиотеки должны добавлять случаи. Аналог: класс типов. Используйте осторожно — возможны конфликты при импорте.
```

### Ассоциированные семейства типов

Семейства типов часто связаны с классами типов:

```haskell
class Container f where
  type Elem f           -- ассоциированный тип
  empty  :: f
  insert :: Elem f -> f -> f
  toList :: f -> [Elem f]

instance Container [a] where
  type Elem [a] = a
  empty  = []
  insert = (:)
  toList = id

instance Container (Set a) where
  type Elem (Set a) = a
  empty  = Set.empty
  insert = Set.insert
  toList = Set.toList
```

`Elem` — **ассоциированное семейство типов** (associated type family). Каждый инстанс `Container` определяет, какой тип элементов он содержит.

```admonish tip title="Знакомый аналог"
**TypeScript:** `interface Container<T> { elem: T; ... }` — generic параметр.
**Rust:** `trait Container { type Elem; ... }` — ассоциированный тип, *точная* аналогия.
Семейства типов в Haskell более мощные: они могут вычислять типы через паттерн-матчинг, чего нет в Rust (пока) и TypeScript.
```

## Проект: типобезопасный конструктор запросов

Вернёмся к нашему трекеру. В [главе 18](chapter18.md) мы строили запросы из текста. Теперь создадим **типобезопасный конструктор запросов** — EDSL, который не позволяет составить невалидный запрос.

### Состояния запроса

Определим состояния конструктора запросов:

```haskell
data QueryState = Building | Ready

data QueryBuilder (s :: QueryState) where
  EmptyQuery  :: QueryBuilder 'Building
  AddFilter   :: FilterExpr -> QueryBuilder 'Building -> QueryBuilder 'Building
  AddSort     :: SortField -> QueryBuilder 'Building -> QueryBuilder 'Building
  FinalQuery  :: QueryBuilder 'Building -> QueryBuilder 'Ready
```

### Конструктор с гарантиями

```haskell
-- Начать построение запроса
newQuery :: QueryBuilder 'Building
newQuery = EmptyQuery

-- Добавить фильтр (только к строящемуся запросу)
whereStatus :: Status -> QueryBuilder 'Building -> QueryBuilder 'Building
whereStatus s = AddFilter (StatusFilter (TextValue (T.pack (show s))))

wherePriority :: Priority -> QueryBuilder 'Building -> QueryBuilder 'Building
wherePriority p = AddFilter (PriorityFilter (TextValue (T.pack (show p))))

whereTag :: Text -> QueryBuilder 'Building -> QueryBuilder 'Building
whereTag t = AddFilter (TagFilter (TextValue t))

-- Завершить построение (только строящийся → готовый)
build :: QueryBuilder 'Building -> QueryBuilder 'Ready
build = FinalQuery

-- Выполнить (только готовый запрос!)
execute :: QueryBuilder 'Ready -> [Task] -> [Task]
execute (FinalQuery qb) tasks = applyFilters (collectFilters qb) tasks
```

### Использование

```haskell
-- OK: правильная последовательность
result :: [Task] -> [Task]
result = execute query
  where
    query = build
          . whereStatus Done
          . wherePriority High
          $ newQuery

-- Ошибка компиляции: нельзя выполнить незавершённый запрос!
-- bad = execute (whereStatus Done newQuery)
--   Couldn't match type ''Building' with ''Ready'

-- Ошибка компиляции: нельзя добавить фильтр к завершённому запросу!
-- bad = whereStatus Todo (build newQuery)
--   Couldn't match type ''Ready' with ''Building'
```

### Извлечение фильтров

```haskell
collectFilters :: QueryBuilder 'Building -> [FilterExpr]
collectFilters EmptyQuery         = []
collectFilters (AddFilter f rest) = f : collectFilters rest
collectFilters (AddSort _ rest)   = collectFilters rest

applyFilters :: [FilterExpr] -> [Task] -> [Task]
applyFilters filters tasks = foldl' (\ts f -> filter (matchFilter f) ts) tasks filters
```

```admonish note title="Протокол на уровне типов"
Мы закодировали *протокол* использования API в типах. Пользователь *физически не может* вызвать `execute` до `build`, а `build` — дважды. Это не рантайм-проверки и не документация — это *гарантия компилятора*.
```

### Типобезопасная валидация

Добавим семейство типов для валидации полей:

```haskell
type family ValidField (field :: Symbol) :: Bool where
  ValidField "status"   = 'True
  ValidField "priority" = 'True
  ValidField "tag"      = 'True
  ValidField "title"    = 'True
  ValidField _          = 'False
```

Это семейство вычисляет на уровне типов, допустимо ли имя поля. С помощью дополнительных расширений (`TypeOperators`, `ConstraintKinds`) можно сделать так, чтобы невалидные поля не компилировались.

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

### Проект

1. Определите GADT `Expr a` с конструкторами `LitInt`, `LitBool`, `Add` и `If`. Реализуйте тотальную функцию `eval`:

    ```haskell
    data Expr a where
      LitInt  :: Int -> Expr Int
      LitBool :: Bool -> Expr Bool
      Add     :: Expr Int -> Expr Int -> Expr Int
      If      :: Expr Bool -> Expr a -> Expr a -> Expr a

    eval :: Expr a -> a
    ```

2. Добавьте конструкторы `Equal :: Expr Int -> Expr Int -> Expr Bool` и `Not :: Expr Bool -> Expr Bool` к `Expr`. Обновите `eval`.

3. Реализуйте `QueryBuilder` с состояниями `Building` и `Ready` и функции `newQuery`, `whereStatus`, `build`, `execute`.

### Практика

4. Определите тип `SafeList` с помощью DataKinds, который различает пустые и непустые списки:

    ```haskell
    data Emptiness = Empty | NonEmpty

    data SafeList (e :: Emptiness) a where
      Nil  :: SafeList 'Empty a
      Cons :: a -> SafeList e a -> SafeList 'NonEmpty a

    safeHead :: SafeList 'NonEmpty a -> a
    ```

    `safeHead Nil` не должен компилироваться.

5. Определите закрытое семейство типов `Add` для сложения натуральных чисел на уровне типов:

    ```haskell
    data Nat = Z | S Nat

    type family Add (n :: Nat) (m :: Nat) :: Nat where
      Add 'Z m     = m
      Add ('S n) m = 'S (Add n m)
    ```

    Проверьте: `Proxy :: Proxy (Add ('S 'Z) ('S ('S 'Z)))` должен иметь тип `Proxy ('S ('S ('S 'Z)))`.

6. Определите ассоциированное семейство типов `Key` для класса `HasKey`:

    ```haskell
    class HasKey a where
      type Key a
      getKey :: a -> Key a
    ```

    Напишите инстансы для `Task` (ключ `TaskId`) и для пар `(k, v)` (ключ `k`).

### 🚀 Продвинутые упражнения (★★★)

Эти упражнения опциональные, но дадут вам реальный опыт работы с advanced Haskell features:

**Challenge 1:** Добавьте к `Expr` условный оператор с проверкой типов:

```haskell
IfThenElse :: Expr Bool -> Expr a -> Expr a -> Expr a
```

Условие должно быть `Bool`, оба branch'а — одного типа. Компилятор проверит это!

**Challenge 2:** Добавьте сравнение с ограничением `Eq`:

```haskell
Equal :: Eq a => Expr a -> Expr a -> Expr Bool
```

Это сложно — нужно добавить constraint в GADT! Изучите, как GHC хранит словари ограничений.

**Challenge 3:** Добавьте let-биндинги с Environment (очень сложно):

```haskell
Let :: String -> Expr a -> Expr b -> Expr b
Var :: String -> Expr a
```

Нужен Environment для хранения значений. Измените `eval :: Env -> Expr a -> a`.

```admonish tip title="Это серьёзный вызов"
Challenge 3 — именно так работают реальные DSL (Haskell для Haskell, embedded SQL, etc.). Если вы решите его, вы поймёте, как устроены системы типов настоящих языков!
```

## Заключение

GADTs и семейства типов — это «программирование на уровне типов». Вместо проверки инвариантов в рантайме мы *доказываем* их на этапе компиляции. Цена — более сложные типы. Выгода — невозможность целых классов ошибок. В этой главе мы прошли от ограничений обычных ADT через фантомные типы к GADTs (конструкторы с индивидуальными сигнатурами и уточнение типов при паттерн-матчинге), DataKinds (ограничение фантомных параметров через продвижение типов) и семействам типов (закрытым, открытым и ассоциированным). На практике мы применили всё это в типобезопасном конструкторе запросов, где невалидные последовательности операций отклоняются компилятором.

В [следующей главе](chapter20.md) мы перейдём к линзам и оптикам — элегантному решению проблемы вложенных обновлений записей.

```admonish tip title="Для углубления"
- **Thinking with Types** — Сэнди Магир (Sandy Maguire): лучшая книга о type-level программировании в Haskell. Главы о GADTs, DataKinds и Type Families — must read.
- **Haskell Wiki** — [GADTs for dummies](https://wiki.haskell.org/GADTs_for_dummies): вводная статья с примерами.
- **GHC User Guide** — разделы о [GADTs](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/gadt.html) и [Type Families](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/type_families.html).
- **Richard Eisenberg** — доклады о зависимых типах в Haskell: куда движется система типов GHC.
```
