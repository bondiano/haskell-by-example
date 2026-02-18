# Сопоставление с образцом

## Цели главы

В этой главе мы познакомимся с двумя тесно связанными понятиями: **алгебраическими типами данных** (АТД) и **сопоставлением с образцом** (pattern matching). Мы также разберём охранные выражения (guards), выражения `case`, а также паттерны `as` и wildcard.

Проект главы — библиотека для работы с геометрическими фигурами.

## Простое сопоставление с образцом

Начнём с примера. Вот функция, вычисляющая наибольший общий делитель двух целых чисел (алгоритм Евклида):

```haskell
gcd :: Int -> Int -> Int
gcd n 0 = n
gcd 0 m = m
gcd n m
  | n > m     = gcd (n - m) m
  | otherwise = gcd n (m - n)
```

Функция определена несколькими **альтернативами** (уравнениями). Каждая альтернатива — это набор **образцов** (patterns) слева от `=` и результат справа. Альтернативы проверяются сверху вниз, и первая подходящая определяет результат.

Разберём:

1. Если второй аргумент равен `0`, возвращаем первый.
2. Если первый аргумент равен `0`, возвращаем второй.
3. Иначе — рекурсивно вычитаем меньшее из большего.

## Виды образцов

### Литеральные образцы

Сопоставляются с конкретными значениями:

```haskell
isZero :: Int -> Bool
isZero 0 = True
isZero _ = False
```

Работают для `Int`, `Char`, `String` и других типов с литералами.

### Переменные

Связывают аргумент с именем:

```haskell
greet :: String -> String
greet name = "Привет, " <> name <> "!"
```

### Wildcard (`_`)

Сопоставляется с любым значением, не связывая его с именем:

```haskell
isZero :: Int -> Bool
isZero 0 = True
isZero _ = False   -- _ означает «всё остальное»
```

Удобно, когда значение аргумента не нужно в правой части.

### Образцы конструкторов

Разбирают значения алгебраических типов данных:

```haskell
fromMaybe :: a -> Maybe a -> a
fromMaybe def Nothing  = def
fromMaybe _   (Just x) = x
```

### Именованные образцы (`@`)

Связывают значение целиком, одновременно разбирая его:

```haskell
showPoint :: Point -> String
showPoint p@(Point x y) = show p <> " = (" <> show x <> ", " <> show y <> ")"
```

Здесь `p` привязана ко всему `Point`, а `x` и `y` — к его компонентам.

### Образцы списков

Списки можно сопоставлять по структуре:

```haskell
isEmpty :: [a] -> Bool
isEmpty []    = True
isEmpty (_:_) = False

head' :: [a] -> Maybe a
head' []    = Nothing
head' (x:_) = Just x
```

Образец `(x:xs)` разбивает список на голову `x` и хвост `xs`.

## Охранные выражения (Guards)

Guards позволяют добавить условия к альтернативам:

```haskell
signum' :: Int -> Int
signum' n
  | n > 0     = 1
  | n == 0    = 0
  | otherwise = -1
```

Guard записывается после образцов через `|`. Проверяются сверху вниз. `otherwise` — это просто `True`, определённый в `Prelude`; он используется как «случай по умолчанию».

```text
> :type otherwise
otherwise :: Bool

> otherwise
True
```

Guards можно комбинировать с образцами:

```haskell
gcd :: Int -> Int -> Int
gcd n 0 = n
gcd 0 m = m
gcd n m
  | n > m     = gcd (n - m) m
  | otherwise = gcd n (m - n)
```

## Выражение `case`

Pattern matching можно использовать не только в определениях функций, но и в выражениях `case`:

```haskell
describe :: [a] -> String
describe xs = case xs of
  []     -> "пустой"
  [_]    -> "один элемент"
  [_,_]  -> "два элемента"
  _      -> "много элементов"
```

Конструкция `case expr of` проверяет `expr` по набору образцов. Это полезно, когда паттерн-матчинг нужен в середине вычисления, а не только в аргументах функции.

### `let` и `where`

Вспомогательные определения можно вводить двумя способами:

**`where`** — определения после основного тела:

