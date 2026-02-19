# Монады

В [главе 5](chapter05.md) мы освоили классы типов, в [главе 7](chapter07.md) — IO и do-нотацию, в [главе 8](chapter08.md) — обработку ошибок с `Either` и вложенными `case`, а в [главе 11](chapter11.md) — `Functor` и `Applicative`. Все эти нити сходятся здесь. Глава посвящена классу `Monad` — механизму **зависимых вычислений**, где каждый шаг определяется результатом предыдущего. Мы разберём `>>=` (bind) и do-нотацию (наконец-то поняв, во что она раскрывается), изучим конкретные монады (`Maybe`, `Either`, список, `IO`, `Reader`) и рефакторим трекер задач, заменив вложенные `case` монадическим стилем.

## Проблема: зависимые вычисления

### Applicative: независимые вычисления

В [главе 11](chapter11.md) мы видели, как `Applicative` позволяет комбинировать *независимые* вычисления:

```haskell
-- Каждый аргумент вычисляется независимо от других
createTask :: Maybe Task
createTask = Task
  <$> lookupTitle config      -- Может вернуть Nothing
  <*> lookupDescription config -- Может вернуть Nothing
  <*> lookupPriority config    -- Может вернуть Nothing
  <*> pure Todo
```

Все три поиска *независимы* друг от друга. `Applicative` собирает результаты, но ни один не может повлиять на следующий шаг. Но что, если нужно принять решение на основе промежуточного результата?

```haskell
-- Прочитать конфиг → на основе конфига выбрать файл → прочитать файл
processConfig :: IO String
processConfig = do
  configPath <- getLine                -- Шаг 1: получить путь
  config     <- readFile configPath    -- Шаг 2: зависит от шага 1!
  let output = processData config      -- Шаг 3: зависит от шага 2!
  pure output
```

Шаг 2 *зависит* от результата шага 1 — мы не знаем, какой файл читать, пока не получим путь. `Monad` даёт именно эту возможность: **выбирать следующее вычисление на основе результата предыдущего**.

```admonish note title="Иерархия: Functor → Applicative → Monad"
Каждый уровень добавляет новую возможность:
- **Functor** (`fmap`): преобразовать значение внутри контекста.
- **Applicative** (`<*>`): комбинировать *независимые* вычисления в контексте.
- **Monad** (`>>=`): *зависимые* вычисления, где следующий шаг определяется результатом предыдущего.

Каждый `Monad` — `Applicative`, а каждый `Applicative` — `Functor`.
```

## Класс Monad

### Определение

```haskell
class Applicative m => Monad m where
  (>>=)  :: m a -> (a -> m b) -> m b   -- «bind» (связывание)
  (>>)   :: m a -> m b -> m b           -- «then» (затем)
  return :: a -> m a                    -- обернуть значение в контекст

  -- Реализации по умолчанию:
  m >> k = m >>= \_ -> k
  return = pure
```

Ключевой оператор — `>>=` (произносится «bind»): возьми вычисление `m a`, передай результат в функцию `a -> m b`, которая *создаёт новое вычисление*. Именно эта функция обеспечивает «зависимость» — она *видит* результат предыдущего шага и решает, что делать дальше.

### Сравнение с fmap и <*>

```haskell
fmap  :: Functor f     => (a -> b)   -> f a -> f b   -- не влияет на контекст
(<*>) :: Applicative f => f (a -> b) -> f a -> f b   -- контексты независимы
(>>=) :: Monad m       => m a -> (a -> m b) -> m b   -- контекст зависит от значения
```

```admonish tip title="Знакомый аналог"
**JavaScript:** `>>=` — это `.then()` у Promise: `fetchUser(id).then(user => fetchPosts(user.name))`. Каждый `.then()` получает результат предыдущего шага и возвращает новый Promise.
**Scala/Kotlin:** `>>=` — это `.flatMap()`: `list.flatMap(x => List(x, x*2))`.
**Rust:** `>>=` — это `.and_then()` у `Option`/`Result`.
```

### Законы монад

Как `Functor` и `Applicative`, `Monad` подчиняется законам:

```haskell
-- 1. Левая единица: return не добавляет эффектов
return a >>= f  ≡  f a

-- 2. Правая единица: return не теряет эффектов
m >>= return  ≡  m

-- 3. Ассоциативность: порядок группировки не важен
(m >>= f) >>= g  ≡  m >>= (\x -> f x >>= g)
```

```admonish warning title="Распространённое заблуждение"
Monad — это **не** про побочные эффекты. Monad — паттерн *последовательных вычислений с контекстом*. `Maybe` — контекст возможного отсутствия. `Either` — контекст ошибки. `[]` — контекст множественных результатов. `IO` — контекст побочных эффектов. Побочные эффекты — лишь *один из* контекстов.
```

## do-нотация: полная картина

### Помните главу 7?

В [главе 7](chapter07.md) мы писали код в `IO` и использовали do-нотацию:

```haskell
main :: IO ()
main = do
  putStrLn "Как вас зовут?"
  name <- getLine
  putStrLn ("Привет, " <> name <> "!")
```

Тогда мы приняли do-нотацию как данность. Теперь разберём, что за ней стоит. do-нотация — **синтаксический сахар** для цепочки `>>=` и `>>`. Правила раскрытия:

| do-нотация | Раскрытие |
|---|---|
| `x <- action; ...` | `action >>= \x -> ...` |
| `action; ...` (без `<-`) | `action >> ...` |
| `let x = expr; ...` | `let x = expr in ...` |
| `action` (последнее) | `action` (как есть) |

Разберём пример из главы 7 шаг за шагом:

```haskell
-- do-нотация:
main :: IO ()
main = do
  putStrLn "Как вас зовут?"
  name <- getLine
  putStrLn ("Привет, " <> name <> "!")

-- Раскрытие:
main :: IO ()
main =
  putStrLn "Как вас зовут?" >>     -- Правило 2: нет <-, используем >>
  getLine >>= \name ->             -- Правило 1: name <- ..., используем >>=
  putStrLn ("Привет, " <> name <> "!")  -- Правило 4: последнее выражение
```

Ничего магического — просто удобная запись. И ключевой момент: do-нотация работает для *любого* типа с инстансом `Monad`, не только `IO`:

```haskell
-- do для Maybe:
safeDivide :: Int -> Int -> Maybe Int
safeDivide _ 0 = Nothing
safeDivide x y = Just (x `div` y)

calculation :: Maybe Int
calculation = do
  a <- safeDivide 100 5    -- Maybe Int
  b <- safeDivide a 4      -- Maybe Int, зависит от a!
  safeDivide b 2            -- Maybe Int, зависит от b!
-- Результат: Just 2

-- do для Either:
validateAge :: Int -> Either String Int
validateAge age
  | age < 0   = Left "Возраст не может быть отрицательным"
  | age > 150 = Left "Слишком большой возраст"
  | otherwise = Right age

registration :: Either String String
registration = do
  age <- validateAge 25
  let category = if age >= 18 then "взрослый" else "ребёнок"
  pure ("Зарегистрирован: " <> category)
-- Результат: Right "Зарегистрирован: взрослый"
```

```admonish tip title="Знакомый аналог"
**JavaScript:** do-нотация — это `async/await`. Как `await` — синтаксический сахар для `.then()`, так `<-` в do-блоке — синтаксический сахар для `>>=`. Разница в том, что `async/await` работает только с Promise, а do-нотация — с любой монадой.
```

## Maybe как монада

Вспомним паттерн из [главы 8](chapter08.md) — цепочка вычислений, каждое из которых может вернуть `Nothing`:

```haskell
lookupAndComplete :: TaskId -> TaskStore -> Maybe TaskStore
lookupAndComplete tid store =
  case Map.lookup tid (unTaskStore store) of
    Nothing   -> Nothing
    Just task ->
      case validateNotDone task of
        Nothing    -> Nothing
        Just task' -> Just (updateTask tid (task' { taskStatus = Done }) store)
```

Каждый `case` добавляет уровень вложенности — «лесенка».

