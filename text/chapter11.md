# Functor и Applicative

Добро пожаловать в Часть III! В первых десяти главах мы познакомились с типами, ADT, классами типов, IO, обработкой ошибок, ленивостью и тестированием. Попутно мы сталкивались с одним и тем же паттерном: **применение функции к значению внутри контекста** — `Maybe`, `Either`, списка, `IO`. Пора дать этому паттерну имя.

Здесь мы выделим общий паттерн преобразования значений внутри контейнеров, познакомимся с классами `Functor` и `Applicative`, построим тип `Validation` для накопления *всех* ошибок валидации и применим всё это для валидации формы создания задач в трекере. К концу главы станет ясно, как `Functor` и `Applicative` устраняют вложенный `case`, с которым мы мучились в [главе 8](chapter08.md).

## Проблема: повторяющийся паттерн

Вспомним код из предыдущих глав:

```haskell
-- Применяем функцию к каждому элементу списка
map (+1) [1, 2, 3]         -- [2, 3, 4]

-- Преобразуем значение внутри Maybe
case maybePriority of
  Nothing -> Nothing
  Just p  -> Just (show p)

-- Преобразуем успешный результат Either
case parseResult of
  Left err -> Left err
  Right x  -> Right (process x)
```

Во всех случаях мы делаем одно и то же: **применяем функцию к значению внутри контейнера, не меняя сам контейнер**. Если `Maybe` — это `Nothing`, результат остаётся `Nothing`. Если `Either` — это `Left err`, ошибка сохраняется.

В [главе 8](chapter08.md) мы видели боль вложенных `case`:

```haskell
createTask :: String -> String -> String -> Either String Task
createTask rawTitle rawDesc rawPrio =
  case validateTitle rawTitle of
    Left err -> Left err
    Right title ->
      case validateDescription rawDesc of
        Left err -> Left err
        Right desc ->
          case parsePriority rawPrio of
            Left err -> Left err
            Right prio -> Right (Task title desc prio Todo)
```

Три уровня вложенности — и это всего три поля! Должен быть способ лучше.

```admonish tip title="Знакомый аналог"
Паттерн «лестницы» знаком из JavaScript до `async/await` — callback hell. `Functor` и `Applicative` — первые шаги к устранению подобных вложенностей в Haskell.
```

## Functor

### Класс типов Functor

`Functor` — класс типов для контейнеров, внутри которых можно преобразовать значение:

```haskell
class Functor f where
  fmap :: (a -> b) -> f a -> f b
```

Здесь `f` — **конструктор типа** (type constructor): `Maybe`, `Either e`, `[]`, `IO`. Каждый из них принимает один параметр и даёт конкретный тип (`Maybe Int`, `[String]` и т.д.).

`fmap` берёт функцию `a -> b` и «поднимает» её внутрь контейнера: преобразует `f a` в `f b`, не меняя структуру.

### Инстансы для знакомых типов

```haskell
instance Functor Maybe where
  fmap _ Nothing  = Nothing
  fmap f (Just x) = Just (f x)

instance Functor (Either e) where
  fmap _ (Left e)  = Left e
  fmap f (Right x) = Right (f x)

instance Functor [] where
  fmap = map
```

Обратите внимание: `Either e` — это `Functor`, а не `Either`. Конструктор `Either` принимает два параметра, но `Functor` ожидает конструктор с одним. Мы «фиксируем» тип ошибки — это частичное применение на уровне типов.

### Оператор <$>

`<$>` — инфиксный синоним `fmap`. Визуально напоминает `$`, но работает «сквозь» контейнер:

```text
> fmap (+1) (Just 5)
Just 6

> (+1) <$> Just 5
Just 6

> show <$> Just 42
Just "42"

> (*2) <$> [1, 2, 3]
[2, 4, 6]

> length <$> (Right "hello" :: Either String Int)
Right 5
```

```admonish tip title="Знакомый аналог"
`fmap` / `<$>` — обобщение `.map()` из JavaScript, Python, Rust. Разница в том, что `fmap` работает не только для списков, а для *любого* `Functor`: `Maybe`, `Either`, `IO`, деревьев, парсеров и т.д.
```

### Законы Functor

Каждый корректный инстанс `Functor` должен удовлетворять двум законам:

```haskell
-- 1. Тождество: преобразование id не меняет значение
fmap id x == id x

-- 2. Композиция: два fmap можно заменить одним
fmap (f . g) x == (fmap f . fmap g) x
```

