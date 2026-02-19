# Стандартные структуры данных

Это последняя глава первой части книги. К этому моменту мы познакомились с типами, функциями, записями, алгебраическими типами данных, паттерн-матчингом, рекурсией, свёртками и классами типов. Но наш трекер задач хранит задачи в обычном списке `[Task]`, а текст представляет типом `String`. Для учебных примеров это работает, но в реальном коде так не делают. Здесь мы разберёмся, почему `String` — плохой выбор для текста, и перейдём на `Text`. Освоим `Map` — ассоциативный массив с быстрым поиском по ключу — и `Set` — множество уникальных элементов. Узнаем, когда использовать `IntMap`, `HashMap` и `Vector`. А главное — обновим трекер задач: `Map TaskId Task` вместо списка, `Set Tag` вместо списка тегов. К концу главы наш проект станет ощутимо ближе к тому, как устроены настоящие Haskell-приложения.

## Проблемы с String

Вспомним определение `String` в Haskell:

```haskell
type String = [Char]
```

`String` — это просто список символов. Связный список. Каждый символ хранится в отдельном узле с указателем на следующий. Это означает:

- **Расход памяти.** На каждый символ — накладные расходы на узел списка (около 40 байт на символ вместо 1–4 байтов).
- **Скорость.** Конкатенация, поиск подстроки, определение длины — всё O(n), причём с большой константой.
- **Юникод.** `Char` — это кодовая точка Unicode, и `String` корректно работает с Юникодом. Но делает это медленно.

Для интерактивного ввода и маленьких строк `String` подходит. Для всего остального — нет.

```admonish warning title="Правило"
В реальном коде всегда используйте `Text` вместо `String`. Исключение — взаимодействие с API, которые требуют `String` (например, `FilePath`).
```

## Text — эффективные строки

Модуль `Data.Text` предоставляет тип `Text` — компактное представление текста в кодировке UTF-16. Внутри — непрерывный массив, а не связный список.

### Подключение

```haskell
import Data.Text (Text)
import Data.Text qualified as T
```

```admonish note title="Квалифицированные импорты"
Паттерн `import Module qualified as M` — стандартная практика для модулей-контейнеров. Так мы избегаем конфликтов имён: `T.length` — длина `Text`, `length` — длина списка. Этот паттерн используется для `Data.Map`, `Data.Set`, `Data.Text` и многих других модулей.
```

### OverloadedStrings

По умолчанию строковые литералы `"hello"` имеют тип `String`. Расширение `OverloadedStrings` (включённое в нашем проекте) делает их полиморфными — по аналогии с тем, как числовой литерал `42` имеет тип `Num a => a`:

```haskell
{-# LANGUAGE OverloadedStrings #-}

greeting :: Text
greeting = "Привет, мир!"  -- литерал автоматически становится Text
```

Без расширения пришлось бы писать `T.pack "Привет, мир!"`.

```admonish tip title="Знакомый аналог"
`OverloadedStrings` — это как неявные преобразования строк. В Python `str` всегда Unicode. В Java `String` — всегда UTF-16. В Haskell нужно явно выбрать `Text` и включить расширение, чтобы литералы работали «как ожидается».
```

### Основные операции

```haskell
-- Преобразование String <-> Text
T.pack   :: String -> Text
T.unpack :: Text -> String

-- Длина
T.length :: Text -> Int

-- Конкатенация
T.append    :: Text -> Text -> Text    -- или оператор (<>)
T.concat    :: [Text] -> Text
T.intercalate :: Text -> [Text] -> Text  -- вставляет разделитель

-- Разбиение и поиск
T.words     :: Text -> [Text]          -- разбить по пробелам
T.lines     :: Text -> [Text]          -- разбить по строкам
T.splitOn   :: Text -> Text -> [Text]  -- разбить по разделителю
T.isInfixOf :: Text -> Text -> Bool    -- поиск подстроки

-- Преобразование
T.toUpper :: Text -> Text
T.toLower :: Text -> Text
T.strip   :: Text -> Text              -- убрать пробелы по краям
```

Попробуем в GHCi:

```text
> import Data.Text qualified as T
> T.intercalate ", " ["Haskell", "OCaml", "Elm"]
"Haskell, OCaml, Elm"

> T.words "  слово   ещё   слово  "
["слово","ещё","слово"]

> T.toUpper "привет"
"ПРИВЕТ"

> T.length "Haskell"
7
```

