# Классы типов

В предыдущих главах мы уже использовали `deriving (Show, Eq, Ord)`, не задумываясь, что именно за этим стоит. Пора разобраться. В этой главе речь пойдёт о **классах типов** — механизме, который делает Haskell одновременно строго типизированным и гибким. Мы разберём разницу между параметрическим и ad-hoc полиморфизмом, познакомимся со стандартными классами (`Eq`, `Ord`, `Show`, `Read`, `Enum`, `Bounded`, `Num`), научимся читать ограничения вида `Eq a =>`, определим собственный класс `Describable` для человекочитаемых описаний, напишем инстансы для типов трекера и реализуем пользовательскую сортировку задач. Заодно разберём стратегии вывода (`stock`, `newtype`, `anyclass`) и методы по умолчанию. К концу главы вы будете свободно читать сигнатуры вида `(Ord a, Show a) => a -> String` и создавать собственные абстракции через классы типов.

## Два вида полиморфизма

### Параметрический полиморфизм

Рассмотрим знакомую функцию:

```haskell
length :: [a] -> Int
```

Переменная `a` может быть *любым* типом: `Int`, `String`, `Task` — без ограничений. Функция `length` ничего не знает о содержимом списка и не может инспектировать элементы. Она работает исключительно со структурой списка.

Это **параметрический полиморфизм** — одна реализация для всех типов. Другие примеры:

```haskell
head   :: [a] -> a
fst    :: (a, b) -> a
id     :: a -> a
const  :: a -> b -> a
```

Параметрический полиморфизм даёт мощные гарантии. Из одной только сигнатуры `f :: [a] -> [a]` можно заключить, что `f` не может *создать* элементы из ниоткуда — она может только переставлять, удалять или дублировать элементы исходного списка. Эти выводы называются **свободными теоремами** (free theorems), и они следуют из параметричности. Это одно из самых мощных свойств системы типов Haskell: тип *сам по себе* документирует поведение функции.

```admonish info title="Свободные теоремы"
Филип Вадлер показал в статье «Theorems for Free!» (1989), что параметрический полиморфизм автоматически порождает законы. Например, для любой функции `f :: [a] -> [a]` и любой функции `g :: a -> b` выполняется:
`map g . f = f . map g`.
Компилятор может использовать такие законы для оптимизации, а программист — для рассуждений о корректности.
```

### Ad-hoc полиморфизм

Но что, если функция *должна* знать что-то о типе? Сравнение на равенство, преобразование в строку, арифметика — всё это зависит от конкретного типа. Сравнивать `Int` и `String` нужно по-разному.

```haskell
-- Не сработает: как сравнивать произвольные `a`?
elem :: a -> [a] -> Bool
elem _ []     = False
elem x (y:ys) = x == y || elem x ys  -- ошибка: нет (==) для `a`
```

Нам нужен способ сказать: «эта функция работает не для *всех* типов, а только для тех, которые *поддерживают сравнение*». Именно это делают классы типов:

```haskell
elem :: Eq a => a -> [a] -> Bool
```

Запись `Eq a =>` — **ограничение** (constraint): «тип `a` должен быть экземпляром класса `Eq`». Это **ad-hoc полиморфизм** — разные реализации для разных типов, выбираемые компилятором на основе типа.

```admonish tip title="Знакомый аналог"
**TypeScript:** `interface Eq<T> { equals(other: T): boolean }` — интерфейс, который тип должен реализовать.
**Python:** `class Eq(Protocol): def __eq__(self, other) -> bool: ...` — протокол (PEP 544) или абстрактный базовый класс (ABC).
**Rust:** `trait Eq { fn eq(&self, other: &Self) -> bool; }`.
Классы типов в Haskell ближе всего к трейтам Rust: они определяют набор операций, а тип отдельно объявляет, что он их поддерживает.
```

## Стандартные классы типов

### Eq — равенство

```haskell
class Eq a where
  (==) :: a -> a -> Bool
  (/=) :: a -> a -> Bool
  x /= y = not (x == y)   -- метод по умолчанию
```

Достаточно определить `(==)` — метод `(/=)` получит реализацию автоматически через **метод по умолчанию** (default method implementation).

```text
> High == High
True

> Todo /= Done
True
```

