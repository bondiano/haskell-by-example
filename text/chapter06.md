# Классы типов

## Цели главы

В этой главе мы познакомимся с классами типов (type classes) — механизмом полиморфизма в Haskell. Мы разберём стандартные классы `Eq`, `Ord`, `Show`, `Read`, `Enum` и `Bounded`, научимся создавать собственные классы и их экземпляры, а также освоим автоматическую деривацию и расширение `DerivingStrategies`.

Проект главы — библиотека хэширования с классом `Hashable`.

## Параметрический и ad-hoc полиморфизм

Прежде чем разбирать классы типов, важно понять *зачем* они нужны. В Haskell существуют два вида полиморфизма:

### Параметрический полиморфизм

Функция работает *одинаково* для любого типа. Реализация ничего не знает о конкретном типе и не может заглядывать внутрь:

```haskell
identity :: a -> a
identity x = x  -- единственная возможная реализация!
```

Из типа `a -> a` следует, что функция *может только вернуть свой аргумент*. Она не может создать значение типа `a` из ничего (не знает, как), не может его изменить (не знает, что внутри). Это называется **свободная теорема** (free theorem, Wadler 1989).

Другой пример: для любой функции `f :: [a] -> [a]` автоматически выполняется:

```text
map g . f == f . map g
```

Это свойство следует *только из типа*, без анализа реализации. Параметрический полиморфизм даёт мощные гарантии бесплатно.

### Ad-hoc полиморфизм

Функция работает *по-разному* для разных типов. Каждый тип предоставляет свою реализацию:

```haskell
-- Для Int: побитовое сравнение
-- Для String: посимвольное сравнение
-- Для [a]: поэлементное сравнение
(==) :: Eq a => a -> a -> Bool
```

**Type classes** — механизм, которым Haskell реализует ad-hoc полиморфизм. В отличие от OOP-диспетчеризации, type classes позволяют **диспетчеризацию по возвращаемому типу**:

```haskell
read :: Read a => String -> a
-- read "42" :: Int      → 42
-- read "42" :: Double   → 42.0
-- Какой read вызвать — определяется типом *результата*!
```

Это невозможно в Java или TypeScript — там выбор метода определяется типом *объекта* (receiver).

```admonish info title="Знакомый аналог"
**TypeScript:** `function identity<T>(x: T): T` — параметрический полиморфизм.
`interface Eq { equals(other: this): boolean }` — ad-hoc. Но TS не может вывести
свободные теоремы (из-за `any`, side effects), и не может диспетчеризовать по return type.

**Python:** `typing.TypeVar` для параметрического, `Protocol` (PEP 544) для ad-hoc.
Без enforcement в runtime.
```

### Зачем два вида?

| | Параметрический | Ad-hoc (type classes) |
|---|---|---|
| Реализация | Одна на все типы | Своя для каждого типа |
| Гарантии | Свободные теоремы | Законы класса (по соглашению) |
| Пример | `length :: [a] -> Int` | `show :: Show a => a -> String` |
| Расширяемость | Нет — и не нужна | Новый тип → новый экземпляр |

Параметрический полиморфизм — *более сильная* абстракция: меньше знаний о типе → больше гарантий. Type classes добавляются, когда нужна *специализация* поведения. В главе 19 мы увидим `Contravariant` — «зеркальный» `Functor`, расширяющий эту картину.

## Что такое классы типов

Класс типов (type class) — это набор операций, определённых для некоторого типа. Если тип реализует эти операции (предоставляет экземпляр класса), его можно использовать везде, где ожидается этот класс.

Вспомним оператор `==`:

```text
> 5 == 5
True

> "hello" == "world"
False
```

Оператор `==` работает и с числами, и со строками, и со списками. Но попробуйте сравнить функции:

```text
> (\x -> x) == (\x -> x)

<error: No instance for (Eq (Integer -> Integer))>
```

Ошибка говорит: для типа `Integer -> Integer` нет экземпляра класса `Eq`. Не все типы можно сравнивать — только те, для которых определено, *как* сравнивать.

### Определение класса

