# Трансформеры и mtl

В [главе 12](chapter12.md) мы познакомились с монадами: `Maybe`, `Either`, `IO`, `Reader`. Каждая из них решает ровно одну задачу: `Maybe` моделирует отсутствие значения, `Either` — ошибку с описанием, `Reader` — доступ к окружению, `IO` — побочные эффекты.

Но что делать, если нужно **всё сразу**? Наш трекер задач требует и конфигурацию (`Reader`), и обработку ошибок (`Either`), и работу с файловой системой (`IO`). Эта глава покажет, как **трансформеры монад** (`ReaderT`, `ExceptT`, `StateT`) позволяют собрать несколько эффектов в единый стек, а библиотека **mtl** абстрагирует код от конкретного стека через классы `MonadReader`, `MonadError`, `MonadIO`. В итоге мы рефакторим трекер задач так, чтобы весь прикладной код работал в монаде `App`.

## Проблема: комбинирование эффектов

Допустим, мы хотим загрузить задачу из файла, проверить конфигурацию и вернуть результат. Наивный подход — вложить монады друг в друга:

```haskell
-- Нужен Reader для конфигурации...
getStorePath :: Reader AppConfig FilePath
getStorePath = asks configStorePath

-- ...и IO для файловой системы...
readFileContents :: FilePath -> IO String
readFileContents = readFile

-- ...и Either для ошибок
parseStore :: String -> Either AppError TaskStore
parseStore = ...
```

Попробуем соединить:

```haskell
loadStore :: AppConfig -> IO (Either AppError TaskStore)
loadStore config = do
  let path = runReader getStorePath config  -- вручную «запускаем» Reader
  contents <- readFileContents path          -- в IO
  pure (parseStore contents)                 -- оборачиваем Either в IO
```

Работает, но у нас уже нет единой монады. В каждой функции приходится вручную «разворачивать» и «заворачивать» результаты. Добавьте ещё одну задачу — скажем, обработку ошибок чтения файла — и код превращается в лестницу из `case`:

```haskell
loadAndProcess :: AppConfig -> IO (Either AppError TaskStore)
loadAndProcess config = do
  let path = runReader getStorePath config
  result <- try $ readFileContents path
  case result of
    Left (e :: IOException) -> pure (Left (StorageError (show e)))
    Right contents ->
      case parseStore contents of
        Left err    -> pure (Left err)
        Right store -> pure (Right store)
```

Три уровня вложенности для простейшей операции. При десятке операций код станет нечитаемым. Нам нужен способ **составить** эффекты в единую монаду.

## Трансформеры монад

**Трансформер монады** — обёртка, которая добавляет один эффект поверх существующей монады. Суффикс `T` означает «transformer»:

| Монада     | Трансформер | Что добавляет               |
|------------|-------------|------------------------------|
| `Reader r` | `ReaderT r` | Доступ к окружению `r`       |
| `Either e` | `ExceptT e` | Ошибки типа `e`              |
| `State s`  | `StateT s`  | Изменяемое состояние типа `s`|
| `Writer w` | `WriterT w` | Логирование (накопление `w`) |

Каждый трансформер принимает **внутреннюю монаду** как параметр и создаёт новую монаду, которая умеет «и то, и это».

### ReaderT — доступ к окружению

```haskell
newtype ReaderT r m a = ReaderT { runReaderT :: r -> m a }
```

`ReaderT r m a` — функция из `r` в `m a`. Если `m = IO`, получаем `ReaderT r IO a` — монаду, которая может и читать окружение `r`, и выполнять `IO`.

```haskell
import Control.Monad.Reader (ReaderT, runReaderT, ask, asks)

type ConfigReader a = ReaderT AppConfig IO a

printStorePath :: ConfigReader ()
printStorePath = do
  path <- asks configStorePath
  liftIO $ putStrLn ("Путь к хранилищу: " <> path)
```

### ExceptT — ошибки с контекстом

```haskell
newtype ExceptT e m a = ExceptT { runExceptT :: m (Either e a) }
```

`ExceptT e m a` — монада `m`, результат которой обёрнут в `Either e`. Ошибка прерывает вычисление, как `throw` в императивных языках, но **без исключений** — всё выражено в типах.