### Ord — упорядочивание

```haskell
class Eq a => Ord a where
  compare :: a -> a -> Ordering
  (<), (<=), (>), (>=) :: a -> a -> Bool
  max, min :: a -> a -> a
  -- ...методы по умолчанию через compare
```

Обратите внимание на `Eq a =>` перед `Ord a` — это **суперкласс**. Чтобы тип имел порядок, он сначала должен поддерживать равенство. Достаточно определить `compare` — все остальные методы получат реализации по умолчанию.

Тип `Ordering` определён как:

```haskell
data Ordering = LT | EQ | GT
```

```text
> compare Low High
LT

> max Medium Low
Medium
```

### Show и Read — сериализация в строку

```haskell
class Show a where
  show :: a -> String
  -- ...и другие методы

class Read a where
  -- ...парсинг из строки
```

```text
> show High
"High"

> show (Task "Test" "" Medium Todo)
"Task {taskTitle = \"Test\", taskDescription = \"\", taskPriority = Medium, taskStatus = Todo}"

> read "High" :: Priority
High
```

```admonish warning title="Осторожно с Read"
Функция `read` бросает исключение при невалидном вводе. В реальном коде используйте `readMaybe :: Read a => String -> Maybe a` из модуля `Text.Read`. Подробнее об обработке ошибок — в [главе 8](chapter08.md).
```

### Enum и Bounded — перечислимые типы

```haskell
class Enum a where
  succ :: a -> a
  pred :: a -> a
  toEnum   :: Int -> a
  fromEnum :: a -> Int
  -- ...

class Bounded a where
  minBound :: a
  maxBound :: a
```

Для наших типов `Priority` и `Status` можно автоматически вывести оба класса:

```haskell
data Priority = Low | Medium | High
  deriving (Show, Eq, Ord, Enum, Bounded)
```

```text
> [minBound .. maxBound] :: [Priority]
[Low,Medium,High]

> succ Low
Medium

> [Todo ..]
[Todo,InProgress,Done]
```

Синтаксис `[Low ..]` и `[minBound .. maxBound]` работает именно благодаря `Enum`. Это **арифметические последовательности** — синтаксический сахар для методов `Enum`.

### Num — числовые типы

```haskell
class Num a where
  (+), (-), (*) :: a -> a -> a
  negate :: a -> a
  abs    :: a -> a
  signum :: a -> a
  fromInteger :: Integer -> a
```

`Num` — причина, по которой литерал `42` имеет тип `Num a => a`, а не `Int`. Литерал `42` компилятор превращает в `fromInteger 42`, и конкретный тип определяется контекстом.

```text
> :type 42
42 :: Num a => a

> 42 :: Int
42

> 42 :: Double
42.0
```

## Ограничения в сигнатурах

Ограничения можно комбинировать:

```haskell
-- Тип должен поддерживать и равенство, и преобразование в строку
showUnique :: (Eq a, Show a) => [a] -> String
showUnique xs = show (nub xs)
  where
    nub [] = []
    nub (x:rest) = x : nub (filter (/= x) rest)
```

Ограничения «заразны» — если ваша функция вызывает функцию с ограничением, это ограничение должно появиться и в вашей сигнатуре:

```haskell
-- filter не требует ограничений, но (==) требует Eq
filterByStatus :: Eq a => a -> [(a, b)] -> [b]
filterByStatus s = map snd . filter (\(status, _) -> status == s)
```

## Определяем свой класс типов

Вернёмся к нашему трекеру. Функции `showPriority` и `showStatus` из [главы 2](chapter02.md) выглядят похоже — обе превращают значение в человекочитаемое описание на русском. Вместо отдельных функций для каждого типа можно определить единый **интерфейс**:

```haskell
class Describable a where
  describe :: a -> String
```

Это объявление говорит: «существует класс `Describable`; любой тип, являющийся его экземпляром, должен реализовать функцию `describe :: a -> String`».

## Пишем инстансы

**Инстанс** (instance) — объявление того, что конкретный тип реализует класс:

```haskell
instance Describable Priority where
  describe Low    = "Низкий приоритет"
  describe Medium = "Средний приоритет"
  describe High   = "Высокий приоритет"

instance Describable Status where
  describe Todo       = "К выполнению"
  describe InProgress = "В работе"
  describe Done       = "Выполнено"

instance Describable Task where
  describe task =
    "[" <> describe (taskPriority task) <> "] "
      <> taskTitle task
      <> " — " <> describe (taskStatus task)
```

Обратите внимание: в инстансе `Task` мы используем `describe` для `Priority` и `Status` — полиморфизм в действии. Компилятор подставит нужную реализацию на основе типа аргумента.

```text
> describe High
"Высокий приоритет"

> describe Todo
"К выполнению"

> let task = Task "Изучить классы типов" "" High InProgress
> describe task
"[Высокий приоритет] Изучить классы типов — В работе"
```

Теперь у нас единый интерфейс `describe` для любых типов нашего домена.

## Методы по умолчанию

Класс может предоставлять реализации методов «из коробки»:

```haskell
class Describable a where
  describe :: a -> String

  -- Метод по умолчанию: краткое описание = полное описание
  shortDescribe :: a -> String
  shortDescribe = describe
```

Если инстанс не определяет `shortDescribe`, будет использована реализация по умолчанию. Инстанс может переопределить её:

```haskell
instance Describable Task where
  describe task =
    "[" <> describe (taskPriority task) <> "] "
      <> taskTitle task
      <> " — " <> describe (taskStatus task)

  shortDescribe task = taskTitle task
```

```admonish note title="Минимальное определение"
Класс `Eq` требует определить *хотя бы* `(==)` или `(/=)` — второй метод выводится из первого. Это называется **минимальным полным определением** (minimal complete definition). GHC предупредит, если определение неполное.
```

## Deriving: автоматический вывод инстансов

### Stock deriving

Для стандартных классов GHC умеет генерировать инстансы автоматически:

```haskell
data Priority = Low | Medium | High
  deriving (Show, Eq, Ord, Enum, Bounded)
```

Это **stock deriving** — встроенный механизм для классов `Eq`, `Ord`, `Show`, `Read`, `Enum`, `Bounded`, `Ix`, `Generic`, `Data`, `Typeable`, `Lift`.

Для `Ord` порядок конструкторов определяется порядком их объявления: `Low < Medium < High`. Для `Show` генерируется текстовое представление, совпадающее с синтаксисом Haskell.

### DerivingStrategies

Расширение `DerivingStrategies` (включённое в нашем проекте) позволяет явно указать *стратегию* вывода:

```haskell
{-# LANGUAGE DerivingStrategies #-}

data Priority = Low | Medium | High
  deriving stock (Show, Eq, Ord, Enum, Bounded)
```

Существует три стратегии:

- **`stock`** — встроенный вывод GHC (работает только для стандартных классов).
- **`newtype`** — для `newtype`-обёрток: инстанс «наследуется» от внутреннего типа.
- **`anyclass`** — использует методы по умолчанию из класса (часто в связке с `DeriveAnyClass` и `Generic`).

```haskell
newtype TaskId = TaskId Int
  deriving stock   (Show)     -- собственное Show: "TaskId 42"
  deriving newtype (Eq, Ord, Num)  -- делегирует Int: сравнение и арифметика как у Int
```

```text
> TaskId 1 < TaskId 2
True

> TaskId 10 + TaskId 5
TaskId 15
```

С `deriving newtype` обёртка `TaskId` «наследует» поведение `Int` без рантайм-накладных расходов. Это безопасная альтернатива `type`-синонимам: компилятор отличает `TaskId` от `Int`, но реализации операций переиспользуются.

```admonish tip title="Знакомый аналог"
**TypeScript:** deriving stock ~ автогенерация через `implements`; deriving newtype ~ branded types (`type TaskId = number & { __brand: 'TaskId' }`), но в Haskell это работает на уровне типов с нулевой стоимостью в рантайме.
**Python:** deriving stock ~ `@dataclass(eq=True, order=True)`.
```

## Проект: пользовательская сортировка задач

В нашем трекере удобно сортировать задачи так, чтобы **самые важные и незавершённые** были вверху. Стандартный `Ord` для `Task` нам не подходит — он сравнивал бы поля лексикографически, начиная с `taskTitle`.

Определим функцию сравнения с нашей бизнес-логикой:

```haskell
-- Высокий приоритет первый (обратный порядок)
-- При равном приоритете: Todo < InProgress < Done
compareTasks :: Task -> Task -> Ordering
compareTasks t1 t2 =
  case compare (taskPriority t2) (taskPriority t1) of  -- обратный порядок!
    EQ -> compare (taskStatus t1) (taskStatus t2)
    other -> other
```

Обратите внимание: `compare (taskPriority t2) (taskPriority t1)` — аргументы переставлены, чтобы `High` шёл первым.

```haskell
import Data.List (sortBy)

sortTasks :: [Task] -> [Task]
sortTasks = sortBy compareTasks
```

```text
> let tasks = [ Task "Купить молоко" "" Low Todo
              , Task "Релиз" "" High InProgress
              , Task "Баг-репорт" "" High Todo
              , Task "Рефакторинг" "" Medium Done
              ]
> map taskTitle (sortTasks tasks)
["Баг-репорт","Релиз","Рефакторинг","Купить молоко"]
```

Задачи отсортированы: сначала `High` (внутри них `Todo` перед `InProgress`), затем `Medium`, затем `Low`.

```admonish info title="Почему не instance Ord Task?"
Можно было бы определить `instance Ord Task`, но тогда *все* сравнения задач во всей программе использовали бы эту логику. Это ограничивает: что если в другом месте нужна сортировка по дате создания? В Haskell принято использовать `sortBy` с явной функцией сравнения, оставляя `Ord` для «канонического» порядка.
```

## Несколько ограничений и классы типов на практике

Классы типов часто комбинируются. Вот реальный пример — функция форматирования статистики:

```haskell
data TaskStats = TaskStats
  { totalTasks   :: Int
  , todoCount    :: Int
  , doneCount    :: Int
  , highPriority :: Int
  }

describeStats :: TaskStats -> String
describeStats TaskStats{..} =
  "Всего: " <> show totalTasks
    <> ", к выполнению: " <> show todoCount
    <> ", выполнено: " <> show doneCount
    <> ", высокий приоритет: " <> show highPriority
```

Здесь мы используем `RecordWildCards` (расширение `{..}` в паттерне) — все поля записи становятся локальными переменными. А `show` вызывается для `Int` — компилятор подбирает нужный инстанс.

## Где живут инстансы

Инстанс можно объявить в одном из двух мест:

1. **В модуле, где определён тип** — например, `instance Show Priority` в модуле `TaskTracker.Types`.
2. **В модуле, где определён класс** — например, `instance Describable Priority` в модуле, где объявлен `Describable`.

Объявление инстанса в третьем модуле (так называемый **orphan instance**) возможно, но нежелательно — компилятор предупредит об этом, потому что orphan-инстансы могут приводить к конфликтам при импорте.

```admonish warning title="Осиротевшие инстансы"
Если вы видите предупреждение `-Worphans`, это сигнал: переместите инстанс в модуль типа или в модуль класса. Orphan-инстансы — частая причина неожиданных конфликтов в больших проектах.
```

## Классы типов vs. интерфейсы ООП

Ключевое отличие от интерфейсов в ООП-языках:

| | ООП-интерфейсы | Классы типов Haskell |
|---|---|---|
| Привязка к типу | При *определении* типа | *Отдельно* от определения типа |
| Добавление нового интерфейса | Требует изменения типа | Новый инстанс в отдельном модуле |
| Диспетчеризация | Виртуальная таблица (рантайм) | Словарь методов (компилятор) |
| Работа с примитивами | Часто невозможна | `instance Eq Int where ...` |

В Haskell вы можете добавить `instance Describable Int` без изменения определения `Int` — это невозможно в Java или C#, где тип должен явно реализовать интерфейс при объявлении.

```admonish note title="Заглядывая вперёд"
Классы типов — фундамент абстракций Haskell. В [главе 11](chapter11.md) мы познакомимся с `Functor`, `Applicative` и увидим, как классы типов позволяют определить единый интерфейс для преобразования значений внутри контейнеров (`Maybe`, списки, `IO` и др.).
```

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

### Проект ★☆☆

1. Определите класс `Describable` и напишите инстанс `Describable Priority`, который возвращает описание на русском языке (`"Низкий приоритет"`, `"Средний приоритет"`, `"Высокий приоритет"`).

    ```haskell
    class Describable a where
      describe :: a -> String

    instance Describable Priority where
      describe = ...
    ```