```admonish tip title="Знакомый аналог"
`Text` — аналог `str` в Python (всегда Unicode), `String` в Java или `string` в Go. Операции `T.words`, `T.splitOn`, `T.strip` — прямые аналоги `.split()`, `.split(sep)`, `.strip()` из Python.
```

## Map — ассоциативные массивы

`Data.Map.Strict` предоставляет тип `Map k v` — ассоциативный массив (словарь), отображающий ключи типа `k` в значения типа `v`. Внутри — сбалансированное двоичное дерево. Операции поиска, вставки и удаления работают за O(log n).

```haskell
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
```

```admonish tip title="Знакомый аналог"
`Map` — аналог `dict` в Python, `Map` / обычного объекта в JavaScript, `TreeMap` в Java. Ключевое отличие: ключи должны реализовывать `Ord` (поддерживать сравнение), потому что `Map` основана на дереве.
```

### Создание

```haskell
-- Пустой словарь
Map.empty :: Map k v

-- Из одной пары
Map.singleton :: k -> v -> Map k v

-- Из списка пар
Map.fromList :: Ord k => [(k, v)] -> Map k v
```

```text
> import Data.Map.Strict qualified as Map
> let ages = Map.fromList [("Алиса", 30), ("Боб", 25), ("Клара", 28)]
> ages
fromList [("Алиса",30),("Боб",25),("Клара",28)]
```

### Поиск

```haskell
-- Безопасный поиск — возвращает Maybe
Map.lookup :: Ord k => k -> Map k v -> Maybe v

-- Поиск с значением по умолчанию
Map.findWithDefault :: Ord k => v -> k -> Map k v -> v

-- Проверка наличия ключа
Map.member :: Ord k => k -> Map k v -> Bool
```

```text
> Map.lookup "Алиса" ages
Just 30

> Map.lookup "Дмитрий" ages
Nothing

> Map.findWithDefault 0 "Дмитрий" ages
0

> Map.member "Боб" ages
True
```

### Вставка и удаление

```haskell
-- Вставка (перезаписывает старое значение)
Map.insert :: Ord k => k -> v -> Map k v -> Map k v

-- Удаление
Map.delete :: Ord k => k -> Map k v -> Map k v

-- Обновление значения (Nothing — удалить, Just — заменить)
Map.update :: Ord k => (v -> Maybe v) -> k -> Map k v -> Map k v

-- Вставка с объединением (если ключ уже есть)
Map.insertWith :: Ord k => (v -> v -> v) -> k -> v -> Map k v -> Map k v
```

```text
> let ages2 = Map.insert "Дмитрий" 35 ages
> ages2
fromList [("Алиса",30),("Боб",25),("Дмитрий",35),("Клара",28)]

> Map.delete "Боб" ages2
fromList [("Алиса",30),("Дмитрий",35),("Клара",28)]
```

Обратите внимание: `ages` не изменился. Мы получили *новый* словарь. Это иммутабельная структура данных — как и всё в Haskell.

### Свёртки и преобразования

```haskell
-- Получить все ключи или значения
Map.keys   :: Map k v -> [k]
Map.elems  :: Map k v -> [v]
Map.toList :: Map k v -> [(k, v)]

-- Количество элементов
Map.size :: Map k v -> Int

-- Применить функцию ко всем значениям
Map.map :: (a -> b) -> Map k a -> Map k b

-- Отфильтровать по значению
Map.filter :: (v -> Bool) -> Map k v -> Map k v

-- Свёртка
Map.foldlWithKey' :: (a -> k -> v -> a) -> a -> Map k v -> a
```

```text
> Map.keys ages
["Алиса","Боб","Клара"]

> Map.map (+1) ages
fromList [("Алиса",31),("Боб",26),("Клара",29)]

> Map.filter (>= 28) ages
fromList [("Алиса",30),("Клара",28)]

> Map.size ages
3
```

### Подсчёт частоты слов — практический пример

`Map` отлично подходит для подсчёта вхождений. Ключевая функция — `insertWith`:

```haskell
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as T

wordFrequency :: Text -> Map Text Int
wordFrequency = foldl' countWord Map.empty . T.words
  where
    countWord acc word = Map.insertWith (+) (T.toLower word) 1 acc
```

```text
> wordFrequency "кот кот пёс кот пёс рыба"
fromList [("кот",3),("пёс",2),("рыба",1)]
```