### Решение: инстанс Monad для Maybe

```haskell
instance Monad Maybe where
  Nothing >>= _ = Nothing   -- Если Nothing, остановись
  Just x  >>= f = f x       -- Если Just, передай значение в f
```

Всего две строки — но они решают нашу проблему. Сравним два варианта записи:

```haskell
-- С >>=:
lookupAndComplete tid store =
  Map.lookup tid (unTaskStore store) >>= \task ->
  validateNotDone task >>= \task' ->
  Just (updateTask tid (task' { taskStatus = Done }) store)

-- С do-нотацией:
lookupAndComplete tid store = do
  task  <- Map.lookup tid (unTaskStore store)
  task' <- validateNotDone task
  pure (updateTask tid (task' { taskStatus = Done }) store)
```

Вложенности нет. Каждая строка — один шаг. При первом `Nothing` остальные не выполнятся.

## Either как монада

### Прощай, лесенка ошибок

`Either` работает аналогично `Maybe`, но вместо простого «нет значения» несёт информацию об ошибке:

```haskell
instance Monad (Either e) where
  Left  e >>= _ = Left e    -- Если ошибка, остановись и сохрани её
  Right x >>= f = f x       -- Если успех, передай значение в f
```

Перепишем вложенные `case` из [главы 8](chapter08.md) монадическим стилем. Для этого определим хелпер `note`, превращающий `Maybe` в `Either`:

```haskell
note :: e -> Maybe a -> Either e a
note err Nothing  = Left err
note _   (Just x) = Right x

-- Было: вложенные case → Стало: плоская цепочка
lookupAndComplete :: TaskId -> TaskStore -> Either AppError TaskStore
lookupAndComplete tid store = do
  task <- note (TaskNotFound tid) (Map.lookup tid (unTaskStore store))
  when (taskStatus task == Done)
    (Left (InvalidInput "Задача уже завершена"))
  pure (updateTask tid (task { taskStatus = Done }) store)
```

### Цепочка валидаций

```haskell
data AppError
  = TaskNotFound TaskId
  | InvalidInput String
  | PermissionDenied String
  deriving (Show, Eq)

validateAndAssign :: TaskId -> String -> TaskStore -> Either AppError TaskStore
validateAndAssign tid assignee store = do
  task <- note (TaskNotFound tid) (Map.lookup tid (unTaskStore store))
  when (taskStatus task == Done)
    (Left (InvalidInput "Нельзя назначить завершённую задачу"))
  when (null assignee)
    (Left (InvalidInput "Имя исполнителя не может быть пустым"))
  let updated = task { taskAssignee = Just assignee }
  pure (updateTask tid updated store)
```

Четыре проверки — и ни одного вложенного `case`. Первая ошибка прерывает цепочку.

## Список как монада

Список — монада **не-детерминированных вычислений**: каждый шаг может дать несколько результатов, и все комбинации исследуются:

```haskell
instance Monad [] where
  xs >>= f = concatMap f xs
  -- Для каждого элемента xs применяем f,
  -- получаем список списков, объединяем в один список
```

```haskell
-- Все пары (x, y), где x из [1,2,3], y из [10,20]
pairs :: [(Int, Int)]
pairs = do
  x <- [1, 2, 3]
  y <- [10, 20]
  pure (x, y)
-- Результат: [(1,10),(1,20),(2,10),(2,20),(3,10),(3,20)]
```

Раскрытие: `[1,2,3] >>= \x -> [10,20] >>= \y -> [(x,y)]` применяет `concatMap` дважды, порождая все 6 комбинаций.

### Связь со list comprehensions

List comprehension — синтаксический сахар для списковой монады. Запись `[(x, y) | x <- [1..3], y <- [10,20]]` эквивалентна do-нотации выше. Условия фильтрации соответствуют `guard` из `Control.Monad`:

```haskell
import Control.Monad (guard)

pythagorean :: Int -> [(Int, Int, Int)]
pythagorean n = do
  a <- [1..n]
  b <- [a..n]
  c <- [b..n]
  guard (a*a + b*b == c*c)
  pure (a, b, c)
-- pythagorean 20 = [(3,4,5),(5,12,13),(6,8,10),(8,15,17),(9,12,15)]
```

