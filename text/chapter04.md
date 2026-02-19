# Списки, рекурсия и свёртки

В [главе 3](chapter03.md) мы описали фильтры для задач с помощью алгебраических типов и паттерн-матчинга. Теперь пора освоить главные инструменты работы со списками: рекурсию, `map`, `filter`, свёртки `foldr` и `foldl'`, а также практические функции вроде `zip`, `take`, `drop`, `span` и `break`. К концу главы мы реализуем сбор статистики по списку задач, сортировку по приоритету и группировку по статусу.

## Подготовка проекта

Код этой главы находится в `exercises/chapter04`. Соберите проект:

```text
$ cd exercises/chapter04
$ stack build
```

## Рекурсия

В императивных языках повторение реализуется через циклы `for` и `while`. В Haskell циклов нет — вместо них **рекурсия**: функция вызывает саму себя.

### Факториал

```haskell
factorial :: Int -> Int
factorial 0 = 1                    -- базовый случай
factorial n = n * factorial (n - 1) -- рекурсивный случай
```

Каждая рекурсивная функция состоит из двух частей:

1. **Базовый случай** — условие остановки (здесь `n == 0`).
2. **Рекурсивный случай** — вызов самой себя с «уменьшённым» аргументом.

```text
> factorial 5
120

> -- Развернём: 5 * 4 * 3 * 2 * 1 * factorial 0 = 5 * 4 * 3 * 2 * 1 * 1 = 120
```

```admonish tip title="Знакомый аналог"
**Python:** рекурсия работает так же, но ограничена глубиной стека (`RecursionError`).
**JavaScript:** аналогично, но без оптимизации хвостовой рекурсии в большинстве движков.
В Haskell рекурсия — основной механизм итерации, и компилятор умеет оптимизировать хвостовые вызовы.
```

### Числа Фибоначчи

```haskell
fib :: Int -> Int
fib 0 = 0
fib 1 = 1
fib n = fib (n - 1) + fib (n - 2)
```

```text
> map fib [0..10]
[0,1,1,2,3,5,8,13,21,34,55]
```

Эта реализация экспоненциально медленная (каждый вызов порождает два), но для понимания рекурсии она идеальна.

## Рекурсия на списках

Списки в Haskell — рекурсивная структура: список либо пуст (`[]`), либо состоит из головы и хвоста (`x : xs`). Это делает рекурсию на списках естественной.

### Длина списка

```haskell
length' :: [a] -> Int
length' []       = 0              -- пустой список: длина 0
length' (_ : xs) = 1 + length' xs -- голова + рекурсия по хвосту
```

Символ `_` означает «значение нам не важно» — мы не используем голову, только считаем элементы.

### Разворот списка

```haskell
reverse' :: [a] -> [a]
reverse' []       = []
reverse' (x : xs) = reverse' xs ++ [x]
```

Оператор `++` конкатенирует два списка. Эта реализация работает за O(n^2). Позже мы увидим, как свёртка решает проблему за O(n).

### Сумма элементов

```haskell
sum' :: Num a => [a] -> a
sum' []       = 0
sum' (x : xs) = x + sum' xs
```

Паттерн повторяется: базовый случай для `[]`, рекурсивный случай для `x : xs`. Именно этот паттерн обобщают свёртки.

## `map` — преобразование списка

Функция `map` применяет функцию к каждому элементу:

```haskell
map :: (a -> b) -> [a] -> [b]
map _ []       = []
map f (x : xs) = f x : map f xs
```

```text
> map (* 2) [1, 2, 3]
[2, 4, 6]

> map taskTitle tasks
["Изучить Haskell","Купить молоко","Написать тесты"]
```

`map` сохраняет структуру списка — длина результата всегда равна длине исходного.

```admonish tip title="Знакомый аналог"
**JavaScript:** `[1, 2, 3].map(x => x * 2)`.
**Python:** `[x * 2 for x in [1, 2, 3]]`.
В Haskell `map` — обычная функция, а не метод.
```

## `filter` — отбор элементов

Функция `filter` оставляет только элементы, удовлетворяющие предикату:

```haskell
filter :: (a -> Bool) -> [a] -> [a]
filter _ []       = []
filter p (x : xs)
  | p x       = x : filter p xs
  | otherwise  = filter p xs
```