`Map.insertWith (+) word 1 acc` работает так: если `word` ещё нет в `acc`, вставляет `1`. Если есть со значением `n`, заменяет на `(+) 1 n = n + 1`.

## Set — множества

`Data.Set` предоставляет тип `Set a` — множество уникальных элементов. Как и `Map`, реализовано на сбалансированном дереве; требует `Ord` от элементов.

```haskell
import Data.Set (Set)
import Data.Set qualified as Set
```

```admonish tip title="Знакомый аналог"
`Set` — аналог `set()` в Python, `Set` в JavaScript, `TreeSet` в Java. Элементы уникальны, порядок определяется экземпляром `Ord`.
```

### Основные операции

```haskell
-- Создание
Set.empty     :: Set a
Set.singleton :: a -> Set a
Set.fromList  :: Ord a => [a] -> Set a

-- Вставка и удаление
Set.insert :: Ord a => a -> Set a -> Set a
Set.delete :: Ord a => a -> Set a -> Set a

-- Проверка принадлежности
Set.member :: Ord a => a -> Set a -> Bool
Set.size   :: Set a -> Int
Set.null   :: Set a -> Bool

-- Теоретико-множественные операции
Set.union        :: Ord a => Set a -> Set a -> Set a
Set.intersection :: Ord a => Set a -> Set a -> Set a
Set.difference   :: Ord a => Set a -> Set a -> Set a

-- Преобразования
Set.toList :: Set a -> [a]
Set.map    :: Ord b => (a -> b) -> Set a -> Set b
Set.filter :: (a -> Bool) -> Set a -> Set a
```

Главное отличие от списков: `Set.fromList` автоматически устраняет дубликаты, а все операции вставки и поиска работают за O(log n). Попробуем в GHCi — заметьте, что второй `"Haskell"` исчезает при создании множества:

```text
> import Data.Set qualified as Set
> let langs = Set.fromList ["Haskell", "OCaml", "Elm", "Haskell"]
> langs
fromList ["Elm","Haskell","OCaml"]

> Set.member "Haskell" langs
True

> Set.member "Rust" langs
False

> let moreLangs = Set.fromList ["Rust", "Haskell", "Idris"]
> Set.union langs moreLangs
fromList ["Elm","Haskell","Idris","OCaml","Rust"]

> Set.intersection langs moreLangs
fromList ["Haskell"]
```

`Set.union` объединяет два множества без дубликатов. `Set.intersection` возвращает только общие элементы. `Set.difference a b` — элементы, которые есть в `a`, но нет в `b`. Все операции иммутабельны: исходные множества не изменяются.

## Какую структуру выбрать

Haskell предлагает несколько контейнеров. Краткая сводка:

| Структура | Модуль | Ключ/элемент | Поиск | Когда использовать |
|-----------|--------|-------------|-------|--------------------|
| `[a]` | `Prelude` | — | O(n) | Маленькие коллекции, ленивые потоки, паттерн-матчинг |
| `Map k v` | `Data.Map.Strict` | `Ord k` | O(log n) | Ассоциативный массив с произвольным ключом |
| `Set a` | `Data.Set` | `Ord a` | O(log n) | Уникальные элементы, пересечения, объединения |
| `IntMap v` | `Data.IntMap.Strict` | `Int` | O(log n)* | Словарь с целочисленным ключом (быстрее `Map Int v`) |
| `HashMap k v` | `Data.HashMap.Strict` | `Hashable k` | O(1) ср. | Когда нужна скорость хэш-таблицы (пакет `unordered-containers`) |
| `HashSet a` | `Data.HashSet` | `Hashable a` | O(1) ср. | Аналог `Set`, но на хэш-таблице |
| `Vector a` | `Data.Vector` | — | O(1) индекс | Массив с произвольным доступом по индексу |

*`IntMap` использует patricia trie и на практике быстрее `Map Int v` в 2–5 раз.

```admonish note title="Что выбрать по умолчанию"
Для большинства задач `Map` и `Set` из `containers` (входит в стандартную поставку GHC) — отличный выбор. `HashMap` и `HashSet` из `unordered-containers` стоит использовать, когда профилировщик показывает, что `Map` — узкое место. `Vector` нужен, когда важен доступ по индексу — например, для числовых вычислений.
```

## Обновляем трекер задач

