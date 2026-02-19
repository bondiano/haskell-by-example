# Алгебраические типы и паттерн-матчинг

В [главе 2](chapter02.md) мы определили базовую модель трекера задач: типы `Priority`, `Status`, `Task` и несколько чистых функций. Теперь углубимся в систему типов Haskell и разберём, как разбирать значения по частям. В центре внимания — сопоставление с образцом (pattern matching), охранные выражения (guards), выражения `case`, алгебраические типы данных (ADT) с их суммами и произведениями, as-паттерны (`@`) и расширение `NamedFieldPuns` для компактной деструктуризации записей. К концу главы мы определим тип `TaskFilter` и реализуем функции `applyFilter` и `filterTasks`.

## Подготовка проекта

Код этой главы находится в `exercises/chapter03`. Соберите проект:

```text
$ cd exercises/chapter03
$ stack build
```

## Напоминание: типы из главы 2

В [главе 2](chapter02.md) мы определили:

```haskell
data Priority = Low | Medium | High deriving (Show, Eq, Ord)
data Status   = Todo | InProgress | Done deriving (Show, Eq, Ord)

data Task = Task
  { taskTitle       :: String
  , taskDescription :: String
  , taskPriority    :: Priority
  , taskStatus      :: Status
  } deriving (Show, Eq)

type TaskList = [Task]
newtype TaskId = TaskId Int deriving (Show, Eq, Ord)
```

Будем использовать их на протяжении всей главы.

## Сопоставление с образцом (pattern matching)

Сопоставление с образцом — главный механизм ветвления в Haskell. Вместо цепочек `if/else` мы описываем, как значение *выглядит*, и компилятор выбирает подходящую ветку.

### Литеральные и переменные паттерны

Простейшие паттерны — литералы и переменные:

```haskell
-- Литеральный паттерн: совпадает с конкретным значением
isZero :: Int -> Bool
isZero 0 = True
isZero _ = False

-- Переменный паттерн: связывает значение с именем
greet :: String -> String
greet name = "Привет, " <> name <> "!"
```

Символ `_` — **подстановочный паттерн** (wildcard). Он совпадает с любым значением, но не связывает его с именем. Используйте `_`, когда значение вам не нужно.

### Паттерны конструкторов

Конструкторы типов данных — главные «фигуры» в паттерн-матчинге. Вспомним функцию из главы 2:

```haskell
showPriority :: Priority -> String
showPriority Low    = "Низкий"
showPriority Medium = "Средний"
showPriority High   = "Высокий"
```

Здесь `Low`, `Medium`, `High` — паттерны конструкторов. Каждое уравнение проверяется сверху вниз; выполняется первое совпавшее.

```text
> showPriority High
"Высокий"
> showPriority Low
"Низкий"
```

```admonish tip title="Знакомый аналог"
**TypeScript:** `switch (priority) { case 'low': ...; case 'medium': ...; }`.
**Python:** `match priority: case Priority.LOW: ...` (Python 3.10+ structural pattern matching).
В Haskell паттерн-матчинг проверяется компилятором на **полноту** — если вы забыли ветку, GHC предупредит.
```

### Проверка полноты

Если убрать одну из веток, GHC выдаст предупреждение:

```text
> :{
  showPriority' :: Priority -> String
  showPriority' Low    = "Низкий"
  showPriority' Medium = "Средний"
  :}

<interactive>: warning: [-Wincomplete-patterns]
    Pattern match(es) are non-exhaustive
    In an equation for 'showPriority'':
        Patterns of type 'Priority' not matched: High
```

Это одно из главных преимуществ ADT: компилятор *знает* все возможные варианты.

```admonish warning title="Важно"
Всегда стремитесь к полному сопоставлению. Избегайте универсального `_` в конце, если можете перечислить все конструкторы — так компилятор предупредит вас при добавлении нового конструктора.
```

### Паттерны для списков

