# IO: взаимодействие с миром

Добро пожаловать во вторую часть книги! До сих пор весь наш код был **чистым**: функции принимали аргументы и возвращали результат, не взаимодействуя с внешним миром. Но реальные программы читают файлы, выводят текст на экран и получают ввод от пользователя. В этой главе мы разберёмся с типом `IO` и тем, почему в Haskell эффекты явно отражены в типах. Познакомимся с базовыми IO-действиями (`putStrLn`, `getLine`, `print`), do-нотацией, файловым вводом-выводом (`readFile`, `writeFile`), мутабельными ссылками `IORef` и архитектурным паттерном **Functional Core, Imperative Shell**. К концу главы наш трекер перестанет быть набором чистых функций — он станет полноценной интерактивной программой.

## Чистота и IO

### Зачем нужен тип IO

В [главе 1](chapter01.md) мы говорили, что функции в Haskell чистые: `sort :: [Int] -> [Int]` гарантированно не читает файлы и не выводит текст на экран. Но как тогда вообще взаимодействовать с внешним миром?

Ответ — через тип `IO`. Если функция выполняет побочные эффекты, это отражено в её типе:

```haskell
putStrLn :: String -> IO ()    -- выводит строку на экран
getLine  :: IO String          -- читает строку с клавиатуры
readFile :: FilePath -> IO String  -- читает содержимое файла
```

`IO a` можно прочитать как: **«действие, которое при выполнении может взаимодействовать с внешним миром и производит значение типа `a`»**.

- `IO ()` — действие, которое ничего полезного не возвращает (аналог `void`). Например, `putStrLn` выводит строку и возвращает `()` — пустой кортеж.
- `IO String` — действие, которое производит строку. Например, `getLine` читает ввод пользователя и возвращает его как `String`.

### IO отделяет чистый код от эффектов

Ключевая идея: компилятор видит разницу между чистой функцией и действием с эффектами. Функция с типом `Int -> Int` гарантированно не выполняет IO — это следует из типа. Если функции нужен доступ к внешнему миру, `IO` обязательно появится в сигнатуре.

```haskell
-- Чистая функция: всегда возвращает одинаковый результат
double :: Int -> Int
double x = x * 2

-- IO-действие: результат зависит от внешнего мира
askName :: IO String
askName = do
  putStrLn "Как вас зовут?"
  getLine
```

Вы не можете случайно вызвать `putStrLn` из чистой функции — компилятор это запретит. Это одно из главных преимуществ Haskell: глядя на тип функции, вы точно знаете, может ли она выполнять побочные эффекты.

```admonish tip title="Знакомый аналог"
Тип `IO a` напоминает `async` в JavaScript/TypeScript. Как `async`-функция возвращает `Promise<T>` вместо `T`, так IO-функция в Haskell возвращает `IO a` вместо `a`. И как `await` «извлекает» значение из `Promise`, оператор `<-` в do-нотации «извлекает» значение из `IO`.

Но есть важное отличие: в JS любая функция может выполнять побочные эффекты, а `async` — лишь конвенция для асинхронности. В Haskell `IO` — фундаментальная граница, которую компилятор строго контролирует.
```

## Простые IO-действия

Основные функции для ввода-вывода:

```haskell
putStrLn :: String -> IO ()       -- вывести строку с переводом строки
putStr   :: String -> IO ()       -- вывести строку без перевода строки
print    :: Show a => a -> IO ()  -- вывести любое значение (через show)
getLine  :: IO String             -- прочитать строку с клавиатуры
```

```text
> putStrLn "Привет!"
Привет!

> print [1, 2, 3]
[1,2,3]

> line <- getLine
Привет
> line
"Привет"
```

`print x` эквивалентно `putStrLn (show x)`. В GHCi можно использовать `<-` для «извлечения» значения из IO-действия. В обычном коде `<-` доступен внутри do-блока.

## do-нотация

### Последовательность действий

Чтобы выполнить несколько IO-действий подряд, используется **do-нотация**:

```haskell
greet :: IO ()
greet = do
  putStrLn "Как вас зовут?"
  name <- getLine
  putStrLn ("Привет, " <> name <> "!")
```

Разберём построчно:

1. `putStrLn "Как вас зовут?"` — выводит строку. Результат (тип `()`) нас не интересует, поэтому мы его не сохраняем.
2. `name <- getLine` — выполняет `getLine` (тип `IO String`) и **связывает** результат с переменной `name` (тип `String`). Оператор `<-` «извлекает» значение из IO.
3. `putStrLn ("Привет, " <> name <> "!")` — использует `name` в чистом выражении для конкатенации строк, затем выводит результат.

### `let` в do-блоке

Для привязки чистых значений (без IO) используется `let`:

```haskell
formatGreeting :: IO ()
formatGreeting = do
  putStr "Имя: "
  name <- getLine
  putStr "Возраст: "
  ageStr <- getLine
  let greeting = "Привет, " <> name <> "! Вам " <> ageStr <> " лет."
  putStrLn greeting
```

Обратите внимание на разницу:

- `name <- getLine` — извлекает значение из IO-действия (`IO String` -> `String`).
- `let greeting = ...` — привязывает результат чистого выражения. Никакого `in` в do-блоке не нужно.

### `pure` и `return`

Иногда нужно «обернуть» чистое значение в `IO`:

```haskell
pure   :: a -> IO a
return :: a -> IO a   -- синоним pure (по историческим причинам)
```

Оба делают одно и то же. В новом коде предпочитайте `pure`:

```haskell
getUserOrDefault :: IO String
getUserOrDefault = do
  putStr "Имя (пустая строка для 'Аноним'): "
  name <- getLine
  if null name
    then pure "Аноним"
    else pure name
```

Последнее выражение в do-блоке определяет возвращаемое значение. Если оно чистое, его нужно обернуть в `pure`.

```admonish note title="О монадах"
do-нотация — это синтаксический сахар, который работает не только с `IO`, но и с любым типом, реализующим интерфейс **монады**. Мы подробно разберём монады в [главе 12](chapter12.md). Пока достаточно понимать do-нотацию как способ записи последовательности IO-действий.
```

### Пример: простой калькулятор

```haskell
calculator :: IO ()
calculator = do
  putStr "Первое число: "
  x <- readLn :: IO Double
  putStr "Второе число: "
  y <- readLn :: IO Double
  putStrLn $ "Сумма: " <> show (x + y)
  putStrLn $ "Произведение: " <> show (x * y)
```

`readLn :: IO Double` читает строку и парсит её. Если ввести не число, программа упадёт с ошибкой (обработку ошибок мы изучим в [главе 8](chapter08.md)).

## Работа с файлами

Стандартные функции для работы с файлами:

```haskell
readFile  :: FilePath -> IO String         -- прочитать файл целиком
writeFile :: FilePath -> String -> IO ()   -- записать строку в файл (перезаписывает)
appendFile :: FilePath -> String -> IO ()  -- дописать строку в конец файла
```

`FilePath` — это просто синоним для `String`:

```haskell
type FilePath = String
```

### Пример: подсчёт строк в файле

```haskell
countLines :: FilePath -> IO Int
countLines path = do
  content <- readFile path
  let n = length (lines content)
  pure n
```

Функция `lines :: String -> [String]` разбивает строку по переносам строк. Это **чистая** функция — она не в `IO`.

### Пример: копирование файла

```haskell
copyFile :: FilePath -> FilePath -> IO ()
copyFile from to = do
  content <- readFile from
  writeFile to content
  putStrLn $ "Скопировано: " <> from <> " -> " <> to
```

```admonish warning title="Кодировки"
Функция `readFile` из `Prelude` работает с `String` (списком `Char`). Для продакшн-кода рекомендуется использовать `Data.Text.IO.readFile` из пакета `text`, который корректно обрабатывает UTF-8 и значительно эффективнее. Мы перейдём на `Text` в следующих главах.
```

## IORef — мутабельные ссылки

Haskell — чистый язык, но иногда внутри `IO` нужно мутабельное состояние. Для этого существует `IORef` — ячейка памяти, которую можно читать и обновлять:

```haskell
import Data.IORef

newIORef    :: a -> IO (IORef a)        -- создать ссылку с начальным значением
readIORef   :: IORef a -> IO a          -- прочитать текущее значение
writeIORef  :: IORef a -> a -> IO ()    -- записать новое значение
modifyIORef :: IORef a -> (a -> a) -> IO ()  -- применить функцию к значению
```

### Пример: счётчик

