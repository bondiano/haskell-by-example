# Типы, функции и REPL

В этой главе мы начнём строить сквозной проект — **трекер задач** (task tracker). На его примере познакомимся с базовыми типами Haskell (`Int`, `String`, `Bool`, списки, кортежи), определением типов данных через `data` и `type`, записями (records), каррированием и частичным применением, композицией функций `(.)` и `($)`, а также типом `Maybe` для представления необязательных значений. К концу главы у нас будет модуль `TaskTracker.Types` с моделью предметной области и набором чистых функций для работы с задачами.

## Подготовка проекта

Код этой главы находится в `exercises/chapter02`. Соберите проект:

```text
$ cd exercises/chapter02
$ stack build
```

## Базовые типы

Начнём с GHCi — проверим, какие типы есть в Haskell:

```text
$ stack ghci

> :type 42
42 :: Num a => a

> :type 42 :: Int
42 :: Int

> :type 3.14
3.14 :: Fractional a => a

> :type "hello"
"hello" :: String

> :type 'a'
'a' :: Char

> :type True
True :: Bool
```

Обратите внимание: числовые литералы полиморфны. `42` — это не `Int` и не `Integer`, а «любой числовой тип». Конкретный тип определяется контекстом. Мы можем явно указать тип через аннотацию `:: Int`.

Другие типы:

```text
> :type [1, 2, 3]
[1, 2, 3] :: Num a => [a]

> :type (True, "hello")
(True, "hello") :: (Bool, String)

> :type ('a', 1, True)
('a', 1, True) :: Num b => (Char, b, Bool)
```

**Списки** `[a]` — однородные коллекции (все элементы одного типа). **Кортежи** `(a, b)` — фиксированного размера, но элементы могут быть разных типов.

## Определяем модель: задачи трекера

Теперь применим эти знания к нашему проекту. Трекер задач оперирует *задачами* — у каждой есть заголовок, приоритет и статус. Опишем это на языке типов.

### `data` — алгебраический тип данных

Приоритет и статус — это перечисления. В Haskell они определяются через `data`:

```haskell
module TaskTracker.Types where

data Priority = Low | Medium | High
  deriving (Show, Eq, Ord)

data Status = Todo | InProgress | Done
  deriving (Show, Eq, Ord)
```

`Priority` — тип с тремя **конструкторами**: `Low`, `Medium`, `High`. Конструкторы начинаются с заглавной буквы. `deriving (Show, Eq, Ord)` автоматически генерирует:

- `Show` — преобразование в строку (`show High` → `"High"`).
- `Eq` — сравнение на равенство (`High == High` → `True`).
- `Ord` — упорядочивание (`Low < High` → `True`, порядок следует из порядка конструкторов).

```admonish tip title="Знакомый аналог"
**TypeScript:** `type Priority = 'low' | 'medium' | 'high'` — union type.
**Python:** `class Priority(Enum): LOW = 1; MEDIUM = 2; HIGH = 3`.
В Haskell `data` с несколькими конструкторами — это и есть enum, но типобезопасный.
```

### Записи (records)

Теперь определим саму задачу — тип с именованными полями:

```haskell
data Task = Task
  { taskTitle       :: String
  , taskDescription :: String
  , taskPriority    :: Priority
  , taskStatus      :: Status
  }
  deriving (Show, Eq)
```

Фигурные скобки задают **записи** — каждое поле имеет имя и тип. `Task` — и имя типа (слева от `=`), и имя конструктора (справа). Префикс `task` в именах полей — конвенция, чтобы избежать конфликтов имён (в Haskell имена полей — глобальные функции).

```admonish tip title="Знакомый аналог"
**TypeScript:** `interface Task { title: string; description: string; priority: Priority; status: Status; }`.
**Python:** `@dataclass class Task: title: str; description: str; ...`.
Записи в Haskell — аналог интерфейсов/dataclass, но иммутабельные.
```

### `type` — синоним типа

Создадим альтернативное имя для списка задач:

```haskell
type TaskList = [Task]
```

`TaskList` и `[Task]` — один и тот же тип. Синонимы полезны как документация.

### `newtype` — обёртка типа

`newtype` создаёт новый тип с одним конструктором и одним полем. В отличие от `type`, `newtype` — *другой* тип, а не синоним. В отличие от `data`, он не несёт рантайм-накладных расходов:

```haskell
newtype TaskId = TaskId Int
  deriving (Show, Eq, Ord)
```

`TaskId` — это `Int`, обёрнутый в новый тип. Компилятор не позволит перепутать `TaskId` с обычным `Int` — это дополнительная защита от ошибок.

## Работа с записями

Haskell автоматически генерирует функции-аксессоры для каждого поля. Имя функции совпадает с именем поля:

```text
> let task = Task { taskTitle = "Изучить Haskell", taskDescription = "Прочитать главу 2", taskPriority = High, taskStatus = Todo }
> taskTitle task
"Изучить Haskell"

> taskPriority task
High
```

### Обновление записей

Записи в Haskell иммутабельны — мы не изменяем существующую запись, а создаём новую:

```text
> let task2 = task { taskStatus = InProgress }
> taskStatus task2
InProgress

> taskStatus task
Todo
```

Синтаксис `task { taskStatus = InProgress }` создаёт копию `task` с изменённым полем. Исходный `task` не изменяется.

```admonish tip title="Знакомый аналог"
**TypeScript:** `{ ...task, status: 'inProgress' }` — spread оператор.
**Python:** `dataclasses.replace(task, status=Status.IN_PROGRESS)`.
В Haskell обновление записей встроено в язык.
```

## Функции для задач

Напишем чистые функции для работы с задачами.

### Форматирование

```haskell
showPriority :: Priority -> String
showPriority Low    = "Низкий"
showPriority Medium = "Средний"
showPriority High   = "Высокий"

showStatus :: Status -> String
showStatus Todo       = "К выполнению"
showStatus InProgress = "В работе"
showStatus Done       = "Готово"

showTask :: Task -> String
showTask task =
  "[" <> showPriority (taskPriority task) <> "] "
    <> taskTitle task
    <> " (" <> showStatus (taskStatus task) <> ")"
```

Оператор `<>` — конкатенация строк (метод класса `Semigroup`, но пока достаточно знать, что он склеивает строки).

```text
> showTask task
"[Высокий] Изучить Haskell (К выполнению)"
```

### Создание задач

```haskell
emptyTaskList :: TaskList
emptyTaskList = []

addTask :: Task -> TaskList -> TaskList
addTask = (:)
```

Оператор `:` (cons) добавляет элемент в начало списка. `addTask` определён в *бесточечном стиле* (point-free): вместо `addTask t ts = t : ts` мы просто сказали `addTask = (:)`.

## Отступы

Haskell, как и Python, чувствителен к отступам. Продолжение выражения на следующей строке должно быть с большим отступом:

```haskell
-- Правильно:
showTask task =
  "[" <> showPriority (taskPriority task) <> "] "
    <> taskTitle task

-- Неправильно (ошибка компиляции):
showTask task =
"[" <> showPriority (taskPriority task)
```

Объявления на одном уровне вложенности должны иметь одинаковый отступ:

```haskell
-- Правильно:
let x = 1
    y = 2

-- Неправильно:
let x = 1
     y = 2
```

## Каррирование

Все функции в Haskell принимают ровно один аргумент. Функция «двух аргументов» — это функция, которая принимает первый аргумент и возвращает *новую функцию*, ожидающую второй.

```haskell
add :: Int -> Int -> Int
add x y = x + y
```

Стрелка `->` правоассоциативна: `Int -> Int -> Int` читается как `Int -> (Int -> Int)`.

Мы можем *частично применить* `add`, передав только один аргумент:

```text
> let addFive = add 5
> :type addFive
addFive :: Int -> Int

> addFive 3
8
```

Это **каррирование** (currying). Частичное применение — мощный инструмент:

```text
> :type addTask
addTask :: Task -> TaskList -> TaskList

> let addHaskellTask = addTask task
> :type addHaskellTask
addHaskellTask :: TaskList -> TaskList
```

`addHaskellTask` — функция, которая добавляет конкретную задачу в любой список задач.

```admonish info title="Знакомый аналог"
**TypeScript:** `const add = (a: number) => (b: number) => a + b` — каррированная стрелочная функция.
**Python:** `functools.partial(add, 5)` — явное частичное применение.
В Haskell каррирование и частичное применение встроены в язык.
```

## Поиск задач

Реализуем функцию поиска задачи по заголовку. Нам понадобятся:

- `filter :: (a -> Bool) -> [a] -> [a]` — отбирает элементы, удовлетворяющие предикату.
- `listToMaybe :: [a] -> Maybe a` — возвращает первый элемент списка или `Nothing`.

### Тип `Maybe`

`Maybe a` представляет значение, которого может не быть:

```haskell
data Maybe a = Nothing | Just a
```

- `Nothing` — значения нет (безопасный аналог `null`).
- `Just x` — значение `x` есть.

```text
> import Data.Maybe (listToMaybe)
> listToMaybe [1, 2, 3]
Just 1

> listToMaybe ([] :: [Int])
Nothing
```

```admonish tip title="Знакомый аналог"
**TypeScript:** `T | undefined` или `T | null`.
**Python:** `Optional[T]`.
**Rust:** `Option<T>`.
Но в Haskell компилятор *заставит* вас обработать `Nothing` — забыть невозможно.
```

### Реализация `findTask`

```haskell
findTask :: String -> TaskList -> Maybe Task
findTask title = listToMaybe . filter matchTitle
  where
    matchTitle t = taskTitle t == title
```

Разберём:

1. **`where`** — вспомогательная функция `matchTitle` определена в блоке `where`. Она имеет доступ к `title` из внешней функции (это **замыкание**).

2. **`filter matchTitle`** — частичное применение: `filter` получает предикат, возвращает функцию `[Task] -> [Task]`.

3. **`listToMaybe . filter matchTitle`** — **композиция функций**. Оператор `(.)` соединяет две функции.