Списки тоже разбираются по паттернам. Список `[a]` имеет два конструктора: `[]` (пустой) и `x : xs` (голова и хвост):

```haskell
-- Количество задач в списке (для демонстрации, обычно используют length)
describeList :: TaskList -> String
describeList []    = "Список задач пуст"
describeList [t]   = "Одна задача: " <> taskTitle t
describeList (t:_) = "Несколько задач, первая: " <> taskTitle t
```

```text
> describeList []
"Список задач пуст"
> describeList [Task "Тест" "" Medium Todo]
"Одна задача: Тест"
```

Паттерн `[t]` — синтаксический сахар для `t : []`. Паттерн `(t:_)` совпадает со списком из одного или более элементов.

## Охранные выражения (guards)

Иногда недостаточно проверить структуру — нужно проверить условие. Для этого существуют **охранные выражения**:

```haskell
priorityLabel :: Priority -> String
priorityLabel p
  | p == High   = "!!! СРОЧНО !!!"
  | p == Medium = "Обычный приоритет"
  | otherwise   = "Низкий приоритет"
```

Охранные выражения записываются через `|` после аргументов. `otherwise` — синоним `True`, гарантирующий, что хотя бы одна ветка совпадёт.

Более практичный пример — классификация списка задач по размеру:

```haskell
describeWorkload :: TaskList -> String
describeWorkload tasks
  | n == 0    = "Нет задач — можно отдохнуть"
  | n <= 3    = "Немного задач (" <> show n <> ")"
  | n <= 10   = "Есть чем заняться (" <> show n <> " задач)"
  | otherwise = "Завал! " <> show n <> " задач"
  where
    n = length tasks
```

```text
> describeWorkload []
"Нет задач — можно отдохнуть"
> describeWorkload [Task "A" "" Low Todo, Task "B" "" High InProgress]
"Немного задач (2)"
```

Блок `where` вычисляет `n` один раз, и все охранные выражения используют его.

```admonish tip title="Знакомый аналог"
**TypeScript/Python:** `if/else if/else` цепочки.
Guards в Haskell — декларативная альтернатива: каждое условие — отдельная строка, без вложенности.
```

## Выражения `case`

Паттерн-матчинг через уравнения функций работает только на верхнем уровне определения. Внутри выражения используйте `case ... of`:

```haskell
statusEmoji :: Status -> String
statusEmoji s = case s of
  Todo       -> "[ ]"
  InProgress -> "[~]"
  Done       -> "[x]"
```

`case` — это **выражение**, а не оператор. Оно возвращает значение и может использоваться внутри других выражений:

```haskell
formatTaskLine :: Task -> String
formatTaskLine task =
  case taskStatus task of
    Done -> "[x] " <> taskTitle task
    _    -> "[ ] " <> taskTitle task
```

```text
> formatTaskLine (Task "Купить молоко" "" Low Done)
"[x] Купить молоко"
> formatTaskLine (Task "Написать отчёт" "" High Todo)
"[ ] Написать отчёт"
```

```admonish note title="Когда использовать case"
Используйте `case`, когда паттерн-матчинг нужен внутри выражения — например, внутри `where`, `let` или лямбда-функции. На верхнем уровне функции уравнения (equations) часто читаются проще.
```

### `LambdaCase`

С расширением `LambdaCase` (включено в нашем проекте) можно писать `case` ещё компактнее:

```haskell
statusEmoji :: Status -> String
statusEmoji = \case
  Todo       -> "[ ]"
  InProgress -> "[~]"
  Done       -> "[x]"
```

`\case` — это лямбда, принимающая один аргумент и сразу сопоставляющая его с образцами. Удобно при передаче в `map`, `filter` и другие функции высшего порядка:

```text
> map (\case { High -> "!"; _ -> "." }) [Low, High, Medium, High]
[".","!",".","!"]
```

## Алгебраические типы данных: сумма и произведение

