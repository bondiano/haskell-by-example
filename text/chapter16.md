# GADTs и семейства типов

## Цели главы

В этой главе мы выйдем за рамки обычных алгебраических типов данных. Мы познакомимся с GADTs (Generalized Algebraic Data Types) — расширением, позволяющим кодировать инварианты прямо в типах. Компилятор будет проверять корректность на этапе компиляции, делая целые классы ошибок невозможными.

Мы также разберём DataKinds и семейства типов (Type Families) — механизм вычислений на уровне типов.

## Ограничения обычных АТД

В главе 15 мы строили DSL с типом выражений:

```haskell
data Expr
  = Lit Int
  | BoolLit Bool
  | Add Expr Expr
  | If Expr Expr Expr
```

Проблема: `Add (BoolLit True) (Lit 1)` — складываем булево значение с числом. Тип `Expr` это допускает, и ошибка обнаружится только в рантайме:

```haskell
eval :: Expr -> ???  -- Какой тип возвращать? Int? Bool?
```

Функция `eval` вынуждена возвращать что-то вроде `Either String Value`, обрабатывая ошибки типов вручную. Но ведь компилятор *мог бы* проверить это за нас — если бы тип выражения нёс информацию о типе результата.

## Фантомные типы

Первый шаг — **фантомные типы**: параметр типа, который не используется в конструкторах:

```haskell
newtype Tagged (tag :: Symbol) a = Tagged a

type Meters  = Tagged "meters"  Double
type Seconds = Tagged "seconds" Double
```

Теперь `Meters` и `Seconds` — разные типы, хотя оба содержат `Double`:

```text
> Tagged 5.0 :: Meters
Tagged 5.0

> (Tagged 5.0 :: Meters) + (Tagged 3.0 :: Seconds)
<ошибка типов!>
```

Ограничение фантомных типов: при *конструировании* мы выбираем тег свободно, компилятор не проверяет соответствие значения и тега. Для этого нужны GADTs.

## GADTs

### Синтаксис

Расширение `GADTs` позволяет каждому конструктору явно задать *возвращаемый тип*:

```haskell
{-# LANGUAGE GADTs #-}

data Expr a where
  ILit :: Int -> Expr Int
  BLit :: Bool -> Expr Bool
  Add  :: Expr Int -> Expr Int -> Expr Int
  Eql  :: Eq a => Expr a -> Expr a -> Expr Bool
  If   :: Expr Bool -> Expr a -> Expr a -> Expr a
  Not  :: Expr Bool -> Expr Bool
  And  :: Expr Bool -> Expr Bool -> Expr Bool
  Gt   :: Ord a => Expr a -> Expr a -> Expr Bool
```

Ключевое отличие от обычных АТД: каждый конструктор может возвращать `Expr` с *разным* параметром. `ILit` возвращает `Expr Int`, `BLit` — `Expr Bool`, `Add` принимает только `Expr Int`.

Теперь `Add (BLit True) (ILit 1)` — **ошибка компиляции**: `Add` ожидает `Expr Int`, а `BLit True` имеет тип `Expr Bool`.

### Уточнение типа при сопоставлении (type refinement)

Самое мощное свойство GADTs — при сопоставлении с образцом компилятор *уточняет* переменную типа:

```haskell
eval :: Expr a -> a
eval (ILit n)   = n           -- здесь GHC знает: a ~ Int
eval (BLit b)   = b           -- здесь GHC знает: a ~ Bool
eval (Add x y)  = eval x + eval y   -- a ~ Int, (+) :: Int -> Int -> Int
eval (Eql x y)  = eval x == eval y  -- a ~ Bool, Eq a — из конструктора
eval (If c t e) = if eval c then eval t else eval e
eval (Not x)    = not (eval x)
eval (And x y)  = eval x && eval y
eval (Gt x y)   = eval x > eval y   -- Ord a — из конструктора
```

Обратите внимание: `eval` — **тотальная** функция. Все случаи покрыты, и в каждой ветке компилятор гарантирует правильный тип. Никаких `Either`, никаких рантайм-ошибок.

### Экзистенциальные типы

GADTs позволяют «упаковать» значение, скрыв его конкретный тип:

```haskell
data SomeExpr = forall a. Show a => SomeExpr (Expr a)
```

`SomeExpr` — контейнер для `Expr a` с *неизвестным* `a`. Единственное, что мы знаем — `a` имеет `Show`:

```haskell
showSomeExpr :: SomeExpr -> String
showSomeExpr (SomeExpr e) = show (eval e)

exprs :: [SomeExpr]
exprs = [SomeExpr (ILit 42), SomeExpr (BLit True), SomeExpr (Add (ILit 1) (ILit 2))]
```

```text
> map showSomeExpr exprs
["42","True","3"]
```

Гетерогенный список! Каждый элемент содержит `Expr` с разным `a`, но все можно показать через `show`.

## DataKinds

Расширение `DataKinds` **промотирует** обычные типы данных в кайнды, а их конструкторы — в типы:

```haskell
{-# LANGUAGE DataKinds #-}

data Nat = Zero | Succ Nat
```

Без `DataKinds`:
- `Nat` — тип с кайндом `Type`
- `Zero`, `Succ` — конструкторы данных (значения)

С `DataKinds`:
- `Nat` — *кайнд*
- `'Zero` — тип с кайндом `Nat`
- `'Succ` — конструктор типов с кайндом `Nat -> Nat`

Апостроф `'` отличает промотированный конструктор от одноимённого конструктора данных.

Теперь `Nat` можно использовать как параметр типа:

```haskell
data Vec (n :: Nat) a where
  VNil  :: Vec 'Zero a
  VCons :: a -> Vec n a -> Vec ('Succ n) a
```

`Vec` — вектор, длина которого закодирована в типе. `VNil` создаёт вектор длины `'Zero`, `VCons` увеличивает длину на один.

## Семейства типов (Type Families)

Семейства типов — это *функции на уровне типов*: они принимают типы и возвращают типы.

### Закрытые семейства типов

Закрытое семейство определяется одним блоком — все уравнения в одном месте:

```haskell
type family Add (a :: Nat) (b :: Nat) :: Nat where
  Add 'Zero     b = b
  Add ('Succ a) b = 'Succ (Add a b)
```

Это сложение натуральных чисел, но на уровне *типов*. GHC вычисляет `Add ('Succ 'Zero) ('Succ 'Zero)` и получает `'Succ ('Succ 'Zero)` — во время компиляции.

### Открытые семейства типов

Открытое семейство можно расширять новыми уравнениями в любом модуле:

```haskell
type family Element (c :: Type) :: Type
type instance Element [a]       = a
type instance Element (Set a)   = a
type instance Element (Map k v) = (k, v)
```

Новые экземпляры добавляются через `type instance` в произвольных модулях.

### Ассоциированные семейства типов

Семейство типов можно привязать к классу типов:

```haskell
class Container c where
  type Elem c :: Type        -- ассоциированное семейство
  empty  :: c
  insert :: Elem c -> c -> c
  toList :: c -> [Elem c]
```

`Elem c` определяется в каждом экземпляре:

```haskell
instance Container [a] where
  type Elem [a] = a
  empty  = []
  insert x xs = xs ++ [x]
  toList = id

instance Ord a => Container (Set a) where
  type Elem (Set a) = a
  empty  = Set.empty
  insert = Set.insert
  toList = Set.toList

instance Ord k => Container (Map k v) where
  type Elem (Map k v) = (k, v)
  empty  = Map.empty
  insert (k, v) = Map.insert k v
  toList = Map.toList
```

Теперь можно писать обобщённые функции:

```haskell
containerFromList :: Container c => [Elem c] -> c
containerFromList = foldl' (flip insert) empty
```

```text
> containerFromList [3, 1, 2] :: Set Int
fromList [1,2,3]

> containerFromList [("a", 1), ("b", 2)] :: Map String Int
fromList [("a",1),("b",2)]
```

Одна функция — разные контейнеры, типобезопасно.

## Длина в типе: `Vec n a`

Соберём всё вместе: `DataKinds`, `GADTs` и семейства типов.

```haskell
data Vec (n :: Nat) (a :: Type) where
  VNil  :: Vec 'Zero a
  VCons :: a -> Vec n a -> Vec ('Succ n) a
```

### Тотальная `vhead`

Обычный `head :: [a] -> a` — частичная функция (падает на пустом списке). С `Vec` мы можем написать тотальную версию:

```haskell
vhead :: Vec ('Succ n) a -> a
vhead (VCons x _) = x
```