```haskell
import Control.Monad.Except (ExceptT, runExceptT, throwError, catchError)

type SafeIO a = ExceptT AppError IO a

safeDivide :: Double -> Double -> SafeIO Double
safeDivide _ 0 = throwError (InvalidInput "Деление на ноль")
safeDivide x y = pure (x / y)
```

### StateT — изменяемое состояние

```haskell
newtype StateT s m a = StateT { runStateT :: s -> m (a, s) }
```

`StateT s m a` — функция, которая принимает текущее состояние, выполняет вычисление в `m` и возвращает результат вместе с обновлённым состоянием.

```haskell
import Control.Monad.State (StateT, runStateT, get, put, modify)

type Counter a = StateT Int IO a

increment :: Counter ()
increment = modify (+1)

showCount :: Counter String
showCount = do
  n <- get
  liftIO $ putStrLn ("Текущее значение: " <> show n)
  pure (show n)
```

```admonish tip title="Знакомый аналог"
**Стек трансформеров** работает как **middleware в Express/Koa**: каждый слой добавляет возможность (логирование, авторизацию, обработку ошибок), а запрос проходит через все слои.
**ReaderT** ~ контейнер зависимостей (dependency injection): конфигурация доступна в любой точке без явной передачи.
**ExceptT** ~ `Result` в Rust или цепочка `.catch()` в Promise: ошибка «всплывает» автоматически.
```

## Строим стек для трекера

Определим типы конфигурации и ошибок:

```haskell
data AppConfig = AppConfig
  { configStorePath      :: FilePath
  , configDefaultPriority :: Priority
  } deriving (Show)

data AppError
  = TaskNotFound TaskId
  | DuplicateTask Text
  | InvalidInput Text
  | StorageError String
  deriving (Show, Eq)
```

Теперь соберём **стек трансформеров**. Нам нужны три эффекта: окружение, ошибки, ввод-вывод. Стек читается изнутри наружу:

```haskell
type App a = ReaderT AppConfig (ExceptT AppError IO) a
```

Разберём по слоям:

1. **IO** — в основании. Позволяет работать с файловой системой и консолью.
2. **ExceptT AppError** — обёртка над `IO`. Добавляет обработку ошибок типа `AppError`.
3. **ReaderT AppConfig** — внешний слой. Добавляет доступ к конфигурации `AppConfig`.

Визуально:

```text
ReaderT AppConfig                ← читаем конфигурацию
  └── ExceptT AppError           ← обрабатываем ошибки
        └── IO                   ← побочные эффекты
```

```admonish warning title="Порядок важен!"
`ReaderT AppConfig (ExceptT AppError IO)` **не то же самое**, что `ExceptT AppError (ReaderT AppConfig IO)`. В первом случае конфигурация доступна даже в обработчике ошибок. Во втором — ошибка может произойти до того, как конфигурация будет прочитана. Для большинства приложений первый порядок — правильный: конфигурация доступна везде, ошибки обрабатываются внутри.
```

## lift и liftIO

Когда мы пишем `do`-блок в `App`, операции `asks` и `throwError` доступны напрямую. Но как добраться до `IO`? Для этого существуют `lift` и `liftIO`.

### lift — один уровень вниз

`lift` «поднимает» операцию из внутренней монады на один уровень:

```haskell
class MonadTrans t where
  lift :: Monad m => m a -> t m a
```

В нашем стеке `lift` в `ReaderT` поднимает операцию из `ExceptT AppError IO`:

```haskell
-- throwError живёт в ExceptT, поднимаем в ReaderT:
throwInApp :: AppError -> App a
throwInApp err = lift (throwError err)
```

### liftIO — сразу до IO

`liftIO` «пробрасывает» `IO`-действие через любое количество слоёв:

```haskell
class Monad m => MonadIO m where
  liftIO :: IO a -> m a
```

Не нужно писать `lift . lift` — `liftIO` работает из любой глубины:

```haskell
printMessage :: String -> App ()
printMessage msg = liftIO $ putStrLn msg

getCurrentTime' :: App UTCTime
getCurrentTime' = liftIO getCurrentTime
```