Класс объявляется ключевым словом `class`:

```haskell
class Eq a where
  (==) :: a -> a -> Bool
  (/=) :: a -> a -> Bool
  x /= y = not (x == y)  -- реализация по умолчанию
```

Здесь:

- `Eq` — имя класса.
- `a` — переменная типа (параметр).
- `(==)` и `(/=)` — методы класса.
- `(/=)` имеет реализацию по умолчанию через `(==)`.

### Экземпляры

Чтобы тип мог использовать операции класса, нужно объявить экземпляр (instance):

```haskell
data Color = Red | Green | Blue

instance Eq Color where
  Red   == Red   = True
  Green == Green = True
  Blue  == Blue  = True
  _     == _     = False
```

Теперь `Color` можно сравнивать:

```text
> Red == Red
True

> Red == Blue
False

> Red /= Green
True
```

### Ограничения (constraints)

Когда функция использует операции класса, это отражается в её типе:

```haskell
elem :: Eq a => a -> [a] -> Bool
```

`Eq a =>` — ограничение: функция работает только с типами, для которых есть экземпляр `Eq`. Это контракт: «дайте мне тип, который умеет проверять равенство, и я скажу, есть ли элемент в списке».

Можно комбинировать несколько ограничений:

```haskell
showMax :: (Ord a, Show a) => a -> a -> String
showMax x y = show (max x y)
```

### Вывод типов (Type Inference)

Вы могли заметить, что Haskell часто не требует аннотаций типов — компилятор сам выводит их. Это заслуга алгоритма **Hindley-Milner** (Algorithm W).

Рассмотрим выражение `\f x -> f x`. Как GHC выводит его тип?

1. Вводим свежие переменные: `f :: t0`, `x :: t1`, результат `f x :: t2`.
2. Из применения `f x` следует ограничение: `t0 ~ (t1 -> t2)`.
3. Унификация: подставляем `t0 = t1 -> t2`.
4. Обобщение: `(a -> b) -> a -> b` — это тип `($)`!

На практике вам не нужно знать детали алгоритма, но важно понимать *когда аннотации необходимы*:

- **Polymorphic recursion** — функция вызывает себя с другим типом аргумента.
- **RankNTypes** — полиморфизм внутри аргумента.
- **Ambiguity** — когда тип нельзя определить из контекста (как `read "42"` без аннотации).

#### Monomorphism restriction

Без сигнатуры типа GHC иногда «сужает» полиморфный тип до конкретного:

```haskell
-- Без сигнатуры:
plusOne = (+1)
-- GHC может вывести: plusOne :: Integer -> Integer (не полиморфный!)

-- С сигнатурой:
plusOne :: Num a => a -> a
plusOne = (+1)  -- полиморфный
```

Это называется **monomorphism restriction** — оптимизация, которая предотвращает случайное повторное вычисление словарей type classes. В GHCi она отключена, в скомпилированном коде — включена по умолчанию.

```admonish tip title="Type holes — ваш лучший друг"
Не знаете, какой тип подставить? Используйте `_` — GHC сам скажет:

    bar :: [Int] -> Int
    bar xs = foldr _todo 0 xs
    -- GHC: Found hole '_todo' with type: Int -> Int -> Int

Type holes (`_`) — мощнейший инструмент разработки. Вместо угадывания типов —
позвольте компилятору помочь.
```

## Стандартные классы типов

### `Eq` — равенство

```haskell
class Eq a where
  (==) :: a -> a -> Bool
  (/=) :: a -> a -> Bool
```

Минимальное определение: `(==)` или `(/=)` — второй метод выводится автоматически.

### `Ord` — сравнение

```haskell
class Eq a => Ord a where
  compare :: a -> a -> Ordering  -- LT | EQ | GT
  (<), (<=), (>), (>=) :: a -> a -> Bool
  max, min :: a -> a -> a
```

Обратите внимание: `Eq a =>` в заголовке означает, что `Ord` *наследует* `Eq`. Каждый тип с `Ord` автоматически имеет и `Eq`.

