# Аппликативная валидация

## Цели главы

В этой главе мы разберём аппликативные функторы (Applicative) — промежуточное звено между `Functor` и `Monad`. Мы создадим собственный тип `Validation` для накопления ошибок и сравним его с `Either`. Также мы познакомимся с `Traversable` и функцией `traverse`.

Проект главы — валидация данных адресной книги.

## От `Functor` к `Applicative`

В главе 6 мы познакомились с `Functor` и операцией `fmap`:

```haskell
fmap :: Functor f => (a -> b) -> f a -> f b
```

`fmap` применяет функцию *одного* аргумента к значению «в контексте» (список, `Maybe`, `Either`...). Но что если функция принимает *два* аргумента?

```text
> fmap (+) (Just 3)
Just (3+)    -- тип: Maybe (Int -> Int)
```

Мы получили функцию *внутри* `Maybe`. Чтобы применить её к следующему значению, нужен новый оператор — `<*>`:

```text
> fmap (+) (Just 3) <*> Just 5
Just 8

> (+) <$> Just 3 <*> Just 5
Just 8
```

### Класс `Applicative`

```haskell
class Functor f => Applicative f where
  pure  :: a -> f a
  (<*>) :: f (a -> b) -> f a -> f b
```

- `pure` — оборачивает значение в контекст.
- `<*>` — применяет функцию в контексте к значению в контексте.

Паттерн `f <$> a <*> b <*> c` — конструктор или функция, применённые к нескольким значениям «в контекстах»:

```haskell
data User = User String Int

mkUser :: Maybe User
mkUser = User <$> Just "Иван" <*> Just 25
-- Just (User "Иван" 25)
```

### `Applicative` для `Maybe`

```haskell
instance Applicative Maybe where
  pure = Just
  Nothing <*> _ = Nothing
  Just f  <*> x = fmap f x
```

Если хотя бы один аргумент — `Nothing`, результат — `Nothing`:

```text
> (+) <$> Just 3 <*> Nothing
Nothing

> (+) <$> Nothing <*> Just 5
Nothing
```

### `Applicative` для `Either`

```haskell
instance Applicative (Either e) where
  pure = Right
  Left e  <*> _ = Left e      -- останавливается на первой ошибке!
  Right f <*> r = fmap f r
```

`Either` — **fail-fast**: при первой ошибке вычисление прекращается:

```text
> (+) <$> Left "ошибка 1" <*> Left "ошибка 2"
Left "ошибка 1"    -- вторая ошибка потеряна!
```

## Тип `Validation`

Что если мы хотим собрать *все* ошибки, а не останавливаться на первой? Для этого нужен другой тип:

```haskell
data Validation e a
  = Failure e
  | Success a
```

Выглядит как `Either`, но с другим `Applicative`:

```haskell
instance Semigroup e => Applicative (Validation e) where
  pure = Success
  Failure e1 <*> Failure e2 = Failure (e1 <> e2)  -- накапливает!
  Failure e  <*> _          = Failure e
  _          <*> Failure e  = Failure e
  Success f  <*> Success a  = Success (f a)
```

Ключевая строка: `Failure e1 <*> Failure e2 = Failure (e1 <> e2)` — ошибки **объединяются** через `Semigroup`. Для списков строк `[String]` это конкатенация списков.

### Пример: валидация адреса

```haskell
type Errors = [String]

nonEmpty :: String -> String -> Validation Errors String
nonEmpty field "" = Failure [field <> " не может быть пустым"]
nonEmpty _ value  = Success value

validateAddress :: String -> String -> String -> Validation Errors Address
validateAddress s c st =
  Address <$> nonEmpty "Улица" s
          <*> nonEmpty "Город" c
          <*> nonEmpty "Регион" st
```

Разберём выражение `Address <$> ... <*> ... <*> ...`:

1. `Address` — конструктор с тремя аргументами: `String -> String -> String -> Address`.
2. `Address <$> nonEmpty "Улица" s` — применяет `Address` к первому результату валидации, получая `Validation Errors (String -> String -> Address)`.
3. `... <*> nonEmpty "Город" c` — применяет частично применённый конструктор ко второму результату.
4. `... <*> nonEmpty "Регион" st` — применяет к третьему, получая `Validation Errors Address`.

Попробуем:

```text
> validateAddress "Ленина 1" "Москва" "МО"
Success (Address {street = "Ленина 1", city = "Москва", state = "МО"})

> validateAddress "" "" ""
Failure ["Улица не может быть пустым","Город не может быть пустым","Регион не может быть пустым"]
```

Три ошибки! `Either` показал бы только первую.

### `Either` vs `Validation`

| | `Either e` | `Validation e` |
|--|-----------|---------------|
| Первая ошибка | Останавливается | Продолжает |
| Все ошибки | Нет | Да (через `Semigroup`) |
| `Monad` | Да | **Нет** |
| Когда использовать | Цепочки зависимых вычислений | Параллельная валидация полей |