Правило простое: для `IO`-действий **всегда** используйте `liftIO`. Для операций промежуточных слоёв — `lift`.

## mtl — абстракция над стеком

До сих пор наш код привязан к конкретному стеку `ReaderT AppConfig (ExceptT AppError IO)`. Что если мы захотим заменить `IO` на тестовую монаду? Или добавить `StateT`? Придётся менять сигнатуры **всех** функций.

Библиотека **mtl** (Monad Transformer Library) решает эту проблему через **классы типов**:

| Класс          | Ключевые методы                  | Что даёт                   |
|----------------|-----------------------------------|-----------------------------|
| `MonadReader r`| `ask`, `asks`, `local`            | Доступ к окружению `r`     |
| `MonadError e` | `throwError`, `catchError`        | Выбрасывание/ловля ошибок  |
| `MonadState s` | `get`, `put`, `modify`            | Чтение/запись состояния    |
| `MonadIO`      | `liftIO`                          | Доступ к `IO`              |

Вместо конкретного стека мы пишем **ограничения**:

```haskell
-- Конкретный стек (привязан к App):
getStorePathConcrete :: App FilePath
getStorePathConcrete = asks configStorePath

-- mtl-стиль (работает с любым совместимым стеком):
getStorePath :: MonadReader AppConfig m => m FilePath
getStorePath = asks configStorePath
```

Функция `getStorePath` в mtl-стиле работает с **любой** монадой, у которой есть доступ к `AppConfig`. Это может быть наш `App`, тестовый стек `ReaderT AppConfig Identity` или что угодно ещё.

```admonish note title="Полиморфизм стека"
mtl позволяет писать код, который **не знает** конкретного стека трансформеров. Функция с сигнатурой `(MonadReader AppConfig m, MonadError AppError m, MonadIO m) => ...` работает с любым стеком, предоставляющим эти три возможности. Тот же принцип, что классы типов в [главе 5](chapter05.md): программируем против интерфейса, а не реализации.
```

Перепишем основные операции трекера в mtl-стиле:

```haskell
loadStore
  :: (MonadReader AppConfig m, MonadError AppError m, MonadIO m)
  => m TaskStore
loadStore = do
  path <- asks configStorePath
  result <- liftIO $ try $ readFile path
  case result of
    Left (e :: IOException) -> throwError (StorageError (show e))
    Right contents -> case parseStore contents of
      Left err    -> throwError (StorageError err)
      Right store -> pure store

saveStore
  :: (MonadReader AppConfig m, MonadError AppError m, MonadIO m)
  => TaskStore -> m ()
saveStore store = do
  path <- asks configStorePath
  let contents = encodeStore store
  result <- liftIO $ try $ writeFile path contents
  case result of
    Left (e :: IOException) -> throwError (StorageError (show e))
    Right ()                -> pure ()
```

Ни одна функция не упоминает `ReaderT`, `ExceptT` или `IO` напрямую. Всё выражено через ограничения.

## Запуск стека: runReaderT, runExceptT

Стек трансформеров — «рецепт» вычисления. Чтобы его выполнить, нужно «снять» каждый слой, подав нужные аргументы.

Порядок разворачивания — **снаружи внутрь** (обратный порядку определения стека):

```haskell
runApp :: AppConfig -> App a -> IO (Either AppError a)
runApp config app =
  runExceptT (runReaderT app config)
--            ^^^^^^^^^^^^^^^^       снимаем ReaderT, подав config
--  ^^^^^^^^^                        снимаем ExceptT, получаем IO (Either ...)
```

Разберём по шагам:

1. `runReaderT app config :: ExceptT AppError IO a` — подаём конфигурацию, снимаем `ReaderT`.
2. `runExceptT (...) :: IO (Either AppError a)` — снимаем `ExceptT`, получаем `IO` с `Either` внутри.

Пример использования:

```haskell
main :: IO ()
main = do
  let config = AppConfig
        { configStorePath = "tasks.json"
        , configDefaultPriority = Medium
        }
  result <- runApp config $ do
    store <- loadStore
    let task = Task "Изучить трансформеры" "" High Todo
    newId <- addTaskApp task store
    liftIO $ putStrLn ("Добавлена задача #" <> show newId)
    pure newId
  case result of
    Left err -> putStrLn ("Ошибка: " <> show err)
    Right taskId -> putStrLn ("Успех! ID: " <> show taskId)
```