Законы гарантируют, что `fmap` **только** преобразует содержимое и не меняет структуру контейнера: не добавляет элементы в список, не превращает `Just` в `Nothing`, не меняет ветку `Either`.

```admonish note title="Зачем нужны законы?"
Законы позволяют рассуждать о коде: `fmap f . fmap g` можно безопасно заменить на `fmap (f . g)` — один проход вместо двух. Компилятор иногда делает такие оптимизации автоматически (через rewrite rules).
```

### Написание собственного инстанса

Допустим, у нас есть тип «значение с меткой»:

```haskell
data Labelled a = Labelled String a
  deriving (Show, Eq)

instance Functor Labelled where
  fmap f (Labelled label x) = Labelled label (f x)
```

```text
> fmap (*2) (Labelled "результат" 21)
Labelled "результат" 42
```

````admonish tip title="Автоматический вывод"
GHC может вывести `Functor` автоматически с расширением `DeriveFunctor` (включено в нашем проекте):

```haskell
data Labelled a = Labelled String a
  deriving stock (Show, Eq, Functor)
```
````

## Applicative

### Мотивация: функции нескольких аргументов

`fmap` работает с функциями одного аргумента. Но что, если функция принимает два аргумента?

```text
> :type fmap (+) (Just 3)
fmap (+) (Just 3) :: Num a => Maybe (a -> a)
```

Мы получили `Maybe (a -> a)` — функцию *внутри* `Maybe`! Как применить её к другому `Maybe`? У `fmap` нет такой возможности. Нужен оператор, применяющий функцию внутри контейнера к значению внутри контейнера.

### Класс типов Applicative

```haskell
class Functor f => Applicative f where
  pure  :: a -> f a
  (<*>) :: f (a -> b) -> f a -> f b
```

- **`pure`** — помещает значение в «минимальный» контекст: `pure 5 :: Maybe Int` даёт `Just 5`.
- **`<*>`** (произносится «ap») — применяет функцию в контейнере к значению в контейнере.

Ограничение `Functor f =>` означает, что каждый `Applicative` — автоматически `Functor`. Иерархия: `Functor` -> `Applicative` -> `Monad`.

### Паттерн f <$> a <*> b <*> c

Ключевая идиома `Applicative`:

```haskell
-- Обычное применение:
Task title desc prio Todo

-- Применение к значениям в контейнерах:
Task <$> validateTitle title
     <*> validateDescription desc
     <*> parsePriority prio
     <*> pure Todo
```

Разберём по шагам для `Maybe`:

```text
> (+) <$> Just 3 <*> Just 5
-- Шаг 1: (+) <$> Just 3  =  Just (+3)    -- fmap
-- Шаг 2: Just (+3) <*> Just 5  =  Just 8 -- <*>
Just 8

> (+) <$> Nothing <*> Just 5
Nothing

> (,,) <$> Just "a" <*> Just "b" <*> Just "c"
Just ("a","b","c")
```

## Applicative для Maybe и Either

### Maybe: остановка на первом Nothing

```haskell
instance Applicative Maybe where
  pure = Just
  Nothing <*> _ = Nothing
  Just f  <*> x = fmap f x
```

При первом `Nothing` вычисление «короткозамыкается» — именно то поведение, которое мы реализовывали вручную через вложенный `case`!

### Either e: остановка на первой ошибке

```haskell
instance Applicative (Either e) where
  pure = Right
  Left e  <*> _ = Left e
  Right f <*> x = fmap f x
```

```text
> (+) <$> Right 3 <*> Right 5
Right 8

> (+) <$> Left "ошибка 1" <*> Left "ошибка 2"
Left "ошибка 1"
```

`Either` возвращает **только первую ошибку**. Вторая теряется — для валидации форм это неудобно.

### Перепишем createTask

```haskell
-- Было (вложенные case — 12 строк):
createTask rawTitle rawDesc rawPrio =
  case validateTitle rawTitle of
    Left err -> Left err
    Right title -> case validateDescription rawDesc of ...

-- Стало (Applicative — 4 строки):
createTask :: String -> String -> String -> Either String Task
createTask rawTitle rawDesc rawPrio =
  Task <$> validateTitle rawTitle
       <*> validateDescription rawDesc
       <*> parsePriority rawPrio
       <*> pure Todo
```

Никаких вложенных `case`. При первой ошибке вычисление останавливается и возвращает `Left`.

### Applicative для списков