### Практический пример: генерация тестовых данных

```haskell
-- Все возможные комбинации задач для тестирования
testTasks :: [Task]
testTasks = do
  priority <- [Low, Medium, High]
  status   <- [Todo, InProgress, Done]
  let title = "Задача " <> show priority <> "/" <> show status
  pure (Task title "" priority status)
-- Результат: 9 задач (3 приоритета × 3 статуса)
```

## IO — монада, которую вы уже знаете

Всё это время, начиная с [главы 7](chapter07.md), вы писали монадический код! `IO` — монада, и do-нотация в `IO` работает по тем же правилам:

```haskell
-- Теперь вы понимаете, что это значит:
main :: IO ()
main = do
  putStrLn "Введите ID задачи:"   -- IO (), эффект
  input <- getLine                  -- IO String, >>=, результат в input
  let tid = read input :: Int       -- let, чистое вычисление
  putStrLn ("ID: " <> show tid)    -- IO (), зависит от tid (Monad!)
```

Раскроем:

```haskell
main :: IO ()
main =
  putStrLn "Введите ID задачи:" >>
  getLine >>= \input ->
  let tid = read input :: Int in
  putStrLn ("ID: " <> show tid)
```

`IO` — самая «обычная» монада. Её особенность — невозможность «убрать» контекст: нет функции `IO a -> a`.

```admonish note title="Почему IO «особая»"
Для `Maybe` есть `fromMaybe :: a -> Maybe a -> a` — можно извлечь значение.
Для `Either` есть `fromRight :: b -> Either a b -> b`.
Для `IO` такой функции нет (кроме `unsafePerformIO`, которая нарушает гарантии).
Это не ограничение монады — это *свойство типа IO*, обеспечивающее чистоту языка.
```

## Reader — монада для конфигурации

В реальных приложениях множество функций нуждаются в одном и том же контексте — конфигурации, подключении к БД, логгере:

```haskell
data AppConfig = AppConfig
  { defaultPriority :: Priority
  , maxTasks        :: Int
  , appName         :: String
  } deriving (Show)

-- Каждая функция принимает AppConfig явно — утомительно!
createDefaultTask :: AppConfig -> String -> Task
createDefaultTask config title = Task title "" (defaultPriority config) Todo

canAddTask :: AppConfig -> TaskStore -> Bool
canAddTask config store = Map.size (unTaskStore store) < maxTasks config
```

`AppConfig` передаётся повсюду вручную. `Reader` решает эту проблему, оборачивая функцию `r -> a` в монадический интерфейс:

```haskell
newtype Reader r a = Reader { runReader :: r -> a }
```

Вместо передачи конфигурации явно, мы *читаем* её из окружения:

```haskell
import Control.Monad.Reader (Reader, asks, runReader)

type App a = Reader AppConfig a

getDefaultPriority :: App Priority
getDefaultPriority = asks defaultPriority

getMaxTasks :: App Int
getMaxTasks = asks maxTasks

getAppName :: App String
getAppName = asks appName
```

Функция `asks` извлекает конкретное поле из окружения, а `ask` возвращает окружение целиком. Монадический интерфейс позволяет комбинировать Reader-вычисления в do-нотации:

```haskell
createDefaultTask :: String -> App Task
createDefaultTask title = do
  prio <- getDefaultPriority
  pure (Task title "" prio Todo)

canAddTask :: TaskStore -> App Bool
canAddTask store = do
  maxN <- getMaxTasks
  pure (Map.size (unTaskStore store) < maxN)

formatHeader :: App String
formatHeader = do
  name <- getAppName
  pure (name <> " — Трекер задач")
```

Запускаем, передав конфигурацию один раз через `runReader`:

```haskell
myConfig :: AppConfig
myConfig = AppConfig { defaultPriority = Medium, maxTasks = 100, appName = "TaskMaster" }

-- runReader formatHeader myConfig  ==>  "TaskMaster — Трекер задач"
-- runReader (createDefaultTask "Новая задача") myConfig  ==>  Task { ..., taskPriority = Medium, ... }
```