```text
> compare 3 5
LT

> max "abc" "abd"
"abd"
```

### `Show` — преобразование в строку

```haskell
class Show a where
  show :: a -> String
```

```text
> show 42
"42"

> show True
"True"

> show [1, 2, 3]
"[1,2,3]"
```

### `Read` — разбор строки

```haskell
read :: Read a => String -> a
```

`read` — обратная операция к `show`:

```text
> read "42" :: Int
42

> read "[1,2,3]" :: [Int]
[1,2,3]
```

Аннотация типа `:: Int` необходима — без неё Haskell не знает, *какой* тип прочитать.

### `Enum` и `Bounded`

`Enum` — типы с последовательными значениями:

```text
> [1..5]
[1,2,3,4,5]

> ['a'..'e']
"abcde"

> succ 'A'
'B'
```

`Bounded` — типы с минимальным и максимальным значением:

```text
> minBound :: Bool
False

> maxBound :: Bool
True

> minBound :: Char
'\NUL'
```

## Собственный класс типов

Определим класс для хэширования — преобразования значения в целое число:

```haskell
class Hashable a where
  hash :: a -> Int
```

Минимальное определение — один метод `hash`. Напишем экземпляры для базовых типов:

```haskell
instance Hashable Int where
  hash = id

instance Hashable Bool where
  hash True  = 1
  hash False = 0

instance Hashable Char where
  hash = fromEnum
```

Вспомогательная функция для комбинирования хэшей:

```haskell
combineHashes :: Int -> Int -> Int
combineHashes h1 h2 = h1 * 31 + h2
```

Множитель 31 — классический приём из хэш-функции Java, дающий хорошее распределение значений.

Теперь можно хэшировать:

```text
> hash (42 :: Int)
42

> hash True
1

> hash 'A'
65
```

### Экземпляр с ограничением

Для пар, где оба компонента хэшируемы:

```haskell
instance (Hashable a, Hashable b) => Hashable (a, b) where
  hash (a, b) = combineHashes (hash a) (hash b)
```

Ограничение `(Hashable a, Hashable b) =>` говорит: «мы можем хэшировать пару, если умеем хэшировать каждый из её элементов».

```text
> hash (True, 'A')
96

> hash (1 :: Int, False)
31
```

## Автоматическая деривация

Писать экземпляры `Eq`, `Show`, `Ord` вручную для каждого типа утомительно. Haskell позволяет генерировать их автоматически:

```haskell
data Color = Red | Green | Blue
  deriving (Eq, Ord, Show, Read)
```

`deriving` создаёт «очевидные» экземпляры:

- `Eq`: конструкторы равны, если они одинаковы.
- `Ord`: порядок определяется позицией конструктора (`Red < Green < Blue`).
- `Show`: `show Red` → `"Red"`.
- `Read`: `read "Red" :: Color` → `Red`.

Стандартно можно деривировать: `Eq`, `Ord`, `Show`, `Read`, `Enum`, `Bounded`, `Functor`, `Foldable`, `Traversable` (последние три — с соответствующими расширениями GHC).

### `DerivingStrategies`

С расширением `DerivingStrategies` (включено в нашем проекте) можно явно указать *стратегию* деривации:

```haskell
data Color = Red | Green | Blue
  deriving stock (Eq, Ord, Show, Read, Enum, Bounded)
```

**`stock`** — стандартная деривация (как без расширения). Работает для встроенного списка классов.

**`newtype`** — для `newtype`-обёрток. Делегирует экземпляр обёрнутому типу:

```haskell
newtype Age = Age { getAge :: Int }
  deriving stock (Show)           -- show: "Age {getAge = 25}"
  deriving newtype (Eq, Ord, Num) -- ==, <, + делегируются Int
```

```text
> Age 20 + Age 5
Age {getAge = 25}

> Age 20 < Age 30
True
```

Без `deriving newtype` пришлось бы писать:

```haskell
instance Num Age where
  Age a + Age b = Age (a + b)
  Age a * Age b = Age (a * b)
  abs (Age a) = Age (abs a)
  signum (Age a) = Age (signum a)
  fromInteger = Age . fromInteger
  negate (Age a) = Age (negate a)
```