У списков `Applicative` комбинирует *все* пары — декартово произведение:

```text
> (*) <$> [1, 2, 3] <*> [10, 100]
[10, 100, 20, 200, 30, 300]

> (,) <$> ["a", "b"] <*> [1, 2]
[("a",1),("a",2),("b",1),("b",2)]
```

## Validation — накопление ошибок

### Проблема Either

`Either` останавливается на первой ошибке. Но при валидации формы мы хотим показать *все* проблемы сразу. Нужен другой тип.

### Тип Validation

```haskell
data Validation e a
  = Failure e
  | Success a
  deriving (Show, Eq)
```

Внешне похож на `Either`, но `Applicative`-инстанс **накапливает** ошибки:

```haskell
instance Functor (Validation e) where
  fmap _ (Failure e) = Failure e
  fmap f (Success x) = Success (f x)

instance Semigroup e => Applicative (Validation e) where
  pure = Success
  Failure e1 <*> Failure e2 = Failure (e1 <> e2)  -- накапливаем!
  Failure e  <*> _          = Failure e
  _          <*> Failure e  = Failure e
  Success f  <*> Success x  = Success (f x)
```

Ограничение `Semigroup e` требует, чтобы ошибки можно было объединять через `(<>)`. Для списков `(<>)` — конкатенация, поэтому `Validation [Text]` собирает ошибки в список.

```text
-- Either: только первая ошибка
> Left ["ошибка 1"] <*> Left ["ошибка 2"]
Left ["ошибка 1"]

-- Validation: обе ошибки
> Failure ["ошибка 1"] <*> Failure ["ошибка 2"]
Failure ["ошибка 1","ошибка 2"]
```

```admonish tip title="Знакомый аналог"
`Validation` — аналог валидации форм в Zod/Yup (JavaScript), где `safeParse` возвращает массив *всех* ошибок, а не только первой. Или `Promise.allSettled()`, собирающий результаты всех промисов.
```

```admonish warning title="Validation и Monad"
`Validation` **не может** иметь корректный инстанс `Monad`. В монаде каждый шаг зависит от предыдущего (`>>=`), а если первое вычисление провалилось — нет значения для передачи. Поэтому `Validation` живёт на уровне `Applicative`: все вычисления независимы.
```

## Traversable: обход с эффектами

Класс `Traversable` тесно связан с `Applicative`:

```haskell
class (Functor t, Foldable t) => Traversable t where
  traverse :: Applicative f => (a -> f b) -> t a -> f (t b)
```

`traverse` — «`map` с эффектами». Применяет функцию к каждому элементу и собирает результаты:

```text
> traverse readMaybe ["1", "2", "3"] :: Maybe [Int]
Just [1, 2, 3]

> traverse readMaybe ["1", "abc", "3"] :: Maybe [Int]
Nothing
```

Частный случай — `sequence`, «выворачивающий» структуру:

```haskell
sequence :: (Traversable t, Applicative f) => t (f a) -> f (t a)
```

```text
> sequence [Just 1, Just 2, Just 3]
Just [1, 2, 3]

> sequence [Just 1, Nothing, Just 3]
Nothing
```

## Проект: валидация формы создания задач

Соберём всё вместе — валидация ввода для трекера с `Validation`.

### Валидаторы полей

```haskell
import Data.Text (Text)
import qualified Data.Text as T

validateTitle :: Text -> Validation [Text] Text
validateTitle title
  | T.null (T.strip title)  = Failure ["Заголовок не может быть пустым"]
  | T.length title > 100    = Failure ["Заголовок слишком длинный"]
  | otherwise                = Success (T.strip title)

validatePriority :: Text -> Validation [Text] Priority
validatePriority txt = case T.toLower (T.strip txt) of
  "low"    -> Success Low
  "medium" -> Success Medium
  "high"   -> Success High
  _        -> Failure ["Приоритет должен быть low, medium или high"]

validateDescription :: Text -> Validation [Text] Text
validateDescription desc
  | T.length desc > 500 = Failure ["Описание слишком длинное"]
  | otherwise            = Success desc
```

### Собираем форму

```haskell
validateTaskInput :: Text -> Text -> Text -> Validation [Text] Task
validateTaskInput rawTitle rawDesc rawPrio =
  Task <$> validateTitle rawTitle
       <*> validateDescription rawDesc
       <*> validatePriority rawPrio
       <*> pure Todo
```