```haskell
counter :: IO ()
counter = do
  ref <- newIORef (0 :: Int)
  modifyIORef ref (+ 1)
  modifyIORef ref (+ 1)
  modifyIORef ref (+ 1)
  val <- readIORef ref
  putStrLn $ "Счётчик: " <> show val  -- "Счётчик: 3"
```

```admonish warning title="Не злоупотребляйте IORef"
`IORef` — полезный инструмент, но он нарушает принцип чистоты. Используйте его только когда это действительно необходимо (например, в main-цикле программы). Для большинства задач предпочтительнее передавать состояние явно через аргументы функций или использовать `State`-монаду (см. [главу 12](chapter12.md)).

Практическое правило: если можете решить задачу без `IORef` — решайте без него.
```

## Functional Core, Imperative Shell

Мы подошли к одному из важнейших архитектурных паттернов в Haskell — **Functional Core, Imperative Shell** (FCIS). Идея проста:

1. **Ядро** (Functional Core) — чистые функции, которые содержат всю бизнес-логику. Их легко тестировать, рефакторить и понимать.
2. **Оболочка** (Imperative Shell) — тонкий слой `IO`-кода, который занимается вводом-выводом и вызывает чистые функции ядра.

```text
┌─────────────────────────────────────────────┐
│           Imperative Shell (IO)             │
│                                             │
│  main, loop, чтение файлов, ввод/вывод,    │
│  IORef для состояния                        │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │        Functional Core (чистый)       │  │
│  │                                       │  │
│  │  parseCommand, applyFilter,           │  │
│  │  filterTasks, computeStats,           │  │
│  │  addTask, completeTask, deleteTask    │  │
│  │                                       │  │
│  │  Легко тестировать!                   │  │
│  │  Нет зависимостей от IO.             │  │
│  └───────────────────────────────────────┘  │
│                                             │
└─────────────────────────────────────────────┘
```

Принцип: **максимум кода — в чистом ядре, минимум — в IO-оболочке**. Оболочка лишь связывает ввод-вывод с чистой логикой.

### Почему это важно

- **Тестируемость.** Чистые функции тестируются без mock-объектов.
- **Предсказуемость.** Одинаковые аргументы — одинаковый результат.
- **Рефакторинг.** Изменение чистого ядра не затрагивает IO-оболочку и наоборот.

```admonish tip title="Знакомый аналог"
Паттерн FCIS используется не только в Haskell. В мире JavaScript это похоже на разделение бизнес-логики (pure reducers в Redux) и слоя эффектов (middleware, API-вызовы). В Clean Architecture — на разделение domain layer и infrastructure layer. Haskell просто делает это разделение **обязательным** благодаря системе типов.
```

## Проект: CLI трекер задач

Применим все знания к нашему сквозному проекту. Мы построим интерактивный CLI, который принимает команды пользователя и управляет хранилищем задач из [главы 6](chapter06.md).

### Тип команд (Functional Core)

Начнём с чистого ядра — типа команд и их парсера:

```haskell
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text

-- Типы из предыдущих глав
type TaskId = Int

data Command
  = CmdAdd Text Priority       -- добавить задачу
  | CmdComplete TaskId          -- отметить как выполненную
  | CmdDelete TaskId            -- удалить задачу
  | CmdList (Maybe TaskFilter)  -- показать задачи (с фильтром или все)
  | CmdHelp                     -- показать справку
  | CmdQuit                     -- выйти
  deriving (Show)
```

### Парсинг команд (Functional Core)

Парсер команд — чистая функция. Она не выполняет IO, а лишь анализирует строку:

```haskell
parseCommand :: String -> Either String Command
parseCommand input = case words input of
  ["add", title, priority] ->
    case parsePriority priority of
      Just p  -> Right (CmdAdd (Text.pack title) p)
      Nothing -> Left "Неизвестный приоритет. Используйте: low, medium, high"
  ["complete", idStr] ->
    case reads idStr of
      [(n, "")] -> Right (CmdComplete n)
      _         -> Left "Некорректный ID задачи"
  ["delete", idStr] ->
    case reads idStr of
      [(n, "")] -> Right (CmdDelete n)
      _         -> Left "Некорректный ID задачи"
  ["list"]     -> Right (CmdList Nothing)
  ["help"]     -> Right CmdHelp
  ["quit"]     -> Right CmdQuit
  []           -> Left ""
  _            -> Left "Неизвестная команда. Введите help для справки."

parsePriority :: String -> Maybe Priority
parsePriority "low"    = Just Low
parsePriority "medium" = Just Medium
parsePriority "high"   = Just High
parsePriority _        = Nothing
```

