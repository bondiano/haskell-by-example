# Ленивость, строгость и производительность

В предыдущих главах мы построили CLI-трекер задач с IO, обработкой ошибок, `Map`, `Set` и `Text`. Мы уже встречали подсказки вроде «используйте `foldl'` вместо `foldl`» и «подробнее в главе 9». Пришло время разобраться, **почему** Haskell ведёт себя именно так.

Ленивость — одна из самых необычных и мощных особенностей Haskell. Она же — источник самых коварных ошибок для новичков. В этой главе мы разберём модель вычислений (санки, WHNF), увидим преимущества ленивости на примере бесконечных структур данных, столкнёмся с утечками памяти (`foldl` vs `foldl'`) и научимся их устранять с помощью `seq`, `BangPatterns` и строгих полей. Попутно сравним `String` и `Text` с точки зрения производительности и познакомимся с базовым профилированием.

К концу главы мы оптимизируем тип `TaskStats` из [главы 4](chapter04.md), добавив строгие поля, и увидим разницу на практике.

## Как Haskell вычисляет выражения

### Ленивая стратегия вычислений

Большинство языков используют **энергичную** (eager) стратегию: аргументы функции вычисляются *до* вызова. Haskell по умолчанию использует **ленивую** (lazy) стратегию: выражение вычисляется только тогда, когда его значение *действительно нужно*.

```haskell
expensive :: Int -> Int
expensive n = sum [1..n]

cheap :: Int -> Int -> Int
cheap x _ = x  -- второй аргумент не используется
```

```text
> cheap 42 (expensive 1_000_000_000)
42   -- мгновенно! expensive никогда не вычислялся
```

В Python или TypeScript `expensive(1_000_000_000)` вычислился бы до вызова `cheap`. В Haskell второй аргумент не нужен — значит, он не вычисляется.

```admonish tip title="Знакомый аналог"
**Python:** генераторы (`yield`) — ленивое вычисление элементов последовательности.
**JavaScript:** генераторы (`function*`) работают аналогично.
Разница: в Haskell ленивость — стратегия **по умолчанию** для *всех* выражений, а не специальный механизм для последовательностей.
```

### Санки (thunks)

Когда Haskell встречает выражение, он не вычисляет его сразу, а создаёт **санк** (thunk) — «обещание вычислить позже». Санк — замыкание: указатель на код плюс ссылки на нужные переменные.

```text
let x = 1 + 2          -- x = <thunk: 1 + 2>
```

После этой строки `x` — не число `3`, а санк. Когда значение `x` понадобится (например, для вывода на экран), санк **форсируется**: вычисление выполняется, результат `3` записывается на место санка. При повторном обращении вычисление не повторяется.

### WHNF и NF

Haskell различает две степени «вычисленности»:

**Weak Head Normal Form (WHNF)** — выражение вычислено до внешнего конструктора или лямбды. Внутренние части могут оставаться санками:

```text
Just <thunk>         -- WHNF (конструктор Just виден)
1 : <thunk>          -- WHNF (конструктор (:) виден)
1 + 2                -- НЕ в WHNF, это санк
Just (1 + 2)         -- в WHNF! конструктор виден, аргумент — санк
```

**Normal Form (NF)** — выражение полностью вычислено, санков внутри нет: `Just 42`, `[1, 2, 3]`.

Это критически важно: `seq`, `case` и паттерн-матчинг форсируют значение только до WHNF, а не до NF.

### Паттерн-матчинг форсирует вычисление

Главный способ форсирования санков — **паттерн-матчинг**:

```haskell
isJust :: Maybe a -> Bool
isJust Nothing  = False
isJust (Just _) = True
```

```text
> isJust (Just (error "boom"))
True            -- ошибка не возникла! Проверяется только конструктор

> isJust (error "boom")
*** Exception: boom   -- здесь форсируется сам аргумент
```