Тип гарантирует, что вектор непустой: `'Succ n` не может быть `'Zero`. Паттерн-матчинг исчерпывающий — `VNil` невозможен.

### Операции с гарантированными длинами

```haskell
vtail :: Vec ('Succ n) a -> Vec n a
vtail (VCons _ xs) = xs

vzip :: Vec n a -> Vec n b -> Vec n (a, b)
vzip VNil VNil = VNil
vzip (VCons a as) (VCons b bs) = VCons (a, b) (vzip as bs)
```

`vzip` принимает два вектора *одинаковой* длины `n`. Попытка вызвать `vzip` с векторами разной длины — ошибка компиляции.

### Конкатенация с семейством типов

```haskell
vappend :: Vec n a -> Vec m a -> Vec (Add n m) a
vappend VNil ys = ys
vappend (VCons x xs) ys = VCons x (vappend xs ys)
```

Тип возвращаемого значения — `Vec (Add n m) a`. GHC использует семейство `Add` для вычисления длины результата на уровне типов.

## Когда (не) использовать GADTs

### Преимущества

- **Инварианты в типах** — компилятор проверяет корректность.
- **Тотальные функции** — `vhead` не может упасть.
- **Отсутствие рантайм-ошибок** — `eval` не возвращает `Either`.

### Недостатки

- **Сложность типов** — код становится труднее читать.
- **Потеря вывода типов** — сигнатуры типов часто обязательны.
- **Несовместимость с `deriving`** — нужен `StandaloneDeriving`.
- **Инфраструктурный налог** — `DataKinds`, `TypeFamilies`, `UndecidableInstances`.

### Правило

Если инвариант можно обеспечить обычными АТД + smart constructors — используйте их. GADTs — для случаев, когда типовая безопасность критична и окупает усложнение (DSL-интерпретаторы, протоколы, индексированные структуры).

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

Модуль `Data.Expr.Typed` предоставляет GADT `Expr a`. Модуль `Data.Vec` — типы `Nat`, `Vec n a` и семейство `Add`. Модуль `Data.Container` — класс `Container` с ассоциированным семейством `Elem`.

1. **(Лёгкое)** Реализуйте вычислитель выражений:

    ```haskell
    eval :: Expr a -> a
    ```

    Компилятор гарантирует корректность типов — `eval` тотальна. При матчинге на `ILit` компилятор знает, что `a ~ Int`; на `BLit` — что `a ~ Bool`.

2. **(Среднее)** Реализуйте красивую печать выражений:

    ```haskell
    prettyExpr :: Expr a -> String
    ```

    ```text
    > prettyExpr (Add (ILit 1) (ILit 2))
    "(1 + 2)"

    > prettyExpr (If (Gt (ILit 3) (ILit 2)) (ILit 1) (ILit 0))
    "(if (3 > 2) then 1 else 0)"
    ```

3. **(Среднее)** Напишите экземпляры `Container` для `[a]`, `Set a` и `Map k v`. Затем реализуйте обобщённую функцию:

    ```haskell
    containerFromList :: Container c => [Elem c] -> c
    ```

    ```text
    > containerFromList [3, 1, 2] :: Set Int
    fromList [1,2,3]
    ```

    *Подсказка:* используйте `foldl'`, `flip insert` и `empty`.

4. **(Продвинутое)** Реализуйте операции на `Vec n a`:

    ```haskell
    vhead   :: Vec ('Succ n) a -> a
    vtail   :: Vec ('Succ n) a -> Vec n a
    vzip    :: Vec n a -> Vec n b -> Vec n (a, b)
    vappend :: Vec n a -> Vec m a -> Vec (Add n m) a
    ```

    `vhead` и `vtail` тотальны — пустой вектор невозможен. `vzip` работает только с векторами одинаковой длины. `vappend` использует семейство типов `Add` для вычисления длины результата.

## Заключение

В этой главе мы:

- Увидели ограничения обычных АТД и мотивацию для GADTs.
- Освоили фантомные типы и перешли к GADTs с уточнением типов при сопоставлении.
- Написали типобезопасный вычислитель выражений без рантайм-ошибок.
- Познакомились с `DataKinds` — промоцией данных в типы.
- Разобрали семейства типов: закрытые, открытые и ассоциированные.
- Реализовали `Vec n a` — вектор с длиной в типе, где тотальность `vhead` гарантирована компилятором.