2. Напишите инстанс `Describable Status`, который возвращает `"К выполнению"`, `"В работе"`, `"Выполнено"`.

    ```haskell
    instance Describable Status where
      describe = ...
    ```

3. Напишите инстанс `Describable Task`, который форматирует задачу как `"[Высокий приоритет] Заголовок — В работе"`, используя `describe` для приоритета и статуса.

    ```haskell
    instance Describable Task where
      describe = ...
    ```

    ```text
    > describe (Task "Релиз" "" High InProgress)
    "[Высокий приоритет] Релиз — В работе"
    ```

### Проект ★★☆

4. Реализуйте функцию `compareTasks`, которая сравнивает задачи по бизнес-правилам: сначала по приоритету (High первый), затем по статусу (Todo первый).

    ```haskell
    compareTasks :: Task -> Task -> Ordering
    ```

    ```text
    > let t1 = Task "A" "" High Todo
    > let t2 = Task "B" "" High InProgress
    > compareTasks t1 t2
    LT
    ```

5. Реализуйте `sortTasks :: [Task] -> [Task]`, используя `compareTasks` и `sortBy` из `Data.List`.

    *Подсказка:* `sortBy :: (a -> a -> Ordering) -> [a] -> [a]`.

### Практика ★☆☆

6. Напишите функцию `allPriorities`, которая возвращает список всех значений `Priority`, используя `Enum` и `Bounded`.

    ```haskell
    allPriorities :: [Priority]
    ```

    *Подсказка:* `[minBound .. maxBound]`.

7. Напишите функцию `cyclePriority`, которая циклически переключает приоритет: `Low -> Medium -> High -> Low`.

    ```haskell
    cyclePriority :: Priority -> Priority
    ```

    *Подсказка:* используйте `succ`, `maxBound` и паттерн-матчинг или guards.

### Практика ★★☆

8. Определите `newtype Name = Name String` и выведите для него `Show` стратегией `stock` и `Eq` стратегией `newtype`. Объясните (в комментарии), чем отличаются результаты `show (Name "Alice")` при `stock` vs `newtype` deriving.

    ```haskell
    newtype Name = Name String
      deriving stock   (Show)
      deriving newtype (Eq)
    ```

9. Определите класс `Summarizable` с методами `summary :: a -> String` и `detailedSummary :: a -> String`, где `detailedSummary` по умолчанию вызывает `summary`. Напишите инстанс для `TaskStats`.

    ```haskell
    class Summarizable a where
      summary :: a -> String
      detailedSummary :: a -> String
      detailedSummary = summary  -- метод по умолчанию
    ```

## Заключение

Классы типов — центральный механизм полиморфизма в Haskell. Мы разобрали разницу между параметрическим полиморфизмом (одна реализация для всех типов) и ad-hoc полиморфизмом (разные реализации, выбираемые компилятором по типу). Стандартные классы `Eq`, `Ord`, `Show`, `Read`, `Enum`, `Bounded`, `Num` покрывают базовые операции, а собственные классы вроде `Describable` позволяют определять интерфейсы для нашего домена. Стратегии вывода `stock`, `newtype` и `anyclass` дают контроль над автоматической генерацией инстансов, а методы по умолчанию и минимальные полные определения сокращают количество шаблонного кода.

В [следующей главе](chapter06.md) мы перейдём к стандартным структурам данных — `Map`, `Set`, `Text` — и научимся эффективно хранить и искать задачи.

```admonish tip title="Для углубления"
- **Haskell MOOC** — [haskell.mooc.fi](https://haskell.mooc.fi/), лекция 4: «Type Classes, Instances, Deriving» и лекция 6: «Defining Your Own Type Classes».
- **MetaLamp** — [education.metalamp.ru](https://education.metalamp.ru/education/haskell/task-1), задания по классам типов.
- **Theorems for Free!** — оригинальная статья Вадлера о свободных теоремах: [www2.cs.sfu.ca/CourseCentral/831/burton/Notes/July14/free.pdf](https://www2.cs.sfu.ca/CourseCentral/831/burton/Notes/July14/free.pdf).
```