Паттерн-матчинг проверяет конструктор `Just`, не заглядывая внутрь. `error "boom"` остаётся невычисленным санком.

## Преимущества ленивости

### Бесконечные структуры данных

Ленивость позволяет работать с бесконечными списками — вычисляются только запрошенные элементы:

```haskell
nats :: [Integer]
nats = [1..]           -- бесконечный список натуральных чисел

ones :: [Int]
ones = repeat 1        -- [1, 1, 1, ...]

abcs :: [String]
abcs = cycle ["a", "b", "c"]  -- ["a","b","c","a","b","c",...]
```

Классический пример — числа Фибоначчи:

```haskell
fibs :: [Integer]
fibs = 0 : 1 : zipWith (+) fibs (tail fibs)
```

```text
> take 10 fibs
[0,1,1,2,3,5,8,13,21,34]

> fibs !! 100
354224848179261915075
```

### Разделение генерации и потребления

Генератор не знает, сколько элементов нужно потребителю:

```haskell
primes :: [Integer]
primes = sieve [2..]
  where
    sieve (p : xs) = p : sieve [x | x <- xs, x `mod` p /= 0]

-- take 10 primes         → [2,3,5,7,11,13,17,19,23,29]
-- takeWhile (< 50) primes → [2,3,5,7,11,13,17,19,23,29,31,37,41,43,47]
```

Это работает и для нашего трекера: `listToMaybe (filter (\t -> taskPriority t == High) tasks)` остановится на первой задаче с высоким приоритетом, не обрабатывая весь список.

## Проблема: утечки памяти (space leaks)

### Классический пример: `foldl` vs `foldl'`

Ленивость — палка о двух концах. Рассмотрим суммирование:

```haskell
import Data.List (foldl')

badSum :: [Int] -> Int
badSum = foldl (+) 0       -- ПЛОХО: ленивая свёртка

goodSum :: [Int] -> Int
goodSum = foldl' (+) 0     -- ХОРОШО: строгая свёртка
```

Что происходит при `badSum [1, 2, 3, 4]`?

```text
foldl (+) 0 [1, 2, 3, 4]
= foldl (+) (0 + 1) [2, 3, 4]              -- не вычисляем!
= foldl (+) ((0 + 1) + 2) [3, 4]           -- копим санки
= foldl (+) (((0 + 1) + 2) + 3) [4]
= foldl (+) ((((0 + 1) + 2) + 3) + 4) []   -- огромная цепочка
= (((0 + 1) + 2) + 3) + 4                  -- только теперь вычисляем
= 10
```

Для миллиона элементов — миллион вложенных санков. Это **утечка памяти** (space leak): O(n) памяти вместо O(1).

А `foldl'` вычисляет аккумулятор на каждом шаге:

```text
foldl' (+) 0 [1, 2, 3, 4]
= foldl' (+) 1 [2, 3, 4]       -- вычислили: 1
= foldl' (+) 3 [3, 4]          -- вычислили: 3
= foldl' (+) 6 [4]             -- вычислили: 6
= foldl' (+) 10 []             -- вычислили: 10
= 10
```

```text
> foldl (+) 0 [1..10_000_000]
*** Exception: stack overflow

> foldl' (+) 0 [1..10_000_000]
50000005000000   -- константная память
```

```admonish warning title="Важно"
`foldl` — это **почти никогда** не то, что вам нужно. Используйте `foldl'` из `Data.List` для строгих аккумуляторов (числа, счётчики, `Map`) и `foldr` для ленивых результатов (списки, конкатенация). Если вы пишете `foldl` — остановитесь и подумайте, не нужен ли `foldl'`.
```

### Утечки в структурах данных

Утечки бывают не только с `foldl`. Даже с `foldl'` поля структуры могут оставаться санками:

```haskell
-- Утечка: foldl' форсирует до конструктора, но не поля!
leakyStats :: [Task] -> TaskStats
leakyStats = foldl' step (TaskStats 0 0 0 0)
  where
    step acc task = TaskStats
      { totalTasks   = totalTasks acc + 1      -- санк!
      , todoCount    = todoCount acc + delta    -- санк!
      , doneCount    = doneCount acc + delta'   -- санк!
      , highPriority = highPriority acc + delta''-- санк!
      }
      where
        delta   = if taskStatus task == Todo then 1 else 0
        delta'  = if taskStatus task == Done then 1 else 0
        delta'' = if taskPriority task == High then 1 else 0
```

`foldl'` форсирует аккумулятор до WHNF — до конструктора `TaskStats`. Но *поля* внутри остаются санками. Решение — **строгие поля**.

## Контроль строгости

### `seq` — примитив форсирования

```haskell
seq :: a -> b -> b
```

`seq a b` вычисляет `a` до WHNF, затем возвращает `b`:

```haskell
strictPair :: a -> b -> (a, b)
strictPair x y = x `seq` y `seq` (x, y)
```

```text
> fst (strictPair (error "x") 42)
*** Exception: x    -- x форсирован, хотя fst его не использует
```

### `$!` — строгое применение

```haskell
($!) :: (a -> b) -> a -> b
f $! x = x `seq` f x   -- вычисляет x до WHNF, затем применяет f
```

### BangPatterns — восклицательные паттерны

Расширение `BangPatterns` помечает аргумент для форсирования при входе в функцию:

```haskell
{-# LANGUAGE BangPatterns #-}

myFoldl' :: (b -> a -> b) -> b -> [a] -> b
myFoldl' _ !acc []     = acc
myFoldl' f !acc (x:xs) = myFoldl' f (f acc x) xs
```

`!acc` эквивалентно ``acc `seq` ...`` — значение форсируется до WHNF перед входом в уравнение.

### Строгие поля в типах данных

Самый надёжный способ избежать утечек — **строгие поля**. `!` перед типом поля означает: «форсировать при создании значения»:

```haskell
data TaskStats = TaskStats
  { totalTasks   :: !Int
  , todoCount    :: !Int
  , doneCount    :: !Int
  , highPriority :: !Int
  } deriving (Show, Eq)
```

Теперь при каждом создании `TaskStats` все поля форсируются. Вместе с `foldl'` это гарантирует отсутствие накопленных санков:

```haskell
computeStats :: [Task] -> TaskStats
computeStats = foldl' step (TaskStats 0 0 0 0)
  where
    step acc task = TaskStats
      { totalTasks   = totalTasks acc + 1
      , todoCount    = todoCount acc + if taskStatus task == Todo then 1 else 0
      , doneCount    = doneCount acc + if taskStatus task == Done then 1 else 0
      , highPriority = highPriority acc + if taskPriority task == High then 1 else 0
      }
```

```admonish note title="Лучшая практика"
Помечайте поля как строгие (`!`), если они содержат «маленькие» значения: числа, булевы, перечисления. Это предотвращает утечки и почти никогда не вредит. Ленивые поля оставляйте для «больших» значений (списки, деревья), которые вычислять заранее расточительно.
```

### `Data.Map.Strict` vs `Data.Map.Lazy`

Существуют две версии `Map`:

```haskell
import Data.Map.Lazy   as Map  -- значения лениво (по умолчанию)
import Data.Map.Strict as Map  -- значения форсируются при вставке
```

`Data.Map.Strict` форсирует *значения* до WHNF при каждой вставке. Для накопления числовых значений это предотвращает утечки:

```haskell
import Data.Map.Strict qualified as Map

countByStatus :: [Task] -> Map.Map Status Int
countByStatus = foldl' (\m t -> Map.insertWith (+) (taskStatus t) 1 m) Map.empty
```

## Text vs String: производительность

### Почему `String` медленный

```haskell
type String = [Char]   -- связный список символов!
```

Каждый символ — отдельный узел в куче (~24 байта на символ вместо 1-4 в UTF-8). Доступ к n-му символу — O(n). Узлы разбросаны по памяти, кэш CPU неэффективен.

