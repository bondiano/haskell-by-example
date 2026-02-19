# Элементы теории категорий

## Цели главы

В этой главе мы соберём разрозненные абстракции из предыдущих глав в единую картину. Вы уже знаете `Functor` (глава 6), `Applicative` (глава 7), `Monad` (глава 8), `Lens` и `Prism` (глава 17). Здесь мы добавим недостающие кусочки: `Contravariant`, `Profunctor`, `Endo` и `Iso` — и покажем, как они связаны через теорию категорий.

Это не курс формальной математики. Цель — дать *словарь для паттернов*, которые вы уже используете.

## Иерархия абстракций

```text
             Functor (fmap: ковариантный)
            /        \
    Applicative    Traversable
        |
      Monad

    Contravariant (contramap: контравариантный)
      |
    Divisible → Decidable

    Bifunctor (bimap)
      |
    Profunctor (dimap: contra по 1-му, co по 2-му)
     /      \
  Strong    Choice
     \      /
    Оптики: Lens, Prism, Iso, Traversal

  Semigroup → Monoid
                 |
               Endo a
```

```admonish info title="Знакомая территория"
Вы уже знаете `Functor` (глава 6), `Applicative` (глава 7), `Monad` (глава 8),
`Semigroup`/`Monoid` (глава 7), `Lens`/`Prism` (глава 17).
Эта глава добавляет недостающие кусочки пазла.
```

## Contravariant

### Мотивация

`Functor` работает для типов-«производителей»: `Maybe a` *содержит* `a`, `[a]` *содержит* `a`. Операция `fmap` трансформирует содержимое:

```haskell
fmap :: Functor f => (a -> b) -> f a -> f b
```

А что если тип *потребляет* `a`? Предикат `a -> Bool` не содержит `a` — он его *принимает*:

```haskell
newtype Predicate a = Predicate { getPredicate :: a -> Bool }
```

Попробуем определить `fmap` для `Predicate`:

```haskell
-- fmap :: (a -> b) -> Predicate a -> Predicate b
-- fmap f (Predicate p) = Predicate (\b -> p (??? b))
-- Нужно: b -> a, но у нас a -> b. Направление не то!
```

### Определение

`Contravariant` — «зеркальный» `Functor`. Стрелка в `contramap` идёт *в обратную сторону*:

```haskell
class Contravariant f where
  contramap :: (b -> a) -> f a -> f b
  --           ^^^^^
  --           b -> a, не a -> b!
```

Для `Predicate`:

```haskell
instance Contravariant Predicate where
  contramap f (Predicate p) = Predicate (p . f)
  -- сначала f :: b -> a, потом p :: a -> Bool
```

### Примеры

```haskell
import Data.Functor.Contravariant

isEven :: Predicate Int
isEven = Predicate even

-- Адаптируем для строк: «строка чётной длины»
hasEvenLength :: Predicate String
hasEvenLength = contramap length isEven
-- contramap length: String -> Int, затем isEven: Int -> Bool
```

```text
> getPredicate hasEvenLength "hi"
True

> getPredicate hasEvenLength "hey"
False
```

Другие контравариантные типы:

```haskell
-- Сравнение
newtype Comparison a = Comparison { getComparison :: a -> a -> Ordering }

-- Эквивалентность
newtype Equivalence a = Equivalence { getEquivalence :: a -> a -> Bool }

-- Обе контравариантны: адаптируем вход, не выход
byAge :: Comparison Person
byAge = contramap personAge defaultComparison
```

```admonish info title="Знакомый аналог"
**TypeScript:** `(input: A) => boolean` — это `Predicate A`. Если нужно адаптировать
для типа `B`, пишем `(b: B) => predicate(toA(b))`. Это и есть `contramap toA predicate`.

**Python:** `key=lambda x: x.age` в `sorted()` — это contramap!
`sorted(people, key=lambda p: p.age)` ≈ `getComparison (contramap age defaultComparison)`.
```