Теперь у нас достаточно инструментов, чтобы серьёзно улучшить модель трекера задач. Вместо `[Task]` мы будем хранить задачи в `Map TaskId Task`, а теги представим как `Set Tag`.

### Новые типы

```haskell
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as T

type Tag = Text
type TaskId = Int

data Priority = Low | Medium | High
  deriving (Show, Eq, Ord)

data Status = Todo | InProgress | Done
  deriving (Show, Eq, Ord)

data Task = Task
  { taskTitle       :: Text
  , taskDescription :: Text
  , taskPriority    :: Priority
  , taskStatus      :: Status
  , taskTags        :: Set Tag
  } deriving (Show, Eq)

newtype TaskStore = TaskStore { unTaskStore :: Map TaskId Task }
  deriving (Show, Eq)
```

Что изменилось:

- `taskTitle` и `taskDescription` теперь `Text`, а не `String`.
- Вместо `[String]` для тегов — `Set Tag` (теги уникальны по определению).
- `TaskStore` — обёртка над `Map TaskId Task`. Каждая задача имеет уникальный числовой идентификатор.

### Базовые операции

```haskell
emptyStore :: TaskStore
emptyStore = TaskStore Map.empty

addTask :: TaskId -> Task -> TaskStore -> TaskStore
addTask tid task (TaskStore m) = TaskStore (Map.insert tid task m)

removeTask :: TaskId -> TaskStore -> TaskStore
removeTask tid (TaskStore m) = TaskStore (Map.delete tid m)

getTask :: TaskId -> TaskStore -> Maybe Task
getTask tid (TaskStore m) = Map.lookup tid m
```

Обратите внимание, как паттерн-матчинг на `TaskStore m` разворачивает `newtype`, а результат заворачивает обратно. Каждая функция — чистая, без побочных эффектов.

### Поиск по тегу

```haskell
findByTag :: Tag -> TaskStore -> [Task]
findByTag tag (TaskStore m) =
  Map.elems (Map.filter hasTag m)
  where
    hasTag task = Set.member tag (taskTags task)
```

`Map.filter` отбирает элементы по предикату, `Map.elems` извлекает значения. Результат — список задач, у которых указанный тег присутствует в множестве `taskTags`.

### Сбор всех тегов

```haskell
allTags :: TaskStore -> Set Tag
allTags (TaskStore m) =
  Map.foldl' (\acc task -> Set.union acc (taskTags task)) Set.empty m
```

Свёртка по всем задачам, на каждом шаге объединяем множество тегов текущей задачи с аккумулятором. Результат — множество всех тегов, которые встречаются хотя бы в одной задаче.

### Пример использования

```text
> let t1 = Task "Изучить Map" "Data.Map.Strict" High Todo (Set.fromList ["haskell", "обучение"])
> let t2 = Task "Написать тесты" "hspec" Medium Todo (Set.fromList ["haskell", "тесты"])
> let t3 = Task "Купить молоко" "" Low Todo Set.empty

> let store = addTask 1 t1 . addTask 2 t2 . addTask 3 t3 $ emptyStore
> getTask 2 store
Just (Task {taskTitle = "Написать тесты", ...})

> findByTag "haskell" store
[Task {taskTitle = "Изучить Map", ...}, Task {taskTitle = "Написать тесты", ...}]

> allTags store
fromList ["haskell","обучение","тесты"]

> removeTask 3 store
TaskStore {unTaskStore = fromList [(1,...),(2,...)]}
```

Обратите внимание на цепочку `addTask 1 t1 . addTask 2 t2 . addTask 3 t3 $ emptyStore`. Каждая функция `addTask id task` — это `TaskStore -> TaskStore`, и мы составляем их через композицию `(.)`.

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

### Проект ★☆☆

1. Реализуйте функцию `storeSize`, которая возвращает количество задач в хранилище.

    ```haskell
    storeSize :: TaskStore -> Int
    ```

    ```text
    > storeSize emptyStore
    0
    > storeSize (addTask 1 t1 emptyStore)
    1
    ```

2. Реализуйте функцию `updateTaskStatus`, которая изменяет статус задачи по её идентификатору. Если задачи с таким `TaskId` нет, хранилище не изменяется.

    ```haskell
    updateTaskStatus :: TaskId -> Status -> TaskStore -> TaskStore
    ```

    *Подсказка:* используйте `Map.adjust` — она применяет функцию к значению по ключу, если ключ существует.