```haskell
circleArea :: Double -> Double
circleArea r = pi * r2
  where
    r2 = r * r
```

**`let ... in`** — определения перед выражением:

```haskell
circleArea :: Double -> Double
circleArea r =
  let r2 = r * r
  in  pi * r2
```

Оба варианта эквивалентны. `where` чаще встречается в определениях функций, `let` — внутри выражений.

## Алгебраические типы данных

**Алгебраические типы данных** (АТД) — это типы с несколькими конструкторами. Каждый конструктор может нести произвольные данные.

### Тип-сумма

Значение может быть одним из нескольких вариантов:

```haskell
data Shape
  = Circle Point Double           -- центр, радиус
  | Rectangle Point Double Double -- угол, ширина, высота
  | Line Point Point              -- начало, конец
  | Text Point String             -- позиция, текст
  deriving (Show, Eq)
```

`Shape` — **тип-сумма**: значение `Shape` — это *или* `Circle`, *или* `Rectangle`, *или* `Line`, *или* `Text`. Конструкторы разделяются символом `|`.

### Тип-произведение

Каждый конструктор — это **тип-произведение**: он объединяет несколько значений. `Circle Point Double` содержит *и* точку, *и* число.

### Рекурсивные типы

АТД могут ссылаться на себя:

```haskell
data List a = Nil | Cons a (List a)
```

Встроенные списки `[a]` — это именно такой тип: `[]` аналогично `Nil`, а `(:)` аналогично `Cons`.

### Тип `Point`

Для нашего проекта определим точку без записей — с позиционными аргументами:

```haskell
data Point = Point Double Double
  deriving (Show, Eq)

origin :: Point
origin = Point 0.0 0.0
```

Это делает паттерн-матчинг наглядным:

```text
> let p = Point 3.0 4.0
> case p of Point x y -> x + y
7.0
```

## Использование АТД

Единственный способ «заглянуть» внутрь АТД — сопоставление с образцом. Напишем функцию `showShape`:

```haskell
showShape :: Shape -> String
showShape (Circle c r)      = "Circle [center: " <> showPoint c <> ", radius: " <> show r <> "]"
showShape (Rectangle p w h) = "Rectangle [" <> showPoint p <> ", " <> show w <> " × " <> show h <> "]"
showShape (Line start end)  = "Line [" <> showPoint start <> " → " <> showPoint end <> "]"
showShape (Text p s)        = "Text [" <> showPoint p <> ": " <> show s <> "]"
```

Каждый конструктор `Shape` обрабатывается своей альтернативой. Компилятор GHC предупредит (с флагом `-Wall`), если вы забудете обработать какой-либо конструктор — это **проверка полноты** (exhaustiveness checking).

## Неполное сопоставление и тотальные функции

Функция называется **тотальной**, если она возвращает результат для любого входа, и **частичной**, если может упасть. Например, `head :: [a] -> a` — частичная (падает на пустом списке).

GHC предупреждает о неполном сопоставлении:

```text
Pattern match(es) are non-exhaustive
In an equation for 'showShape':
    Patterns not matched: Text _ _
```

Хорошая практика — всегда определять тотальные функции. Если результат может отсутствовать, используйте `Maybe`:

```haskell
head' :: [a] -> Maybe a
head' []    = Nothing
head' (x:_) = Just x
```

## `newtype`

`newtype` создаёт новый тип с одним конструктором и одним полем. В отличие от `data`, `newtype` не несёт рантайм-накладных расходов — значение хранится так же, как базовый тип:

```haskell
newtype Volt = Volt Double
newtype Amp  = Amp Double
newtype Ohm  = Ohm Double

calculateCurrent :: Volt -> Ohm -> Amp
calculateCurrent (Volt v) (Ohm r) = Amp (v / r)
```

Система типов не позволит случайно перепутать вольты и омы:

```haskell
battery :: Volt
battery = Volt 1.5

resistor :: Ohm
resistor = Ohm 500.0

-- calculateCurrent resistor battery  -- ошибка компиляции!
-- ожидается Volt, получено Ohm
```

`newtype` — мощный инструмент для повышения типобезопасности без рантайм-расходов.