Таблица «снятия» для каждого трансформера:

| Трансформер     | Функция запуска                          | Результат           |
|-----------------|-------------------------------------------|----------------------|
| `ReaderT r m a` | `runReaderT :: ReaderT r m a -> r -> m a` | снимает Reader-слой  |
| `ExceptT e m a` | `runExceptT :: ExceptT e m a -> m (Either e a)` | снимает Except-слой |
| `StateT s m a`  | `runStateT :: StateT s m a -> s -> m (a, s)` | снимает State-слой |

## Рефакторим трекер задач

Соберём всё вместе. Полный пример трекера, работающего в монаде `App`:

```haskell
module TaskTracker where

import Control.Monad.Reader (ReaderT, runReaderT, asks)
import Control.Monad.Except (ExceptT, runExceptT, throwError)
import Control.Monad.IO.Class (liftIO)
import Control.Exception (try, IOException)
import Data.Text (Text)

-- Типы (определены ранее)
-- data AppConfig = ...
-- data AppError  = ...
-- data Task      = ...
-- data TaskStore = ...

-- Стек
type App a = ReaderT AppConfig (ExceptT AppError IO) a

runApp :: AppConfig -> App a -> IO (Either AppError a)
runApp config app = runExceptT (runReaderT app config)

-- Операции с хранилищем
getStorePath :: App FilePath
getStorePath = asks configStorePath

loadStore :: App TaskStore
loadStore = do
  path <- getStorePath
  result <- liftIO $ try $ readFile path
  case result of
    Left (e :: IOException) -> throwError (StorageError (show e))
    Right contents -> case parseStore contents of
      Left err    -> throwError (StorageError err)
      Right store -> pure store

saveStore :: TaskStore -> App ()
saveStore store = do
  path <- getStorePath
  let contents = encodeStore store
  result <- liftIO $ try $ writeFile path contents
  case result of
    Left (e :: IOException) -> throwError (StorageError (show e))
    Right ()                -> pure ()

-- Бизнес-логика
addTaskApp :: Task -> App TaskId
addTaskApp task = do
  store <- loadStore
  defaultPrio <- asks configDefaultPriority
  let task' = if taskPriority task == Low
              then task { taskPriority = defaultPrio }
              else task
  let newId = nextId store
  let store' = insertTask newId task' store
  saveStore store'
  liftIO $ putStrLn ("Задача добавлена: " <> show newId)
  pure newId

findTaskApp :: TaskId -> App Task
findTaskApp taskId = do
  store <- loadStore
  case lookupTask taskId store of
    Nothing   -> throwError (TaskNotFound taskId)
    Just task -> pure task

completeTaskApp :: TaskId -> App ()
completeTaskApp taskId = do
  task <- findTaskApp taskId
  store <- loadStore
  let task' = task { taskStatus = Done }
  let store' = updateTask taskId task' store
  saveStore store'
  liftIO $ putStrLn ("Задача завершена: " <> taskTitle task)
```

Сравните с «лестницей `case`» из начала главы. Теперь код линейный: каждая строка — одна операция, ошибки обрабатываются автоматически. Если `loadStore` вернёт ошибку, вся цепочка прервётся — точно как `throw` в императивном коде, но **без скрытых путей выполнения**: всё отражено в типе `App a`.

### Обработка ошибок внутри стека

Иногда нужно **поймать** ошибку, не прерывая вычисление. Для этого есть `catchError`:

```haskell
findTaskOrDefault :: TaskId -> Task -> App Task
findTaskOrDefault taskId defaultTask =
  findTaskApp taskId `catchError` handler
  where
    handler (TaskNotFound _) = pure defaultTask
    handler err              = throwError err  -- пробросить другие ошибки
```

Это аналог `try/catch`, но в чистом функциональном стиле.

### Локальное изменение окружения

`local` позволяет выполнить вычисление с изменённой конфигурацией:

```haskell
withCustomPath :: FilePath -> App a -> App a
withCustomPath path = local (\cfg -> cfg { configStorePath = path })

-- Использование:
importFromFile :: FilePath -> App TaskStore
importFromFile path = withCustomPath path loadStore
```

`local` не изменяет глобальную конфигурацию — изменение действует только внутри переданного вычисления. Это чистый аналог «с подменённой переменной среды».

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

### Проект ★☆☆

1. Реализуйте функцию `deleteTaskApp`, которая удаляет задачу из хранилища. Если задача не найдена, верните ошибку `TaskNotFound`.

    ```haskell
    deleteTaskApp :: TaskId -> App ()
    ```

    *Подсказка:* используйте `findTaskApp` для проверки существования, затем `loadStore`, удалите задачу и `saveStore`.

2. Реализуйте функцию `listTasksApp`, которая загружает хранилище и возвращает все задачи в виде списка `[(TaskId, Task)]`.

    ```haskell
    listTasksApp :: App [(TaskId, Task)]
    ```

    *Подсказка:* загрузите хранилище через `loadStore` и извлеките из него список задач.

### Проект ★★☆

3. Добавьте `StateT` для кэширования хранилища в памяти. Определите новый стек:

    ```haskell
    type AppWithCache a =
      ReaderT AppConfig (StateT (Maybe TaskStore) (ExceptT AppError IO)) a
    ```

    Реализуйте `loadStoreCached`, которая загружает хранилище из файла только при первом вызове, а при последующих возвращает закэшированное значение:

    ```haskell
    loadStoreCached :: AppWithCache TaskStore
    ```

    *Подсказка:* используйте `get` для проверки кэша. Если `Nothing` — загрузите из файла и обновите через `put`. Если `Just store` — верните `store`.

### Практика ★☆☆

4. Напишите функцию `safeHead`, которая возвращает первый элемент списка или выбрасывает ошибку через `MonadError`:

    ```haskell
    safeHead :: MonadError String m => [a] -> m a
    safeHead []    = throwError "Пустой список"
    safeHead (x:_) = pure x
    ```

    Проверьте, что она работает как в `Either String`, так и в `ExceptT String IO`.

5. Напишите функцию `askAndGreet`, которая читает имя из `MonadReader` и приветствует пользователя через `MonadIO`:

    ```haskell
    askAndGreet :: (MonadReader String m, MonadIO m) => m ()
    ```

    Проверьте её в `ReaderT String IO`.

### Практика ★★☆

6. Напишите мини-приложение — «калькулятор с историей». Определите стек:

    ```haskell
    type Calc a = StateT [String] (ExceptT String IO) a
    ```

    Реализуйте:

    ```haskell
    calcDivide :: Double -> Double -> Calc Double
    -- Деление на ноль → throwError
    -- Иначе → результат + запись в историю (modify)

    calcHistory :: Calc [String]
    -- Возвращает историю операций
    ```

    Напишите `runCalc` для запуска стека.

## Заключение

Монады не складываются наивным вложением — результат нечитаем. Трансформеры (`ReaderT`, `ExceptT`, `StateT`) решают эту проблему: каждый добавляет ровно один эффект поверх существующей монады. Собрав стек `ReaderT AppConfig (ExceptT AppError IO)`, мы получили монаду `App`, в которой прикладной код линеен и ошибки обрабатываются автоматически. Абстракции mtl (`MonadReader`, `MonadError`, `MonadIO`) отвязывают код от конкретного стека, открывая путь к тестированию и рефакторингу.

В [следующей главе](chapter14.md) мы займёмся **JSON и сериализацией** — научим трекер сохранять и загружать задачи в формате JSON с помощью библиотеки `aeson`.

```admonish tip title="Для углубления"
- **Haskell MOOC** — [haskell.mooc.fi](https://haskell.mooc.fi/), лекции 17–18: «Monad Transformers» и «IO in Practice».
- **mtl documentation** — [hackage.haskell.org/package/mtl](https://hackage.haskell.org/package/mtl) — документация библиотеки с примерами.
- **Monad Transformers Step by Step** — классическая статья Мартина Грабмюллера: [mgrabmueller/transformers-step-by-step](https://github.com/mgrabmueller/Transformers).
```