Обратите внимание: `parseCommand` возвращает `Either String Command`. `Left` содержит сообщение об ошибке, `Right` — распознанную команду. Это чистая функция — её легко тестировать:

```text
> parseCommand "add Купить_молоко high"
Right (CmdAdd "Купить_молоко" High)

> parseCommand "blah"
Left "Неизвестная команда. Введите help для справки."
```

### Выполнение команд (Functional Core + IO Shell)

Выполнение команды может быть разделено на чистую логику и IO-обёртку:

```haskell
-- Чистая функция: добавление задачи в хранилище
addTaskPure :: Text -> Priority -> TaskId -> TaskStore -> (TaskStore, TaskId)
addTaskPure title priority nextId store =
  let task = Task
        { taskTitle = title
        , taskDescription = ""
        , taskPriority = priority
        , taskStatus = Todo
        , taskTags = mempty
        }
      newStore = TaskStore (Map.insert nextId task (unTaskStore store))
  in (newStore, nextId + 1)

-- Чистая функция: удаление задачи
deleteTaskPure :: TaskId -> TaskStore -> TaskStore
deleteTaskPure tid (TaskStore m) = TaskStore (Map.delete tid m)

-- Чистая функция: отметить задачу как выполненную
completeTaskPure :: TaskId -> TaskStore -> Either String TaskStore
completeTaskPure tid (TaskStore m) =
  case Map.lookup tid m of
    Nothing   -> Left $ "Задача с ID " <> show tid <> " не найдена"
    Just task ->
      let updated = task { taskStatus = Done }
      in Right (TaskStore (Map.insert tid updated m))
```

### Главный цикл (Imperative Shell)

IO-оболочка — тонкий слой, который связывает ввод/вывод с чистым ядром:

```haskell
import Data.IORef

main :: IO ()
main = do
  ref <- newIORef (TaskStore Map.empty, 1 :: TaskId)
  putStrLn "Трекер задач. Введите help для справки."
  loop ref

loop :: IORef (TaskStore, TaskId) -> IO ()
loop ref = do
  putStr "> "
  hFlush stdout  -- принудительно вывести приглашение
  input <- getLine
  case parseCommand input of
    Left ""  -> loop ref  -- пустая строка — просто продолжаем
    Left err -> putStrLn err >> loop ref
    Right CmdQuit -> putStrLn "До свидания!"
    Right cmd -> executeCommand ref cmd >> loop ref
```

`hFlush stdout` нужен, чтобы приглашение `"> "` появилось до ожидания ввода (по умолчанию `stdout` буферизован по строкам). Функция `hFlush` из модуля `System.IO`.

### Выполнение команд (Imperative Shell)

```haskell
executeCommand :: IORef (TaskStore, TaskId) -> Command -> IO ()
executeCommand ref = \case
  CmdAdd title priority -> do
    (store, nextId) <- readIORef ref
    let (newStore, newId) = addTaskPure title priority nextId store
    writeIORef ref (newStore, newId)
    putStrLn $ "Добавлена задача #" <> show nextId

  CmdComplete tid -> do
    (store, nextId) <- readIORef ref
    case completeTaskPure tid store of
      Left err       -> putStrLn err
      Right newStore -> do
        writeIORef ref (newStore, nextId)
        putStrLn $ "Задача #" <> show tid <> " завершена"

  CmdDelete tid -> do
    (store, nextId) <- readIORef ref
    writeIORef ref (deleteTaskPure tid store, nextId)
    putStrLn $ "Задача #" <> show tid <> " удалена"

  CmdList _filter -> do
    (store, _) <- readIORef ref
    let tasks = Map.toAscList (unTaskStore store)
    if null tasks
      then putStrLn "Список задач пуст."
      else mapM_ printTask tasks

  CmdHelp -> mapM_ putStrLn
    [ "Доступные команды:"
    , "  add <название> <приоритет>  — добавить задачу"
    , "  complete <id>               — отметить как выполненную"
    , "  delete <id>                 — удалить задачу"
    , "  list                        — показать все задачи"
    , "  quit                        — выйти"
    ]

  CmdQuit -> pure ()  -- обрабатывается в loop

printTask :: (TaskId, Task) -> IO ()
printTask (tid, task) =
  putStrLn $ "  #" <> show tid <> " "
    <> showPriority (taskPriority task) <> " | "
    <> Text.unpack (taskTitle task)
    <> " [" <> showStatus (taskStatus task) <> "]"
```