## Ограничивающий прямоугольник

В модуле `Data.Picture` определена функция `bounds`, которая вычисляет минимальный ограничивающий прямоугольник для картинки. Она использует все изученные приёмы:

```haskell
data Bounds = Bounds
  { minX :: Double, minY :: Double
  , maxX :: Double, maxY :: Double
  } deriving (Show, Eq)

shapeBounds :: Shape -> Bounds
shapeBounds (Circle (Point cx cy) r) = Bounds
  { minX = cx - r, minY = cy - r
  , maxX = cx + r, maxY = cy + r }
shapeBounds (Rectangle (Point x y) w h) = Bounds
  { minX = x, minY = y
  , maxX = x + w, maxY = y + h }
shapeBounds (Line (Point x1 y1) (Point x2 y2)) = Bounds
  { minX = min x1 x2, minY = min y1 y2
  , maxX = max x1 x2, maxY = max y1 y2 }
shapeBounds (Text (Point x y) _) = Bounds
  { minX = x, minY = y, maxX = x, maxY = y }
```

Обратите внимание на **вложенные образцы**: `Circle (Point cx cy) r` разбирает и `Circle`, и вложенный `Point` за одно сопоставление.

Функция `bounds` использует свёртку (о ней подробно — в следующей главе) для объединения границ всех фигур:

```haskell
bounds :: Picture -> Bounds
bounds = foldl combine emptyBounds
  where
    combine acc shape = unionBounds acc (shapeBounds shape)
```

Проверим в GHCi:

```text
> import Data.Picture
> let pic = [Circle origin 1, Rectangle (Point 2 2) 3 3]
> bounds pic
Bounds {minX = -1.0, minY = -1.0, maxX = 5.0, maxY = 5.0}
```

## `LambdaCase`

Расширение `LambdaCase` (включённое в нашем проекте) позволяет записывать анонимные функции с паттерн-матчингом:

```haskell
describe :: Maybe Int -> String
describe = \case
  Nothing -> "пусто"
  Just n  -> "значение: " <> show n
```

Это сокращение для `\x -> case x of ...`. Удобно при передаче функций в `map`, `filter` и другие функции высшего порядка:

```haskell
> map (\case { Nothing -> 0; Just n -> n }) [Just 1, Nothing, Just 3]
[1, 0, 3]
```

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

1. **(Среднее)** Реализуйте функцию `area`, которая вычисляет площадь фигуры. Площадь линии и текста считается нулевой.

    ```haskell
    area :: Shape -> Double
    ```

    *Подсказка:* используйте сопоставление с образцом по каждому конструктору `Shape`. Площадь круга: \\(\pi r^2\\). Площадь прямоугольника: \\(w \times h\\). Константа `pi` доступна из `Prelude`.

2. **(Среднее)** Реализуйте функцию `scale`, которая масштабирует фигуру на заданный коэффициент. Координаты и размеры умножаются на коэффициент, текст не масштабируется (только его позиция).

    ```haskell
    scale :: Double -> Shape -> Shape
    ```

    *Подсказка:* для каждого конструктора создайте новое значение того же конструктора с умножёнными координатами. Используйте вложенные образцы для `Point`.

3. **(Среднее)** Реализуйте функцию `shapeText`, которая извлекает текст из фигуры `Text`. Для остальных фигур верните `Nothing`.

    ```haskell
    shapeText :: Shape -> Maybe String
    ```

    *Подсказка:* один образец для `Text`, один wildcard для всего остального.

## Заключение

В этой главе мы:

- Познакомились с алгебраическими типами данных: суммами, произведениями и рекурсивными типами.
- Освоили сопоставление с образцом: литералы, переменные, wildcards, конструкторы, вложенные и именованные образцы.
- Разобрали guards, `case`, `let` и `where`.
- Узнали о `newtype` и его использовании для типобезопасности.
- Создали библиотеку геометрических фигур с вычислением ограничивающего прямоугольника.

АТД и паттерн-матчинг — одни из самых мощных и часто используемых инструментов в Haskell. В оставшейся части книги мы будем активно их применять.