```admonish tip title="Знакомый аналог"
**OOP:** Reader — это dependency injection. Вместо того чтобы передавать зависимости в конструктор каждого класса, мы объявляем, что вычисление *зависит от окружения*, и предоставляем окружение один раз при запуске.
**React:** Reader — это `useContext`. Провайдер контекста — `runReader`, потребитель — `ask`/`asks`.
```

## Рефакторим трекер задач

Сравним «до» и «после» на примере операций трекера.

### До: вложенные case (глава 8)

Вспомним `transferTask` с тремя уровнями вложенности:

```haskell
transferTask :: TaskId -> TaskId -> TaskStore -> Either AppError TaskStore
transferTask fromId toId store =
  case Map.lookup fromId (unTaskStore store) of
    Nothing -> Left (TaskNotFound fromId)
    Just fromTask ->
      case Map.lookup toId (unTaskStore store) of
        Nothing -> Left (TaskNotFound toId)
        Just _toTask ->
          case taskStatus fromTask of
            Done -> Left (InvalidInput "Нельзя передать завершённую задачу")
            _    -> Right (TaskStore (Map.insert toId fromTask (unTaskStore store)))
```

### После: монадический стиль

```haskell
-- Вспомогательные функции
note :: e -> Maybe a -> Either e a
note err Nothing  = Left err
note _   (Just a) = Right a

lookupTask :: TaskId -> TaskStore -> Either AppError Task
lookupTask tid store =
  note (TaskNotFound tid) (Map.lookup tid (unTaskStore store))

ensureNotDone :: Task -> Either AppError ()
ensureNotDone task =
  when (taskStatus task == Done)
    (Left (InvalidInput "Задача уже завершена"))

-- Рефакторинг операций
completeTask :: TaskId -> TaskStore -> Either AppError TaskStore
completeTask tid store = do
  task <- lookupTask tid store
  ensureNotDone task
  pure (TaskStore
    (Map.insert tid (task { taskStatus = Done }) (unTaskStore store)))

transferTask :: TaskId -> TaskId -> TaskStore -> Either AppError TaskStore
transferTask fromId toId store = do
  fromTask <- lookupTask fromId store
  _toTask  <- lookupTask toId store
  ensureNotDone fromTask
  pure (TaskStore (Map.insert toId fromTask (unTaskStore store)))
```

Вложенность исчезла. Логика переиспользуется — `lookupTask` и `ensureNotDone` вынесены в хелперы. При первой ошибке (`Left`) цепочка прерывается автоматически. `transferTask` проверяет три условия, но код остаётся плоским.

### Полезные монадические функции

Модуль `Control.Monad` предоставляет комбинаторы:

```haskell
when   :: Applicative f => Bool -> f () -> f ()  -- действие по условию
unless :: Applicative f => Bool -> f () -> f ()  -- действие, если условие ложно
mapM   :: Monad m => (a -> m b) -> [a] -> m [b]  -- монадический map
forM   :: Monad m => [a] -> (a -> m b) -> m [b]  -- mapM с аргументами наоборот
foldM  :: Monad m => (b -> a -> m b) -> b -> [a] -> m b  -- монадическая свёртка
join   :: Monad m => m (m a) -> m a               -- убрать один слой
```

Пример `foldM` — завершить все задачи с заданным приоритетом:

```haskell
completeByPriority :: Priority -> TaskStore -> Either AppError TaskStore
completeByPriority prio store = do
  let taskIds = [ tid | (tid, task) <- Map.toList (unTaskStore store)
                      , taskPriority task == prio ]
  foldM (\s tid -> completeTask tid s) store taskIds
```

`foldM` применяет `completeTask` к каждому `tid`, передавая обновлённый `store` на каждом шаге. Если какой-то шаг вернёт `Left`, вся свёртка прекратится.

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

### Проект ★☆☆