`Validation` *не может быть монадой*: в монаде каждый шаг может зависеть от результата предыдущего (`>>=`), поэтому нельзя продолжать при ошибке. Аппликативный стиль подходит, когда проверки *независимы* друг от друга.

## `Traversable`

В главе 6 мы кратко познакомились с `Traversable`. Теперь разберём его подробнее.

`traverse` обобщает `map` с эффектами:

```haskell
traverse :: (Traversable t, Applicative f) => (a -> f b) -> t a -> f (t b)
```

Если `map` преобразует каждый элемент, то `traverse` преобразует каждый элемент *с эффектом* и собирает результаты:

```text
> traverse Just [1, 2, 3]
Just [1, 2, 3]

> traverse (\x -> if x > 0 then Just x else Nothing) [1, -2, 3]
Nothing
```

### `sequenceA`

`sequenceA` — частный случай: `sequenceA = traverse id`. Он «выворачивает» вложенные контексты:

```text
> sequenceA [Just 1, Just 2, Just 3]
Just [1, 2, 3]

> sequenceA [Just 1, Nothing, Just 3]
Nothing
```

### `traverse` с `Validation`

С `Validation` можно валидировать список, накапливая ошибки:

```text
> traverse (nonEmpty "элемент") ["a", "", "c", ""]
Failure ["элемент не может быть пустым","элемент не может быть пустым"]
```

Обе ошибки (для индексов 1 и 3) собрались! Это возможно благодаря аппликативному экземпляру `Validation`.

### Зачем нужен `traverse`

Сравните три подхода:

```haskell
-- 1. map — нет эффектов
map show [1, 2, 3]              -- ["1", "2", "3"]

-- 2. map + sequenceA — два шага
sequenceA (map validate items)  -- Validation Errors [a]

-- 3. traverse — один шаг (= map + sequenceA)
traverse validate items         -- Validation Errors [a]
```

`traverse` делает то же, что `map` + `sequenceA`, но за один проход.

## Semigroup и Monoid

В определении `Validation` мы использовали `<>` для накопления ошибок. Пришло время разобрать `Semigroup` и `Monoid` подробнее — это одни из самых полезных абстракций в Haskell.

### `Semigroup` — тип с ассоциативной операцией

```haskell
class Semigroup a where
  (<>) :: a -> a -> a
  -- Закон: (x <> y) <> z == x <> (y <> z)   (ассоциативность)
```

Списки, строки, числа (под сложением или умножением) — всё это полугруппы:

```text
> [1,2] <> [3,4]
[1,2,3,4]

> "hello" <> " " <> "world"
"hello world"
```

### `Monoid` — полугруппа с нейтральным элементом

```haskell
class Semigroup a => Monoid a where
  mempty :: a
  -- Законы:
  --   mempty <> x == x                 (левый нейтральный)
  --   x <> mempty == x                 (правый нейтральный)
  --   (x <> y) <> z == x <> (y <> z)  (ассоциативность)
```

```text
> mempty :: String
""

> mempty :: [Int]
[]
```

### Стандартные newtype-обёртки

Для чисел существуют *две* осмысленные операции: сложение и умножение. Поскольку тип может иметь только один экземпляр `Monoid`, Haskell использует newtype-обёртки:

```haskell
import Data.Monoid

-- Сложение
> getSum (Sum 3 <> Sum 4 <> Sum 5)
12

-- Умножение
> getProduct (Product 3 <> Product 4)
12

-- Логическое И
> getAll (All True <> All True <> All False)
False

-- Логическое ИЛИ
> getAny (Any False <> Any False <> Any True)
True

-- Первый Just
> getFirst (First Nothing <> First (Just 42) <> First (Just 0))
Just 42

-- Последний Just
> getLast (Last (Just 42) <> Last Nothing <> Last (Just 0))
Just 0
```

### `foldMap` — map и mconcat в один проход

```haskell
foldMap :: (Foldable t, Monoid m) => (a -> m) -> t a -> m
```

`foldMap` — «перевести каждый элемент в моноид и склеить»:

```text
> foldMap Sum [1, 2, 3, 4, 5]
Sum {getSum = 15}

> getAll $ foldMap (All . (> 0)) [1, 2, 3]
True

> getAll $ foldMap (All . (> 0)) [1, -2, 3]
False
```

```admonish info title="Знакомый аналог"
**TypeScript:** `Array.prototype.reduce(fn, initial)` — по сути `foldMap`.
`initial` — это `mempty`, `fn` — это `<>`.

**Python:** `functools.reduce` с начальным значением — тот же принцип.
```

### `Endo` — моноид эндоморфизмов

**Эндоморфизм** — функция `a -> a`, которая не меняет тип. Под композицией с `id` такие функции образуют моноид:

```haskell
import Data.Monoid (Endo(..))

applyAll :: [a -> a] -> a -> a
applyAll fs = appEndo (foldMap Endo fs)
```

```text
> applyAll [(+1), (*2), negate] 3
-5
-- negate 3 = -3, (*2) (-3) = -6, (+1) (-6) = -5
```