Шесть методов вместо одной строки!

`GeneralizedNewtypeDeriving` — расширение, которое делает `deriving newtype` возможным для произвольных классов (не только стандартных). Оно включено в нашем проекте.

### `anyclass`

Третья стратегия — `anyclass` — использует реализацию по умолчанию всех методов. Она полезна с `DeriveGeneric` и библиотеками типа `aeson`, но выходит за рамки этой главы.

## Введение в `Functor`, `Foldable`, `Traversable`

Три класса, которые обобщают операции на «контейнерах». Мы кратко познакомимся с ними здесь; подробнее — в главе 7.

Но сначала разберём важное понятие, без которого эти классы не получится понять до конца.

### Кайнды (Kinds)

Типы в Haskell сами имеют «типы» — они называются **кайндами** (kinds). Кайнд описывает, сколько аргументов ожидает конструктор типа.

- **`Type`** (он же `*`) — кайнд конкретных типов, которые могут иметь значения:

    ```text
    Int    :: Type
    Bool   :: Type
    String :: Type
    ```

- **`Type -> Type`** — кайнд конструкторов типов, принимающих один аргумент:

    ```text
    Maybe  :: Type -> Type      -- Maybe Int :: Type, Maybe String :: Type
    []     :: Type -> Type      -- [Int] :: Type
    IO     :: Type -> Type      -- IO () :: Type
    ```

- **`Type -> Type -> Type`** — кайнд конструкторов с двумя параметрами:

    ```text
    Either :: Type -> Type -> Type   -- Either String Int :: Type
    (,)    :: Type -> Type -> Type   -- (Int, Bool) :: Type
    Map    :: Type -> Type -> Type   -- Map String Int :: Type
    ```

Почему это важно? Классы типов ожидают аргументы определённого кайнда. Например, `Functor` требует `f :: Type -> Type`:

```text
instance Functor Maybe       -- ОК: Maybe :: Type -> Type
instance Functor []          -- ОК: [] :: Type -> Type
instance Functor Int          -- Ошибка! Int :: Type, а нужен Type -> Type
```

Конструкторы типов можно **частично применять**, как и функции. `Either` имеет кайнд `Type -> Type -> Type`, но если зафиксировать первый аргумент:

```text
Either String :: Type -> Type
```

Поэтому `instance Functor (Either String)` допустим — `Either String` имеет нужный кайнд.

В GHCi можно узнать кайнд любого типа командой `:kind` (или `:k`):

```text
> :kind Int
Int :: *

> :kind Maybe
Maybe :: * -> *

> :kind Either
Either :: * -> * -> *

> :kind Either String
Either String :: *-> *
```

GHCi показывает `*` вместо `Type` — это синонимы.

### `Functor`

```haskell
class Functor f where
  fmap :: (a -> b) -> f a -> f b
```

`fmap` — обобщённый `map`. Работает не только со списками:

```text
> fmap (+1) [1, 2, 3]
[2,3,4]

> fmap (*2) (Just 5)
Just 10

> fmap show (Right 42 :: Either String Int)
Right "42"
```

Оператор `<$>` — инфиксный синоним `fmap`:

```text
> (*2) <$> Just 5
Just 10
```

```admonish note title="Что дальше"
`Functor` трансформирует *содержимое* контейнера. Но что если тип не содержит `a`,
а *потребляет* его (например, `Predicate a = a -> Bool`)? Для таких типов существует
«зеркальный» `Functor` — `Contravariant`. Подробнее — в главе 19.
```

### `Foldable`

```haskell
class Foldable t where
  foldr  :: (a -> b -> b) -> b -> t a -> b
  foldl' :: (b -> a -> b) -> b -> t a -> b
  -- ... и другие методы
```

Обобщение свёрток за пределы списков:

```text
> sum (Just 5)
5

> sum Nothing
0

> length [1, 2, 3]
3
```

### `Traversable`

```haskell
class (Functor t, Foldable t) => Traversable t where
  traverse :: Applicative f => (a -> f b) -> t a -> f (t b)
```