1. Перепишите функцию `completeTask`, используя do-нотацию и `Either AppError`. Функция принимает `TaskId` и `TaskStore`, находит задачу, проверяет, что она не в статусе `Done`, и переводит её в `Done`.

    ```haskell
    completeTask :: TaskId -> TaskStore -> Either AppError TaskStore
    ```

2. Реализуйте функцию `deleteTask`, которая удаляет задачу по `TaskId`. Если задачи нет, верните `Left (TaskNotFound tid)`.

    ```haskell
    deleteTask :: TaskId -> TaskStore -> Either AppError TaskStore
    ```

    *Подсказка:* используйте `note` и `Map.delete`.

### Проект ★★☆

3. Реализуйте функцию `processCommands`, которая принимает `AppConfig` и список команд, и выполняет их последовательно, используя `Reader`:

    ```haskell
    data Command = AddCmd String | CompleteCmd TaskId

    processCommands :: [Command] -> TaskStore -> App TaskStore
    ```

    *Подсказка:* используйте `foldM` и `asks defaultPriority` для приоритета новых задач.

### Практика ★☆☆

4. Напишите функцию `safeHead`, которая безопасно извлекает первый элемент списка, и используйте её в монадической цепочке:

    ```haskell
    safeHead :: [a] -> Maybe a

    firstPlusSecond :: [Int] -> Maybe Int
    -- firstPlusSecond [3, 7, 1] = Just 10
    -- firstPlusSecond [3]       = Nothing
    -- firstPlusSecond []        = Nothing
    ```

    *Подсказка:* `safeHead xs` и `safeHead (drop 1 xs)` в do-нотации.

5. Напишите функцию `validateTask`, которая проверяет задачу по нескольким критериям и возвращает `Either String Task`:

    ```haskell
    validateTask :: Task -> Either String Task
    -- Проверки: заголовок не пустой, описание не длиннее 200 символов
    ```

### Практика ★★☆

6. Используя списковую монаду, напишите функцию `allTaskCombinations`, которая генерирует все возможные комбинации приоритетов и статусов:

    ```haskell
    allTaskCombinations :: [(Priority, Status)]
    -- Результат: [(Low,Todo),(Low,InProgress),(Low,Done),(Medium,Todo),...] — 9 пар
    ```

7. Реализуйте функцию `safeLookupChain`, которая по списку ключей последовательно ищет значения в `Map`, где каждое найденное значение используется как ключ для следующего поиска:

    ```haskell
    safeLookupChain :: Ord k => [k] -> Map k k -> Maybe k
    -- safeLookupChain ["a"] (Map.fromList [("a","b"),("b","c")]) = Just "b"
    -- safeLookupChain ["a","b"] (Map.fromList [("a","b"),("b","c")]) = Just "c"
    -- safeLookupChain ["a","x"] (Map.fromList [("a","b"),("b","c")]) = Nothing
    ```

    *Подсказка:* используйте `foldM` с `Map.lookup`.

## Заключение

Монады решают проблему, которую `Applicative` не покрывает: зависимые вычисления, где каждый шаг определяется результатом предыдущего. Оператор `>>=` связывает вычисления в цепочку, а do-нотация делает такой код читаемым — `<-` раскрывается в `>>=`, действие без `<-` — в `>>`. Конкретные монады дают разные «контексты»: `Maybe` — возможное отсутствие, `Either` — ошибки, список — не-детерминизм, `IO` — побочные эффекты, `Reader` — неявное окружение.

В [следующей главе](chapter13.md) мы столкнёмся с проблемой: что делать, когда нужно *комбинировать* несколько монад — например, `IO` + `Either` + `Reader`? Ответ — **монадные трансформеры** и библиотека `mtl`.

```admonish tip title="Для углубления"
- **Haskell MOOC** — [haskell.mooc.fi](https://haskell.mooc.fi/), лекция 13: «Monads» — подробный разбор с примерами.
- **Learn You a Haskell** — глава «A Fistful of Monads»: [learnyouahaskell.com/a-fistful-of-monads](http://learnyouahaskell.com/a-fistful-of-monads).
- **Typeclassopedia** — раздел о монадах: формальное описание с законами и интуицией.
```