Теперь, когда мы умеем разбирать значения, разберёмся с тем, как они устроены.

### Типы-произведения (product types)

Тип-произведение содержит *все* поля одновременно. `Task` — типичный пример:

```haskell
data Task = Task
  { taskTitle       :: String     -- И заголовок
  , taskDescription :: String     -- И описание
  , taskPriority    :: Priority   -- И приоритет
  , taskStatus      :: Status     -- И статус
  }
```

Называется «произведением», потому что множество возможных значений — это *декартово произведение* множеств значений каждого поля.

### Типы-суммы (sum types)

Тип-сумма содержит значение *одного из* конструкторов. `Priority` и `Status` — типы-суммы:

```haskell
data Priority = Low | Medium | High   -- Low ИЛИ Medium ИЛИ High
data Status   = Todo | InProgress | Done
```

«Сумма» — потому что количество возможных значений равно *сумме* значений каждого конструктора.

### Сочетание суммы и произведения

Сила ADT в том, что суммы и произведения свободно комбинируются. Определим тип для фильтрации задач:

```haskell
data TaskFilter
  = ByStatus Status            -- Фильтр по статусу
  | ByPriority Priority        -- Фильтр по приоритету
  | ByTitleContains String     -- Фильтр по подстроке в заголовке
  | AllTasks                   -- Без фильтрации
  deriving (Show, Eq)
```

`TaskFilter` — тип-сумма, но конструкторы `ByStatus`, `ByPriority` и `ByTitleContains` несут данные (это произведения). Такое сочетание невозможно выразить одним enum в TypeScript или Python — пришлось бы использовать union типы или наследование.

```admonish tip title="Знакомый аналог"
**TypeScript:**
`type TaskFilter = { kind: 'byStatus'; status: Status } | { kind: 'byPriority'; priority: Priority } | { kind: 'byTitle'; title: string } | { kind: 'all' }` — discriminated union.
**Rust:** `enum TaskFilter { ByStatus(Status), ByPriority(Priority), ... }` — практически идентичный синтаксис.
В Haskell ADT — фундамент языка, а не надстройка.
```

## Реализация фильтрации задач

Реализуем функцию, которая проверяет, удовлетворяет ли задача фильтру:

```haskell
import Data.List (isInfixOf)

applyFilter :: TaskFilter -> Task -> Bool
applyFilter AllTasks           _    = True
applyFilter (ByStatus s)       task = taskStatus task == s
applyFilter (ByPriority p)     task = taskPriority task == p
applyFilter (ByTitleContains sub) task = sub `isInfixOf` taskTitle task
```

Разберём каждое уравнение:

1. `AllTasks` — всегда `True`, задача игнорируется (`_`).
2. `ByStatus s` — конструктор разбирается, `s` связывается со значением `Status`.
3. `ByPriority p` — аналогично, `p` получает значение `Priority`.
4. `ByTitleContains sub` — `sub` получает строку-подстроку, `isInfixOf` проверяет вхождение.

Теперь фильтрация списка:

```haskell
filterTasks :: TaskFilter -> TaskList -> TaskList
filterTasks f = filter (applyFilter f)
```

Обратите внимание на частичное применение: `applyFilter f` — это функция `Task -> Bool`, которую мы передаём в `filter`.

```text
> let tasks = [Task "Купить молоко" "" Low Todo, Task "Написать отчёт" "" High InProgress, Task "Прочитать книгу" "" Medium Done]
> filterTasks (ByStatus Todo) tasks
[Task {taskTitle = "Купить молоко", ...}]
> filterTasks (ByPriority High) tasks
[Task {taskTitle = "Написать отчёт", ...}]
> filterTasks (ByTitleContains "Купить") tasks
[Task {taskTitle = "Купить молоко", ...}]
```

```admonish note title="Расширяемость"
Чтобы добавить новый критерий фильтрации, достаточно добавить конструктор в `TaskFilter` и ветку в `applyFilter`. Компилятор подскажет все места, где нужно обработать новый конструктор — это и есть «Making illegal states unrepresentable».
```