Обратите внимание, как мало IO-кода: `executeCommand` лишь читает/пишет `IORef` и вызывает `putStrLn`. Вся логика — в чистых функциях.

### Полезные комбинаторы

В коде проекта мы использовали два полезных комбинатора:

- `mapM_ :: (a -> IO ()) -> [a] -> IO ()` — применяет IO-действие к каждому элементу списка. Вариант `mapM` (без подчёркивания) собирает результаты: `mapM :: (a -> IO b) -> [a] -> IO [b]`.
- `(>>) :: IO a -> IO b -> IO b` — последовательно выполняет два действия, отбрасывая результат первого. `putStrLn err >> loop ref` эквивалентно `do { putStrLn err; loop ref }`.

## Упражнения

### Проект ★☆☆

1. Добавьте команду `show <id>`, которая выводит подробную информацию о задаче (заголовок, приоритет, статус). Реализуйте чистую функцию `lookupTask :: TaskId -> TaskStore -> Maybe Task` и используйте её в `executeCommand`.

2. Добавьте команды `save <path>` и `load <path>`. При `save` — записывайте задачи в файл (по одной строке на задачу, в формате `id|title|priority|status`). При `load` — считывайте файл и восстанавливайте хранилище. Реализуйте чистые функции для сериализации/десериализации:

    ```haskell
    serializeStore :: TaskStore -> String
    parseStore     :: String -> Either String TaskStore
    ```

### Проект ★★☆

1. Реализуйте команду `undo`, которая отменяет последнее действие. Используйте `IORef` со стеком предыдущих состояний:

    ```haskell
    type AppState = (TaskStore, TaskId, [TaskStore])  -- store, nextId, history
    ```

    При каждом изменении сохраняйте предыдущее состояние в список (стек). При `undo` — восстанавливайте последнее сохранённое.

### Практика ★☆☆

1. Напишите программу `echo`, которая читает строки из stdin и выводит их обратно, пока пользователь не введёт `"quit"`:

    ```haskell
    echoLoop :: IO ()
    ```

2. Напишите функцию `interactiveSum :: IO ()`, которая запрашивает числа у пользователя (по одному) и после ввода пустой строки выводит их сумму.

### Практика ★★☆

1. Напишите программу, которая читает текстовый файл, нумерует каждую строку (начиная с 1) и записывает результат в новый файл:

    ```haskell
    numberLines :: FilePath -> FilePath -> IO ()
    ```

    Используйте чистую функцию для нумерации (`addNumbers :: String -> String`) и IO-обёртку для чтения/записи файлов. Формат: `"1: Привет\n2: Мир\n"`.

## Заключение

Тип `IO a` — это действие, которое может взаимодействовать с внешним миром и производит значение типа `a`. Базовые функции `putStrLn`, `getLine`, `print`, `readFile`, `writeFile` покрывают основные потребности ввода-вывода. do-нотация позволяет записывать последовательности действий: `<-` извлекает значение из IO, `let` связывает чистые значения. `IORef` даёт мутабельное состояние внутри IO, но злоупотреблять им не стоит — для большинства задач лучше передавать состояние явно. Паттерн **Functional Core, Imperative Shell** разделяет программу на чистое ядро с бизнес-логикой и тонкую IO-оболочку, что упрощает тестирование и рефакторинг.

В [следующей главе](chapter08.md) мы разберём обработку ошибок — что делать, когда файл не найден, ввод некорректен или операция невозможна. Мы познакомимся с `Maybe`, `Either` и научимся обрабатывать исключения в `IO`.

```admonish tip title="Для углубления"
- **Haskell MOOC** — [haskell.mooc.fi](https://haskell.mooc.fi/), лекция 8: «IO» — подробнее об IO-действиях и do-нотации.
- **Haskell MOOC** — [haskell.mooc.fi](https://haskell.mooc.fi/), лекция 11: «Working with Files» — работа с файлами и IORef.
```