4. **Бесточечный стиль** — аргумент `tasks` не упоминается. Запись эквивалентна `findTask title tasks = listToMaybe (filter matchTitle tasks)`.

## Композиция функций

Оператор `(.)` — композиция:

```haskell
(.) :: (b -> c) -> (a -> b) -> a -> c
(f . g) x = f (g x)
```

`f . g` — функция, которая сначала применяет `g`, затем `f`. Это аналог математической записи f∘g.

Композиция позволяет строить сложные функции из простых, не упоминая промежуточные данные:

```haskell
-- Отформатировать первую задачу с данным заголовком
showFoundTask :: String -> TaskList -> Maybe String
showFoundTask title = fmap showTask . findTask title
```

Здесь `fmap showTask` применяет `showTask` к значению внутри `Maybe` (если оно есть). Подробнее о `fmap` — в [главе 11](chapter11.md).

### `($)` vs `(.)`

- `($)` — **применяет** функцию к значению: `f $ x` = `f x` (избавляет от скобок).
- `(.)` — **соединяет** две функции: `(f . g) x` = `f (g x)`.

```haskell
-- ($) — вычисляет результат
length $ filter matchTitle tasks

-- (.) — создаёт новую функцию
countMatching :: String -> TaskList -> Int
countMatching title = length . filter (\t -> taskTitle t == title)
```

`($)` — правоассоциативный оператор с приоритетом 0 (самый низкий), определён как:

```haskell
($) :: (a -> b) -> a -> b
f $ x = f x
```

## Сопоставление с образцом в записях

С расширением `NamedFieldPuns` (включённым в нашем проекте) доступ к полям можно сделать компактнее:

```haskell
showTask :: Task -> String
showTask Task{taskTitle, taskPriority, taskStatus} =
  "[" <> showPriority taskPriority <> "] "
    <> taskTitle
    <> " (" <> showStatus taskStatus <> ")"
```

`Task{taskTitle, taskPriority, taskStatus}` — образец, извлекающий поля в одноимённые переменные.

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

### Проект ★☆☆

1. Реализуйте функцию `mkTask`, которая создаёт задачу с заданным заголовком, приоритетом `Medium` и статусом `Todo`. Описание — пустая строка.

    ```haskell
    mkTask :: String -> Task
    ```

    ```text
    > taskTitle (mkTask "Купить молоко")
    "Купить молоко"

    > taskStatus (mkTask "Купить молоко")
    Todo
    ```

2. Реализуйте функцию `completeTask`, которая возвращает копию задачи со статусом `Done`.

    ```haskell
    completeTask :: Task -> Task
    ```

### Проект ★★☆

3. Реализуйте функцию `findTaskByTitle`, которая находит задачу по заголовку (без учёта регистра не нужен — простое сравнение строк).

    ```haskell
    findTaskByTitle :: String -> TaskList -> Maybe Task
    ```

4. Реализуйте функцию `taskExists`, которая проверяет, есть ли задача с этим заголовком в списке.

    ```haskell
    taskExists :: String -> TaskList -> Bool
    ```

    *Подсказка:* используйте `findTaskByTitle` или найдите подходящую функцию через `:type any` в GHCi.

### Практика ★☆☆

5. Реализуйте функцию `isHighPriority`, которая возвращает `True`, если задача имеет приоритет `High`.

    ```haskell
    isHighPriority :: Task -> Bool
    ```

6. Реализуйте функцию `formatTasks`, которая форматирует список задач в одну строку, разделяя их переносами строк.

    ```haskell
    formatTasks :: TaskList -> String
    ```

    *Подсказка:* используйте `unlines` и `map`.

### Практика ★★☆

7. Реализуйте функцию `removeDuplicates`, которая удаляет дубликаты из списка задач. Дубликатами считаются задачи с одинаковым заголовком. Из группы дубликатов сохраняется первый.

    ```haskell
    removeDuplicates :: TaskList -> TaskList
    ```

    *Подсказка:* найдите функцию `nubBy` в модуле `Data.List` через GHCi (`:info nubBy`) или Hoogle.

## Заключение

Мы определили модель трекера задач (`Priority`, `Status`, `Task`), познакомились с базовыми типами Haskell и научились работать с записями — создавать, читать поля, обновлять. Каррирование и частичное применение оказались встроены прямо в язык, а композиция `(.)` и оператор `($)` позволяют выстраивать конвейеры обработки данных. Тип `Maybe` заменяет `null` и заставляет обрабатывать отсутствие значения явно.

В [следующей главе](chapter03.md) мы подробно разберём алгебраические типы данных и сопоставление с образцом — и научимся фильтровать задачи по произвольным критериям.

```admonish tip title="Для углубления"
- **Haskell MOOC** — [haskell.mooc.fi](https://haskell.mooc.fi/), лекции 1–2: базовые типы, рекурсия, `Maybe`.
- **MetaLamp** — [education.metalamp.ru](https://education.metalamp.ru/education/haskell/task-1), задание 1–2: типы и функции.
```