## As-паттерны (@)

Иногда нужно одновременно разобрать значение *и* сохранить его целиком. Для этого существуют as-паттерны:

```haskell
-- Логировать и вернуть задачу, если она срочная
logUrgent :: Task -> String
logUrgent task@Task{taskPriority = High, taskStatus = Todo} =
  "ВНИМАНИЕ: не начата срочная задача \"" <> taskTitle task <> "\""
logUrgent task = taskTitle task <> " — всё в порядке"
```

Конструкция `task@(...)` связывает `task` с *целым* значением, а `Task{taskPriority = High, taskStatus = Todo}` — деструктуризация с проверкой конкретных значений полей.

```text
> logUrgent (Task "Баг в проде" "" High Todo)
"ВНИМАНИЕ: не начата срочная задача \"Баг в проде\""
> logUrgent (Task "Рефакторинг" "" Low InProgress)
"Рефакторинг — всё в порядке"
```

As-паттерны работают с любыми типами, не только с записями:

```haskell
firstAndAll :: [a] -> Maybe (a, [a])
firstAndAll []       = Nothing
firstAndAll xs@(x:_) = Just (x, xs)
```

```text
> firstAndAll [1, 2, 3]
Just (1,[1,2,3])
```

## NamedFieldPuns и деструктуризация записей

В [главе 2](chapter02.md) мы уже видели `NamedFieldPuns`. Разберём подробнее.

### Без NamedFieldPuns

Стандартная деструктуризация записей выглядит так:

```haskell
showTaskVerbose :: Task -> String
showTaskVerbose (Task { taskTitle = title, taskPriority = prio, taskStatus = stat }) =
  "[" <> showPriority prio <> "] " <> title <> " (" <> showStatus stat <> ")"
```

Каждому полю нужно дать новое имя: `taskTitle = title`. Это многословно.

### С NamedFieldPuns

Расширение `NamedFieldPuns` позволяет опустить правую часть, если имя переменной совпадает с именем поля:

```haskell
showTaskCompact :: Task -> String
showTaskCompact Task{taskTitle, taskPriority, taskStatus} =
  "[" <> showPriority taskPriority <> "] "
    <> taskTitle
    <> " (" <> showStatus taskStatus <> ")"
```

`Task{taskTitle, taskPriority, taskStatus}` — сокращение для `Task{taskTitle = taskTitle, taskPriority = taskPriority, taskStatus = taskStatus}`. Поля становятся локальными переменными.

### RecordWildCards

Ещё радикальнее — расширение `RecordWildCards` с паттерном `{..}`:

```haskell
showTaskWild :: Task -> String
showTaskWild Task{..} =
  "[" <> showPriority taskPriority <> "] "
    <> taskTitle
    <> " (" <> showStatus taskStatus <> ")"
```

`Task{..}` вводит *все* поля записи как локальные переменные. Удобно, но менее явно — используйте с осторожностью.

```admonish warning title="RecordWildCards: осторожно"
`{..}` импортирует все поля, даже те, которые вы не используете. Это может привести к конфликтам имён и затруднить чтение кода. Предпочитайте `NamedFieldPuns` для явности.
```

## Комбинирование паттернов

Паттерны можно вкладывать друг в друга. Вот функция, которая находит первую незавершённую срочную задачу — она сочетает паттерн списка, as-паттерн, паттерн записи и guard:

```haskell
findUrgent :: TaskList -> Maybe Task
findUrgent [] = Nothing
findUrgent (task@Task{taskPriority = High, taskStatus = s} : rest)
  | s /= Done = Just task
  | otherwise  = findUrgent rest
findUrgent (_ : rest) = findUrgent rest
```