```admonish warning title="Направление стрелки"
`contramap` идёт «в обратную сторону» относительно `fmap`. Если интуиция подсказывает,
что типы не сходятся — попробуйте перевернуть стрелку. Правило: `fmap` — для выходов
(ковариантная позиция), `contramap` — для входов (контравариантная позиция).
```

### Ковариантность vs контравариантность

| | Ковариантный (`Functor`) | Контравариантный (`Contravariant`) |
|---|---|---|
| Метод | `fmap :: (a -> b) -> f a -> f b` | `contramap :: (b -> a) -> f a -> f b` |
| Направление | По стрелке | Против стрелки |
| Тип «содержит» a | Да (`Maybe a`, `[a]`) | Нет — «потребляет» a |
| Примеры | `Maybe`, `[]`, `IO`, `Either e` | `Predicate`, `Comparison`, `Op` |

## Profunctor

### Мотивация

Функция `a -> b` одновременно *потребляет* `a` (контравариантная позиция) и *производит* `b` (ковариантная позиция). Тип, который контравариантен по первому аргументу и ковариантен по второму, называется **профунктором**:

```haskell
class Profunctor p where
  dimap :: (c -> a) -> (b -> d) -> p a b -> p c d
  --       ^^^^^^^     ^^^^^^^
  --       contra      co
```

`dimap` — «обернуть» вход и выход одновременно: преобразовать входные данные *перед* обработкой и результат *после*.

### Канонический пример: `(->)`

```haskell
instance Profunctor (->) where
  dimap pre post f = post . f . pre
  -- pre :: c -> a    (преобразовать вход)
  -- f   :: a -> b    (обработать)
  -- post :: b -> d   (преобразовать выход)
```

```haskell
-- Капитализация фраз:
-- 1. Разбить строку на слова (pre)
-- 2. Капитализировать каждое (f)
-- 3. Склеить обратно (post)
capitalizePhrase :: String -> String
capitalizePhrase = dimap words unwords (map capitalize)
  where capitalize []     = []
        capitalize (c:cs) = toUpper c : cs
```

```text
> capitalizePhrase "hello beautiful world"
"Hello Beautiful World"
```

```admonish example title="Пример: dimap как обёртка"
`dimap words unwords :: (String -> String) -> ([String] -> [String])`

Это «оборачивает» функцию: сначала разбивает строку на слова, обрабатывает список слов,
затем склеивает обратно. Вход и выход функции трансформируются независимо.
```

### Связь с оптиками

В главе 17 мы видели profunctor encoding линз:

```haskell
type Lens  s t a b = forall p. Strong p     => p a b -> p s t
type Prism s t a b = forall p. Choice p     => p a b -> p s t
type Iso   s t a b = forall p. Profunctor p => p a b -> p s t
```

`Iso` требует только `Profunctor` — это самая слабая (и потому самая общая) оптика. `Lens` добавляет `Strong`, `Prism` — `Choice`. Иерархия оптик — это иерархия ограничений на профунктор.

## Endomorphism (Endo)

### Мотивация

Функция `a -> a` — **эндоморфизм**: она не меняет тип. Под композицией с `id` такие функции образуют моноид:

```haskell
newtype Endo a = Endo { appEndo :: a -> a }

instance Semigroup (Endo a) where
  Endo f <> Endo g = Endo (f . g)

instance Monoid (Endo a) where
  mempty = Endo id
```

Мы уже познакомились с `Endo` в главе 7. Здесь рассмотрим его практическое применение.

### Config Builder

Паттерн «список модификаторов, применяемых последовательно»:

```haskell
data Config = Config
  { configPort    :: Int
  , configHost    :: String
  , configVerbose :: Bool
  } deriving Show

defaultConfig :: Config
defaultConfig = Config 8080 "localhost" False

setPort :: Int -> Endo Config
setPort p = Endo $ \c -> c { configPort = p }

setHost :: String -> Endo Config
setHost h = Endo $ \c -> c { configHost = h }

setVerbose :: Endo Config
setVerbose = Endo $ \c -> c { configVerbose = True }

-- Композиция через mconcat:
productionConfig :: Config
productionConfig = appEndo
  (mconcat [setPort 443, setHost "example.com", setVerbose])
  defaultConfig
-- Config { configPort = 443, configHost = "example.com", configVerbose = True }
```

### Middleware

Тот же паттерн — в middleware-цепочках:

```haskell
type Middleware = Endo Application
-- Application ~ Request -> IO Response

logging :: Middleware
logging = Endo $ \app req -> do
  putStrLn $ "Request: " <> show req
  app req

auth :: Middleware
auth = Endo $ \app req -> do
  if authorized req then app req
  else pure forbidden

-- Композиция: logging *после* auth
stack :: Middleware
stack = logging <> auth  -- = Endo (logging . auth)
```

```admonish info title="Знакомый аналог"
**TypeScript:** Express middleware `(req, res, next) => { ... next() }` — эндоморфизм
на handler pipeline. `app.use(a).use(b).use(c)` ≈ `appEndo (mconcat [a, b, c])`.

**Python:** Django middleware, Flask `@app.before_request` — аналогичная композиция.
```

## Isomorphism (Iso)

### Мотивация

Два типа **изоморфны**, если между ними есть биекция — пара функций `to` и `from`, таких что `to . from == id` и `from . to == id`. Информация не теряется ни в одном направлении.

### Стандартные изоморфизмы

```text
(a, b)        ≅  (b, a)           -- swap
(a, (b, c))   ≅  ((a, b), c)     -- assoc
Either () a   ≅  Maybe a          -- вложение «пустоты»
(a -> b -> c) ≅  ((a, b) -> c)   -- curry / uncurry
```

В Haskell каждый `newtype` — это изоморфизм:

```haskell
newtype Age = Age { unAge :: Int }
-- Age :: Int -> Age     (to)
-- unAge :: Age -> Int   (from)
-- unAge . Age == id, Age . unAge == id
```

### Iso в lens

В главе 17 мы определили:

```haskell
celsiusFahrenheit :: Iso' Double Double
celsiusFahrenheit = iso (\c -> c * 9/5 + 32) (\f -> (f - 32) * 5/9)
```

`Iso` — оптика, которая «видит» весь тип. В отличие от `Lens` (видит часть) или `Prism` (видит один конструктор), `Iso` — полная биекция.

```admonish info title="Знакомый аналог"
**TypeScript:** `JSON.stringify` / `JSON.parse` — *почти* изоморфизм, но теряет
`undefined`, функции, `Date`. В Haskell `aeson` + deriving — настоящий изоморфизм
для ваших типов (если тип полностью представим в JSON).
```

## Шпаргалка

| Абстракция | Класс | Ключевой метод | Интуиция |
|------------|-------|----------------|----------|
| Contravariant | `Contravariant` | `contramap :: (b -> a) -> f a -> f b` | Адаптировать потребителя |
| Profunctor | `Profunctor` | `dimap :: (c -> a) -> (b -> d) -> p a b -> p c d` | Обернуть вход и выход |
| Endo | `Monoid (Endo a)` | `appEndo :: Endo a -> a -> a` | Цепочка трансформаций |
| Iso | `Iso' s a` | `iso :: (s -> a) -> (a -> s) -> Iso' s a` | Два типа = одна форма |

## Дальнейшее чтение

- [Typeclassopedia (HaskellWiki)](https://wiki.haskell.org/Typeclassopedia) — полная карта иерархии type classes.
- Bartosz Milewski, *Category Theory for Programmers* — доступное введение в теорию категорий для программистов.
- [Don't Fear the Profunctor Optics](https://github.com/hablapps/DontFearTheProfunctorOptics) — связь профункторов и оптик.