```text
> filter even [1..10]
[2,4,6,8,10]

> filter (\t -> taskPriority t == High) tasks
[Task {taskTitle = "Изучить Haskell", ...}]
```

Комбинация `map` и `filter` покрывает огромную долю задач обработки списков:

```haskell
-- Заголовки всех выполненных задач
doneTitles :: TaskList -> [String]
doneTitles = map taskTitle . filter (\t -> taskStatus t == Done)
```

## `foldr` — правая свёртка

`map` и `filter` — частные случаи более общей операции: **свёртки** (fold). Свёртка «сворачивает» список в одно значение, последовательно применяя функцию.

```haskell
foldr :: (a -> b -> b) -> b -> [a] -> b
foldr _ acc []       = acc
foldr f acc (x : xs) = f x (foldr f acc xs)
```

Три аргумента: `f` — функция (элемент, накопитель -> результат), `acc` — начальное значение, и список.

### Как работает `foldr`

`foldr` заменяет каждый `:` на `f`, а `[]` на `acc`:

```text
foldr f acc (1 : 2 : 3 : [])
= f 1 (f 2 (f 3 acc))
```

Вычисление идёт **справа налево** — отсюда название `foldr` (fold right).

### Примеры через `foldr`

```haskell
sum'' :: Num a => [a] -> a
sum'' = foldr (+) 0          -- заменяем (:) на (+), [] на 0

product' :: Num a => [a] -> a
product' = foldr (*) 1       -- заменяем (:) на (*), [] на 1

concat' :: [[a]] -> [a]
concat' = foldr (++) []      -- заменяем (:) на (++), [] на []
```

### `map` и `filter` через `foldr`

Любую рекурсию по списку можно выразить через `foldr`:

```haskell
map' :: (a -> b) -> [a] -> [b]
map' f = foldr (\x acc -> f x : acc) []

filter' :: (a -> Bool) -> [a] -> [a]
filter' p = foldr (\x acc -> if p x then x : acc else acc) []
```

## `foldl'` — строгая левая свёртка

**Левая** свёртка обрабатывает список слева направо:

```haskell
foldl' :: (b -> a -> b) -> b -> [a] -> b
foldl' _ acc []       = acc
foldl' f acc (x : xs) = let acc' = f acc x
                         in acc' `seq` foldl' f acc' xs
```

```text
foldl' f acc [1, 2, 3]
= foldl' f (f acc 1) [2, 3]
= foldl' f (f (f acc 1) 2) [3]
= f (f (f acc 1) 2) 3
```

Аргументы `f` в `foldl'` идут в другом порядке: сначала аккумулятор, потом элемент.

````admonish warning title="foldl vs foldl'"
В Haskell существует также `foldl` (без апострофа) — **ленивая** левая свёртка. Она накапливает цепочку отложенных вычислений и может вызвать переполнение стека на длинных списках:

```text
foldl (+) 0 [1..1_000_000]  -- может упасть с переполнением стека!
foldl' (+) 0 [1..1_000_000] -- работает в константной памяти
```

**Правило:** всегда используйте `foldl'` из `Data.List` вместо `foldl`. Подробнее о ленивости и строгости — в [главе 9](chapter09.md).

```haskell
import Data.List (foldl')
```
````

### Когда `foldr`, когда `foldl'`?

- **`foldr`** — когда результат строится «лениво» (списки, строки) или операция может завершиться досрочно.
- **`foldl'`** — когда результат — одно строгое значение (число, запись-аккумулятор).

```haskell
-- foldl': эффективный разворот списка за O(n)
reverse'' :: [a] -> [a]
reverse'' = foldl' (flip (:)) []

-- foldl': вычисляем число
length'' :: [a] -> Int
length'' = foldl' (\acc _ -> acc + 1) 0
```

## Практические функции для списков

### `zip` и `zipWith`

`zip` объединяет два списка в список пар. `zipWith` обобщает `zip`, применяя функцию:

```text
> zip [1, 2, 3] ["a", "b", "c"]
[(1,"a"),(2,"b"),(3,"c")]

> zipWith (+) [1, 2, 3] [10, 20, 30]
[11,22,33]

> zipWith (\i t -> show i <> ". " <> taskTitle t) [1..] tasks
["1. Изучить Haskell","2. Купить молоко","3. Написать тесты"]
```