```text
> let tasks = [ Task "Рефакторинг" "" Low Todo
              , Task "Баг в проде" "" High Todo
              , Task "Код-ревью" "" High Done ]
> findUrgent tasks
Just (Task {taskTitle = "Баг в проде", ...})
```

Паттерн-матчинг также работает в `let` и `where` — например, для деструктуризации кортежей:

```haskell
taskSummary :: Task -> String
taskSummary task =
  let (label, icon) = case taskStatus task of
        Todo       -> ("к выполнению", "[ ]")
        InProgress -> ("в работе",     "[~]")
        Done       -> ("готово",       "[x]")
  in icon <> " " <> taskTitle task <> " — " <> label
```

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

### Проект ★☆☆

1. Реализуйте функцию `findEntryByStreet`, которая находит запись в адресной книге по названию улицы.

    ```haskell
    findEntryByStreet :: String -> AddressBook -> Maybe Entry
    ```

    *Подсказка:* используйте `listToMaybe`, `filter` и доступ к полю `street` через `address`.

2. Реализуйте функцию `entryExists`, которая проверяет, есть ли запись с заданным именем и фамилией.

    ```haskell
    entryExists :: String -> String -> AddressBook -> Bool
    ```

    *Подсказка:* используйте `any` или `findEntry` и проверку на `Nothing`.

### Проект ★★☆

3. Реализуйте функцию `removeDuplicates`, которая удаляет дубликаты из адресной книги. Дубликатами считаются записи с одинаковым именем и фамилией. Из группы дубликатов сохраняется первая запись.

    ```haskell
    removeDuplicates :: AddressBook -> AddressBook
    ```

    *Подсказка:* найдите функцию `nubBy` в модуле `Data.List` через `:info nubBy` в GHCi.

### Практика ★☆☆

4. Напишите функцию `describeStatus`, которая по `Status` возвращает описание с эмодзи (используйте паттерн-матчинг):

    ```haskell
    describeStatus :: Status -> String
    -- describeStatus Todo       = "[ ] К выполнению"
    -- describeStatus InProgress = "[~] В работе"
    -- describeStatus Done       = "[x] Готово"
    ```

5. Напишите функцию `isUrgent`, которая возвращает `True` для задач с приоритетом `High` и статусом, отличным от `Done`. Используйте guards.

    ```haskell
    isUrgent :: Task -> Bool
    ```

### Практика ★★☆

6. Напишите функцию `nextStatus`, которая «продвигает» статус задачи: `Todo -> InProgress -> Done -> Done`. Используйте `case`:

    ```haskell
    nextStatus :: Status -> Status
    ```

7. Напишите функцию `describeTasks`, которая принимает список задач и возвращает строку вида:

    ```text
    "3 задач(и), из них 1 срочных (High + не Done)"
    ```

    ```haskell
    describeTasks :: TaskList -> String
    ```

    *Подсказка:* используйте `show`, `length` и `filter` с функцией `isUrgent` из предыдущего упражнения (или напишите условие заново).

## Заключение

Паттерн-матчинг — центральный механизм Haskell для работы с данными. Мы разобрали литеральные, переменные и конструкторные паттерны, guards, выражения `case` и `LambdaCase`, as-паттерны (`@`), а также `NamedFieldPuns` и `RecordWildCards` для записей. Алгебраические типы данных — суммы и произведения — позволяют точно моделировать предметную область, а компилятор следит за полнотой сопоставления. В качестве практики мы определили `TaskFilter` и реализовали фильтрацию задач.

В [следующей главе](chapter04.md) мы перейдём к спискам, рекурсии и свёрткам — и научимся обрабатывать коллекции задач без явных циклов.

```admonish tip title="Для углубления"
- **Haskell MOOC** — [haskell.mooc.fi](https://haskell.mooc.fi/), лекции 3–4: pattern matching, рекурсия.
- **MetaLamp** — [education.metalamp.ru](https://education.metalamp.ru/education/haskell/task-1), задание 2: паттерн-матчинг и типы данных.
```