`Traversable` объединяет `Functor` и `Foldable`, добавляя возможность «пройти» по структуре с эффектами. Подробнее — в главе 7.

Все три класса можно деривировать:

```haskell
data Tree a = Leaf a | Branch (Tree a) (Tree a)
  deriving stock (Show, Eq, Functor, Foldable, Traversable)
```

## Проект: библиотека хэширования

Модуль `Data.Hashable` определяет класс `Hashable` и экземпляры для базовых типов:

```haskell
class Hashable a where
  hash :: a -> Int

combineHashes :: Int -> Int -> Int
combineHashes h1 h2 = h1 * 31 + h2
```

Предоставленные экземпляры: `Int`, `Bool`, `Char`, `(a, b)`.

Модуль также экспортирует тип `Coord`:

```haskell
data Coord = Coord
  { coordX :: Double
  , coordY :: Double
  }
```

Экземпляры `Eq` и `Show` для `Coord` не определены — это ваше первое упражнение.

Попробуем в GHCi:

```text
> import Data.Hashable

> hash (42 :: Int)
42

> hash 'Z'
90

> combineHashes (hash True) (hash 'A')
96
```

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

1. **(Среднее)** Напишите экземпляры `Eq` и `Show` для типа `Coord` вручную (без `deriving`).

    - `Eq`: две координаты равны, если совпадают оба поля.
    - `Show`: формат `"(x, y)"` — например, `show (Coord 1.0 2.0)` → `"(1.0, 2.0)"`.

    ```haskell
    instance Eq Coord where ...
    instance Show Coord where ...
    ```

2. **(Среднее)** Напишите экземпляры `Hashable` для `Maybe a`, `Either a b` и `[a]`.

    ```haskell
    instance Hashable a => Hashable (Maybe a) where ...
    instance (Hashable a, Hashable b) => Hashable (Either a b) where ...
    instance Hashable a => Hashable [a] where ...
    ```

    *Подсказка:* используйте `combineHashes` для комбинирования тега конструктора с хэшем содержимого. Для `Nothing` верните `0`. Для списка используйте `foldl'`.

3. **(Среднее)** Реализуйте функцию `nubByHash`, которая удаляет дубликаты из списка.

    ```haskell
    nubByHash :: (Eq a, Hashable a) => [a] -> [a]
    ```

    ```text
    > nubByHash [1, 2, 3, 1, 2 :: Int]
    [1,2,3]
    ```

    *Подсказка:* используйте аккумулятор для хранения уже встреченных элементов.

4. **(Лёгкое)** В `MySolutions.hs` определён тип:

    ```haskell
    newtype Brightness = Brightness { getBrightness :: Int }
    ```

    Под ним — шесть шаблонных экземпляров с `undefined`. Замените всё это на `DerivingStrategies`:

    - `Show` — стратегия `stock` (показывает имя конструктора).
    - `Eq`, `Ord`, `Num`, `Hashable` — стратегия `newtype` (делегирует `Int`).

    Результат — две строки `deriving` вместо двадцати строк шаблонного кода.

## Заключение

В этой главе мы:

- Разграничили параметрический и ad-hoc полиморфизм; узнали о свободных теоремах.
- Узнали, что классы типов — механизм ad-hoc полиморфизма: одна операция, много реализаций.
- Познакомились со стандартными классами: `Eq`, `Ord`, `Show`, `Read`, `Enum`, `Bounded`.
- Научились определять собственные классы и писать экземпляры.
- Разобрали вывод типов (Hindley-Milner), monomorphism restriction и type holes.
- Освоили `deriving` и `DerivingStrategies` (`stock`, `newtype`).
- Разобрали кайнды (kinds) — «типы типов», необходимые для понимания `Functor` и других параметризованных классов.
- Получили введение в `Functor`, `Foldable` и `Traversable`.
- Применили всё это в проекте библиотеки хэширования.

В следующей главе мы подробнее разберём аппликативные функторы и используем их для валидации данных с накоплением ошибок.