Обратите внимание: `[1..]` — бесконечный список. Благодаря ленивости Haskell вычислит ровно столько элементов, сколько нужно.

### `take`, `drop`, `span`, `break`

```text
> take 3 [1..10]
[1,2,3]

> drop 3 [1..10]
[4,5,6,7,8,9,10]

> span (< 4) [1, 2, 3, 5, 1, 2]
([1,2,3],[5,1,2])

> break (>= 4) [1, 2, 3, 5, 1, 2]  -- эквивалентно span (< 4)
([1,2,3],[5,1,2])
```

### Шпаргалка

| Функция | Тип | Описание |
|---------|-----|----------|
| `map` | `(a -> b) -> [a] -> [b]` | Преобразование элементов |
| `filter` | `(a -> Bool) -> [a] -> [a]` | Отбор по предикату |
| `foldr` | `(a -> b -> b) -> b -> [a] -> b` | Правая свёртка |
| `foldl'` | `(b -> a -> b) -> b -> [a] -> b` | Строгая левая свёртка |
| `zip` | `[a] -> [b] -> [(a, b)]` | Объединение в пары |
| `zipWith` | `(a -> b -> c) -> [a] -> [b] -> [c]` | Объединение с функцией |
| `take` / `drop` | `Int -> [a] -> [a]` | Первые n / без первых n |
| `span` / `break` | `(a -> Bool) -> [a] -> ([a], [a])` | Разбиение списка |
| `any` / `all` | `(a -> Bool) -> [a] -> Bool` | Есть ли / все ли |

## Проект: статистика и сортировка задач

Применим свёртки к нашему трекеру задач.

### Статистика в один проход

Определим тип для статистики:

```haskell
data TaskStats = TaskStats
  { totalTasks   :: Int
  , todoCount    :: Int
  , doneCount    :: Int
  , highPriority :: Int
  } deriving (Show, Eq)
```

Наивный подход — пройти список четыре раза:

```haskell
-- Неэффективно: четыре прохода по списку
computeStatsNaive :: TaskList -> TaskStats
computeStatsNaive ts = TaskStats
  { totalTasks   = length ts
  , todoCount    = length (filter (\t -> taskStatus t == Todo) ts)
  , doneCount    = length (filter (\t -> taskStatus t == Done) ts)
  , highPriority = length (filter (\t -> taskPriority t == High) ts)
  }
```

Лучше — собрать всё за **один проход** с помощью `foldl'`:

```haskell
import Data.List (foldl')

computeStats :: TaskList -> TaskStats
computeStats = foldl' step emptyStats
  where
    emptyStats = TaskStats 0 0 0 0

    step acc task = TaskStats
      { totalTasks   = totalTasks acc + 1
      , todoCount    = todoCount acc + if taskStatus task == Todo then 1 else 0
      , doneCount    = doneCount acc + if taskStatus task == Done then 1 else 0
      , highPriority = highPriority acc + if taskPriority task == High then 1 else 0
      }
```

```text
> let tasks = [Task "Haskell" "" High Todo, Task "Молоко" "" Low Done, Task "Тесты" "" High InProgress]
> computeStats tasks
TaskStats {totalTasks = 3, todoCount = 1, doneCount = 1, highPriority = 2}
```

Здесь `foldl'` вместо `foldr`, потому что мы вычисляем строгое значение (`TaskStats`), а не строим ленивую структуру.

### Сортировка вставками

Реализуем сортировку по приоритету с помощью `foldr` и вспомогательной рекурсивной функции:

```haskell
-- Вставка задачи в отсортированный список
insertByPriority :: Task -> TaskList -> TaskList
insertByPriority task [] = [task]
insertByPriority task (t : ts)
  | taskPriority task >= taskPriority t = task : t : ts
  | otherwise                           = t : insertByPriority task ts

-- Сортировка: от высокого приоритета к низкому
sortByPriority :: TaskList -> TaskList
sortByPriority = foldr insertByPriority []
```