### Проект ★★☆

3. Реализуйте функцию `findByTag`, которая возвращает список всех задач, содержащих данный тег.

    ```haskell
    findByTag :: Tag -> TaskStore -> [Task]
    ```

    *Подсказка:* используйте `Map.filter` и `Map.elems`. Для проверки принадлежности тега — `Set.member`.

### Практика ★☆☆

4. Реализуйте функцию `invertMap`, которая меняет местами ключи и значения в `Map`. Если несколько ключей имеют одинаковое значение, сохраняется любой из них.

    ```haskell
    invertMap :: (Ord k, Ord v) => Map k v -> Map v k
    ```

    ```text
    > invertMap (Map.fromList [("a", 1), ("b", 2), ("c", 3)])
    fromList [(1,"a"),(2,"b"),(3,"c")]
    ```

    *Подсказка:* `Map.toList`, `map`, `Map.fromList`.

5. Реализуйте функцию `commonElements`, которая возвращает общие элементы двух списков (без дубликатов).

    ```haskell
    commonElements :: Ord a => [a] -> [a] -> [a]
    ```

    ```text
    > commonElements [1,2,3,2] [2,3,4,3]
    [2,3]
    ```

    *Подсказка:* преобразуйте списки в `Set`, используйте `Set.intersection`, результат преобразуйте обратно.

### Практика ★★☆

6. Реализуйте функцию `wordFrequency`, которая считает частоту слов в тексте. Регистр не учитывается.

    ```haskell
    wordFrequency :: Text -> Map Text Int
    ```

    ```text
    > wordFrequency "кот Кот пёс кот Пёс рыба"
    fromList [("кот",3),("пёс",2),("рыба",1)]
    ```

    *Подсказка:* `T.words` разбивает текст на слова, `T.toLower` приводит к нижнему регистру, `Map.insertWith (+)` увеличивает счётчик.

## Заключение

Мы прошли путь от «работает» до «работает правильно»: `Text` заменил `String` для эффективной работы с текстом, `Map` обеспечил O(log n) поиск, вставку и удаление, а `Set` — уникальность элементов и теоретико-множественные операции. Квалифицированные импорты (`import Data.Map.Strict qualified as Map`) стали стандартным паттерном для работы с контейнерами. Трекер задач обновлён: `Map TaskId Task` для хранения, `Set Tag` для тегов.

### Итоги Части I

За шесть глав мы освоили фундамент Haskell:

| Глава | Тема | Ключевые концепции |
|-------|------|--------------------|
| 1 | Введение | GHCup, Stack, GHCi, hspec |
| 2 | Типы и функции | `data`, записи, `Maybe`, каррирование, `(.)`, `($)` |
| 3 | ADT и паттерн-матчинг | Конструкторы, guards, `where`, `case` |
| 4 | Списки и свёртки | Рекурсия, `map`, `filter`, `foldr`, `foldl'` |
| 5 | Классы типов | `class`, `instance`, `deriving`, `Eq`, `Ord`, `Show` |
| 6 | Структуры данных | `Text`, `Map`, `Set`, квалифицированные импорты |

Наш трекер задач вырос от простого типа `Task` со списком до полноценной модели с хранилищем на `Map`, тегами на `Set` и текстом на `Text`. Но все функции, которые мы написали, — чистые. Трекер не может ничего напечатать, прочитать с клавиатуры или сохранить в файл.

В [следующей главе](chapter07.md) мы добавим ввод-вывод (`IO`) и сделаем трекер интерактивным: пользователь сможет добавлять задачи, просматривать список и отмечать задачи как выполненные — всё через командную строку.

```admonish tip title="Для углубления"
- **Haskell MOOC** — [haskell.mooc.fi](https://haskell.mooc.fi/), лекция 5: `Data.Map`, `Data.Text` и работа с контейнерами.
- **MetaLamp** — [education.metalamp.ru](https://education.metalamp.ru/education/haskell/task-1), задание 3: стандартные структуры данных.
- **Документация `containers`** — [hackage.haskell.org/package/containers](https://hackage.haskell.org/package/containers) — полная документация по `Map`, `Set`, `IntMap`, `Sequence`.
- **Документация `text`** — [hackage.haskell.org/package/text](https://hackage.haskell.org/package/text) — полный API модуля `Data.Text`.
```