`Endo` полезен для паттерна **config builder**: список модификаторов конфигурации, применяемых последовательно. Подробнее — в главе 19.

### Шпаргалка

| Обёртка | Операция `<>` | `mempty` | Пример |
|---------|--------------|----------|--------|
| `Sum a` | `(+)` | `0` | `foldMap Sum [1..5]` → `Sum 15` |
| `Product a` | `(*)` | `1` | `foldMap Product [1..5]` → `Product 120` |
| `All` | `(&&)` | `True` | `foldMap (All . even) [2,4]` → `All True` |
| `Any` | `(\|\|)` | `False` | `foldMap (Any . even) [1,3]` → `Any False` |
| `First a` | первый `Just` | `Nothing` | |
| `Last a` | последний `Just` | `Nothing` | |
| `Endo a` | `(.)` | `id` | Композиция функций |

## Проект: валидация адресной книги

Модуль `Data.AddressBook` определяет:

```haskell
data Validation e a
  = Failure e
  | Success a

type Errors = [String]

data Address = Address
  { street :: String
  , city   :: String
  , state  :: String
  }

data Person = Person
  { firstName :: String
  , lastName  :: String
  , address   :: Address
  }
```

Предоставленные валидаторы:

```haskell
nonEmpty        :: String -> String -> Validation Errors String
eitherNonEmpty  :: String -> String -> Either String String
validateAddress :: String -> String -> String -> Validation Errors Address
```

Вспомогательные функции:

```haskell
isSuccess  :: Validation e a -> Bool
isFailure  :: Validation e a -> Bool
errorCount :: Validation [a] b -> Int
```

Попробуем в GHCi:

```text
> import Data.AddressBook

> nonEmpty "Имя" "Иван"
Success "Иван"

> nonEmpty "Имя" ""
Failure ["Имя не может быть пустым"]

> validateAddress "Пушкина 10" "" ""
Failure ["Город не может быть пустым","Регион не может быть пустым"]
```

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

1. **(Среднее)** Реализуйте валидатор телефонного номера. Номер должен быть непустым, содержать только цифры и иметь длину не менее 7 символов. Если несколько условий нарушены — все ошибки должны накопиться.

    ```haskell
    validatePhoneNumber :: String -> Validation Errors String
    ```

    ```text
    > validatePhoneNumber "1234567"
    Success "1234567"

    > validatePhoneNumber "ab"
    Failure [...]    -- две ошибки: не цифры + слишком короткий
    ```

    *Подсказка:* напишите вспомогательную функцию `check :: Bool -> String -> Validation Errors ()` и комбинируйте проверки через `*>`.

2. **(Среднее)** Реализуйте валидацию данных о человеке. Имя и фамилия должны быть непустыми, адрес — валидным.

    ```haskell
    validatePerson :: String -> String -> String -> String -> String
                   -> Validation Errors Person
    ```

    Аргументы: имя, фамилия, улица, город, регион.

    ```text
    > validatePerson "" "" "" "" ""
    Failure [...]    -- пять ошибок (все поля пустые)
    ```

    *Подсказка:* используйте `Person <$> ... <*> ... <*> ...` с `nonEmpty` и `validateAddress`.

3. **(Сложное)** Реализуйте `traverseWithIndex` — аналог `traverse`, который передаёт индекс элемента в функцию.

    ```haskell
    traverseWithIndex :: Applicative f => (Int -> a -> f b) -> [a] -> f [b]
    ```

    ```text
    > traverseWithIndex (\i x -> Just (i, x)) ["a", "b", "c"]
    Just [(0,"a"),(1,"b"),(2,"c")]
    ```

    *Подсказка:* используйте вспомогательную функцию `go` с аккумулятором индекса и комбинируйте через `(:) <$> f i x <*> go (i+1) xs`.

4. **(Среднее)** Реализуйте те же проверки, что в упражнении 2, но используя `Either String` вместо `Validation Errors`.

    ```haskell
    eitherValidateAddress :: String -> String -> String -> Either String Address
    validatePersonEither  :: String -> String -> String -> String -> String
                          -> Either String Person
    ```

    Сравните поведение: при всех пустых полях `validatePerson` вернёт 5 ошибок, а `validatePersonEither` — только одну (первую).

    *Подсказка:* используйте `eitherNonEmpty` из модуля `Data.AddressBook`.

## Заключение

В этой главе мы:

- Разобрали `Applicative` — класс типов между `Functor` и `Monad`.
- Создали тип `Validation` с накоплением ошибок через `Semigroup`.
- Сравнили fail-fast поведение `Either` с аккумулирующим поведением `Validation`.
- Познакомились с `Traversable`, `traverse` и `sequenceA`.
- Систематизировали `Semigroup` и `Monoid`: законы, стандартные обёртки (`Sum`, `Product`, `All`, `Any`, `First`, `Last`, `Endo`), `foldMap`.
- Применили аппликативный стиль к валидации данных адресной книги.

В следующей главе мы перейдём к монаде `IO` и напишем интерактивное приложение адресной книги.