```admonish danger title="Не используйте String в продакшене"
`String` подходит для обучения и прототипов. В реальном коде **всегда** используйте `Text` для текста и `ByteString` для бинарных данных. Разница в производительности — 10-100x.
```

### `Text` и `ByteString`

`Data.Text` хранит текст как компактный массив UTF-8 (начиная с `text-2.0`). Операции конкатенации, поиска и разбиения работают значительно быстрее:

```haskell
{-# LANGUAGE OverloadedStrings #-}
import Data.Text (Text)
import Data.Text qualified as T

greeting :: Text
greeting = "Привет, мир!"     -- OverloadedStrings: литерал → Text

fullName :: Text -> Text -> Text
fullName first last = first <> " " <> last
```

`Data.ByteString` — массив байтов без интерпретации как текст. Используйте для файлов, сети, бинарных форматов.

| Тип | Когда использовать |
|-----|-------------------|
| `Text` | Человекочитаемый текст: имена, описания, UI |
| `ByteString` | Бинарные данные: файлы, сеть, криптография |
| `String` | Только в учебном коде и прототипах |

## Профилирование

### Зачем профилировать

Ленивость делает предсказание производительности *сложным*. Интуиция из императивных языков часто не работает. Единственный надёжный способ — **профилирование**.

### Компиляция и запуск

```text
$ stack build --profile
$ stack exec -- my-program +RTS -s    # статистика выполнения
$ stack exec -- my-program +RTS -p    # детальный профиль по функциям
```

Флаг `-s` показывает ключевые метрики:

```text
   1,200,048 bytes allocated in the heap
      44,504 bytes maximum residency (1 sample(s))
```

- **maximum residency** — пиковое потребление «живой» памяти. Растёт пропорционально входу? У вас утечка.
- **bytes allocated** — общий объём выделений. Много — часто из-за санков.

Флаг `-p` создаёт файл `.prof` с разбивкой по функциям.

### Пример: `foldl` vs `foldl'`

```haskell
module Main where
import Data.List (foldl')

badSum, goodSum :: [Int] -> Int
badSum  = foldl  (+) 0
goodSum = foldl' (+) 0

main :: IO ()
main = print (goodSum [1..10_000_000])  -- замените на badSum для сравнения
```

```text
-- badSum:   maximum residency ~400 MB (цепочка санков)
-- goodSum:  maximum residency ~44 KB  (константная память)
```

Разница — **в 10 000 раз**. Это утечка памяти в действии.

## Проект: оптимизация `TaskStats`

Вспомним тип из [главы 4](chapter04.md):

```haskell
-- Было: ленивые поля → утечка при свёртке большого списка
data TaskStats = TaskStats
  { totalTasks :: Int, todoCount :: Int, doneCount :: Int, highPriority :: Int }

-- Стало: строгие поля → безопасно
data TaskStats = TaskStats
  { totalTasks :: !Int, todoCount :: !Int, doneCount :: !Int, highPriority :: !Int }
```

Одно изменение — `!` перед `Int` — и утечка исчезает. `foldl'` форсирует `TaskStats` до WHNF (конструктор), а строгие поля форсируют числа до NF.

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

### Проект ★☆☆

1. Определите тип `TaskStats` со строгими полями и реализуйте `computeStatsStrict`, считающую статистику за один проход с `foldl'`:

    ```haskell
    data TaskStats = TaskStats
      { totalTasks :: !Int, todoCount :: !Int
      , doneCount :: !Int, highPriority :: !Int
      } deriving (Show, Eq)

    computeStatsStrict :: [Task] -> TaskStats
    ```

2. Реализуйте `badSum` через `foldl` и `goodSum` через `foldl'`. Попробуйте в GHCi вызвать обе с `[1..1_000_000]` и сравните поведение:

    ```haskell
    badSum :: [Int] -> Int
    goodSum :: [Int] -> Int
    ```