```text
> validateTaskInput "Изучить Functor" "" "high"
Success (Task "Изучить Functor" "" High Todo)

> validateTaskInput "" "" "oops"
Failure ["Заголовок не может быть пустым",
         "Приоритет должен быть low, medium или high"]
```

Обе ошибки возвращены одновременно! С `Either` мы бы увидели только первую. Для перехода обратно к `Either` используем конвертер:

```haskell
validationToEither :: Validation e a -> Either e a
validationToEither (Failure e) = Left e
validationToEither (Success x) = Right x
```

## Шпаргалка

| Абстракция | Метод | Сигнатура | Что делает |
|---|---|---|---|
| `Functor` | `fmap` / `<$>` | `(a -> b) -> f a -> f b` | Преобразует значение внутри контейнера |
| `Applicative` | `pure` | `a -> f a` | Помещает значение в контейнер |
| `Applicative` | `<*>` | `f (a -> b) -> f a -> f b` | Применяет функцию в контейнере |
| `Traversable` | `traverse` | `(a -> f b) -> t a -> f (t b)` | `map` с эффектами |

**Иерархия:**

```text
Functor        fmap     — преобразование (1 аргумент)
  ↓
Applicative    <*>      — комбинирование независимых вычислений
  ↓
Monad          >>=      — цепочка зависимых вычислений (глава 12)
```

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test chapter11`.

### Проект ★☆☆

1. Напишите функцию `validateTitle`, которая проверяет заголовок задачи: непустой и не длиннее 100 символов. Верните `Validation [Text] Text`.

    ```haskell
    validateTitle :: Text -> Validation [Text] Text
    ```

2. Напишите функцию `validatePriority`, которая парсит строку `"low"`, `"medium"`, `"high"` (регистронезависимо) в `Priority`.

    ```haskell
    validatePriority :: Text -> Validation [Text] Priority
    ```

### Проект ★★☆

3. Реализуйте тип `Validation e a` с инстансами `Functor` и `Applicative`. Напишите `validateTaskInput`, возвращающую все ошибки одновременно.

    ```haskell
    data Validation e a = Failure e | Success a

    validateTaskInput :: Text -> Text -> Text -> Validation [Text] Task
    validateTaskInput rawTitle rawDesc rawPrio =
      Task <$> validateTitle rawTitle <*> ...
    ```

### Практика ★☆☆

4. Напишите инстанс `Functor` для типа `Labelled`:

    ```haskell
    data Labelled a = Labelled String a

    instance Functor Labelled where
      fmap = ...
    ```

5. Напишите инстанс `Functor` для `RoseTree`:

    ```haskell
    data RoseTree a = RoseNode a [RoseTree a]

    instance Functor RoseTree where
      fmap = ...
    ```

    *Подсказка:* рекурсия и `map` для списка поддеревьев.

### Практика ★★☆

6. Напишите инстанс `Applicative` для `Labelled`, объединяя метки через `(<>)`:

    ```haskell
    instance Applicative Labelled where
      pure x = Labelled "" x
      Labelled l1 f <*> Labelled l2 x = Labelled (l1 <> l2) (f x)
    ```

    Проверьте: `(+) <$> Labelled "a" 3 <*> Labelled "b" 5` даёт `Labelled "ab" 8`.

## Заключение

`Functor` и `Applicative` — не абстрактная математика, а практические инструменты, убирающие шаблонный код. `fmap` и `<$>` обобщают `map` на любые контейнеры, а `<*>` позволяет комбинировать независимые вычисления с эффектами. Паттерн `f <$> a <*> b <*> c` заменяет вложенные `case`, а тип `Validation` решает проблему накопления ошибок, которую `Either` не покрывает.

Но `Applicative` работает только с **независимыми** вычислениями. Что, если результат одного вычисления нужен *внутри* другого? Для этого нам понадобятся **монады** — тема [следующей главы](chapter12.md).

```admonish tip title="Для углубления"
- **Haskell MOOC** — [haskell.mooc.fi](https://haskell.mooc.fi/), лекции 12 и 15: Functors, Applicatives.
- **Typeclassopedia** — Brent Yorgey, раздел Functor и Applicative: [wiki.haskell.org/Typeclassopedia](https://wiki.haskell.org/Typeclassopedia).
- **Learn You a Haskell** — глава «Functors, Applicative Functors and Monoids»: [learnyouahaskell.com](http://learnyouahaskell.com/functors-applicative-functors-and-monoids).
```