`sortByPriority` — это `foldr`, где функцией свёртки выступает `insertByPriority`. Каждый элемент вставляется в нужное место уже отсортированного хвоста.

````admonish note title="О производительности"
Сортировка вставками работает за O(n^2). Для реальных проектов используйте `sortBy` из `Data.List`:

```haskell
import Data.List (sortBy)
import Data.Ord (comparing, Down(..))

sortByPriority' :: TaskList -> TaskList
sortByPriority' = sortBy (comparing (Down . taskPriority))
```

Наша реализация — учебная: она демонстрирует, как рекурсия и свёртки работают вместе.
````

### Группировка по статусу

Сгруппируем задачи по статусу:

```haskell
groupByStatus :: TaskList -> [(Status, [Task])]
groupByStatus tasks =
  [ (s, filter (\t -> taskStatus t == s) tasks)
  | s <- [Todo, InProgress, Done]
  ]
```

```text
> map (\(s, ts) -> (s, length ts)) (groupByStatus tasks)
[(Todo,1),(InProgress,1),(Done,1)]
```

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

### Проект ★☆☆

1. Реализуйте функцию `computeStats`, которая вычисляет `TaskStats` за один проход по списку задач. Используйте `foldl'`.

    ```haskell
    computeStats :: TaskList -> TaskStats
    ```

2. Реализуйте функцию `completionRate`, которая возвращает долю выполненных задач (от 0.0 до 1.0). Для пустого списка верните 0.0.

    ```haskell
    completionRate :: TaskList -> Double
    ```

    *Подсказка:* используйте `computeStats` и `fromIntegral` для преобразования `Int` в `Double`.

### Проект ★★☆

3. Реализуйте функцию `sortByPriority`, которая сортирует задачи от высокого приоритета к низкому. Используйте `foldr` и вспомогательную функцию `insertByPriority`.

    ```haskell
    sortByPriority :: TaskList -> TaskList
    ```

### Практика ★☆☆

4. Реализуйте функцию `myReverse`, которая разворачивает список. Используйте `foldl'`.

    ```haskell
    myReverse :: [a] -> [a]
    ```

    *Подсказка:* `foldl' (\acc x -> ...) [] xs`.

5. Реализуйте функцию `myMap`, которая работает как стандартный `map`, но определена через `foldr`.

    ```haskell
    myMap :: (a -> b) -> [a] -> [b]
    ```

### Практика ★★☆

6. Реализуйте функцию `frequencies`, которая подсчитывает, сколько раз каждый элемент встречается в списке. Результат — список пар `(элемент, количество)`.

    ```haskell
    frequencies :: Eq a => [a] -> [(a, Int)]
    ```

    ```text
    > frequencies [1, 2, 1, 3, 2, 1]
    [(1,3),(2,2),(3,1)]
    ```

    *Подсказка:* используйте `foldl'` и вспомогательную функцию для обновления списка пар.

7. Реализуйте функцию `chunksOf`, которая разбивает список на подсписки заданной длины:

    ```haskell
    chunksOf :: Int -> [a] -> [[a]]
    ```

    ```text
    > chunksOf 3 [1..10]
    [[1,2,3],[4,5,6],[7,8,9],[10]]
    ```

    *Подсказка:* используйте `splitAt` или комбинацию `take`/`drop` с рекурсией.

## Заключение

Рекурсия, `map`, `filter` и свёртки (`foldr`, `foldl'`) — фундамент обработки данных в Haskell. Через `foldr` выражаются `map`, `filter`, `length`, `reverse` и многие другие функции; `foldl'` безопаснее ленивого `foldl` для строгих вычислений (подробнее — в [главе 9](chapter09.md)). Мы применили эти инструменты к трекеру задач: собрали статистику за один проход, отсортировали по приоритету и сгруппировали по статусу.

В [следующей главе](chapter05.md) мы познакомимся с классами типов — механизмом, который позволяет одной и той же функции работать с разными типами данных.

```admonish tip title="Для углубления"
- **Haskell MOOC** — [haskell.mooc.fi](https://haskell.mooc.fi/), лекция 3: рекурсия, списки и свёртки.
- **MetaLamp** — [education.metalamp.ru](https://education.metalamp.ru/education/haskell/task-1), задание 3: работа со списками.
```