### Практика ★☆☆

3. Реализуйте бесконечные списки `ones` (бесконечный список единиц) и `nats` (натуральные числа от 1):

    ```haskell
    ones :: [Int]
    nats :: [Integer]
    ```

    Проверка: `take 5 ones == [1,1,1,1,1]`, `take 5 nats == [1,2,3,4,5]`.

4. Реализуйте `fibs` — бесконечный список чисел Фибоначчи:

    ```haskell
    fibs :: [Integer]
    -- take 8 fibs == [0,1,1,2,3,5,8,13]
    ```

    *Подсказка:* `fibs = 0 : 1 : zipWith ...`

### Практика ★★☆

5. Предскажите результат каждого выражения, затем проверьте в GHCi:

    ```haskell
    -- a) fst (1, error "boom")
    -- b) snd (error "boom", 2)
    -- c) length [error "a", error "b", error "c"]
    -- d) head (1 : error "tail")
    -- e) seq (Just (error "inner")) "ok"
    ```

    Реализуйте функцию `predictions`:

    ```haskell
    predictions :: [String]
    -- ["1", "error", "3", "1", "ok"]
    ```

6. Исправьте утечку памяти. Функция суммирует длины строк:

    ```haskell
    -- Версия с утечкой:
    -- totalLength = foldl (\acc s -> acc + length s) 0

    totalLengthStrict :: [String] -> Int
    ```

    *Подсказка:* замените `foldl` на `foldl'` из `Data.List`.

### Практика ★★★

7. Реализуйте `strictMap` — аналог `map`, форсирующий каждый элемент результата до WHNF:

    ```haskell
    strictMap :: (a -> b) -> [a] -> [b]
    ```

    ```text
    > head (strictMap (\x -> error "boom") [1, 2, 3])
    *** Exception: boom
    -- Обычный map: head (map (\x -> error "boom") [1,2,3]) тоже упадёт,
    -- но strictMap форсирует элемент ДО помещения в список
    ```

    *Подсказка:* ``let y = f x in y `seq` (y : strictMap f xs)``.

## Шпаргалка по строгости

| Инструмент | Что делает | Когда использовать |
|------------|-----------|-------------------|
| `seq a b` | Форсирует `a` до WHNF, возвращает `b` | Точечное управление |
| `f $! x` | `seq x (f x)` — строгое применение | Форсировать аргумент |
| `!x` (BangPatterns) | Форсировать при входе в функцию | Строгие аккумуляторы |
| `!Int` (строгое поле) | Форсировать при создании значения | Числовые поля в `data` |
| `foldl'` | Строгая левая свёртка | Строгий результат (число, Map) |
| `Data.Map.Strict` | Форсирует значения при вставке | Карты с числовыми значениями |

## Заключение

Ленивая стратегия вычислений, санки, WHNF — всё это не абстрактная теория, а рабочие инструменты, определяющие поведение каждой Haskell-программы. Бесконечные списки и разделение генерации от потребления — сильные стороны ленивости. Утечки памяти через `foldl` и цепочки санков — её слабые стороны. Инструменты строгости (`seq`, `$!`, `BangPatterns`, строгие поля, `Data.Map.Strict`) позволяют точечно управлять вычислениями там, где ленивость вредит.

Правило большого пальца: **структуры данных — строгие, вычисления — ленивые**.

В [следующей главе](chapter10.md) мы перейдём к тестированию: hspec для юнит-тестов и QuickCheck для property-based testing.

```admonish tip title="Для углубления"
- **Haskell MOOC** — [haskell.mooc.fi](https://haskell.mooc.fi/), лекция 10: ленивость. Подробнейший разбор с визуализациями вычислений и практическими упражнениями.
- **Real World Haskell** — глава 25: Profiling and optimization.
- **Вики Haskell** — [Memory leak](https://wiki.haskell.org/Memory_leak) — каталог типичных утечек и решений.
```
