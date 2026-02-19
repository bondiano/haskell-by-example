# Конкурентность и async

В предыдущей главе мы организовали трекер задач в модульную структуру. Теперь научим его работать быстрее. GHC предоставляет лёгкие потоки (green threads), а библиотеки `async` и `stm` — высокоуровневые примитивы для параллельного и конкурентного кода. В этой главе мы пройдём от низкоуровневого `forkIO` и `MVar` до `concurrently`, `race`, `mapConcurrently` и транзакционной памяти (STM). Завершим главу параллельным импортом задач с прогрессом и тайм-аутами.

## Лёгкие потоки

### Модель конкурентности GHC

GHC использует **лёгкие потоки** (green threads), которыми управляет рантайм. Они дешёвые: создание за микросекунды, ~1 КБ памяти на поток. Можно создать сотни тысяч потоков. Рантайм мультиплексирует их на OS-потоки (по числу ядер при компиляции с `-threaded`).

```admonish tip title="Знакомый аналог"
**Go:** горутины — практически та же модель. `go func()` ~ `forkIO action`.
**TypeScript:** `Promise.all()` ~ `mapConcurrently`. Но JS однопоточен (event loop), а GHC использует несколько ядер.
**Python:** `asyncio` — кооперативная многозадачность в одном потоке.
```

### forkIO и threadDelay

```haskell
import Control.Concurrent (forkIO, threadDelay)

forkIO :: IO () -> IO ThreadId
```

`forkIO` принимает IO-действие и запускает его в новом потоке, немедленно возвращая `ThreadId`. Вызывающий поток продолжает работу параллельно с дочерним:

```haskell
main :: IO ()
main = do
  putStrLn "Главный поток: старт"
  _ <- forkIO $ do
    putStrLn "Дочерний поток: начал"
    threadDelay 1_000_000  -- 1 секунда (микросекунды)
    putStrLn "Дочерний поток: завершился"
  putStrLn "Главный поток: продолжает"
  threadDelay 2_000_000
  putStrLn "Главный поток: конец"
```

`threadDelay n` приостанавливает поток на `n` микросекунд. `NumericUnderscores` позволяет писать `1_000_000`.

```admonish warning title="Проблема с forkIO"
Если главный поток завершится раньше дочернего — дочерний будет убит. `forkIO` не даёт способа получить результат или узнать об исключении. Для продакшн-кода используйте `async`.
```

## MVar

`MVar a` — мутабельная ячейка, которая может быть **пустой** или **заполненной**:

```haskell
import Control.Concurrent.MVar

newEmptyMVar :: IO (MVar a)          -- пустая ячейка
newMVar      :: a -> IO (MVar a)     -- заполненная
putMVar      :: MVar a -> a -> IO () -- положить (блокирует, если заполнена)
takeMVar     :: MVar a -> IO a       -- взять (блокирует, если пуста)
readMVar     :: MVar a -> IO a       -- прочитать без извлечения
```

Ключевое свойство блокировки: `takeMVar` ждёт, пока ячейка не станет заполненной, а `putMVar` — пока не станет пустой. Это делает `MVar` естественным примитивом синхронизации и передачи данных между потоками.

### MVar как канал для результата

```haskell
computeInThread :: IO ()
computeInThread = do
  resultVar <- newEmptyMVar
  _ <- forkIO $ do
    let result = sum [1..1_000_000 :: Int]
    putMVar resultVar result
  putStrLn "Ожидаем..."
  result <- takeMVar resultVar
  putStrLn $ "Результат: " <> show result
```

Дочерний поток вычисляет сумму и кладёт результат через `putMVar`. Главный поток блокируется на `takeMVar` ровно до тех пор, пока дочерний не завершится. Это простейший способ дождаться результата из другого потока.

### Потокобезопасный счётчик

Реализуем счётчик, который можно безопасно инкрементировать из нескольких потоков одновременно:

```haskell
type Counter = MVar Int

newCounter :: IO Counter
newCounter = newMVar 0

increment :: Counter -> IO ()
increment counter = do
  n <- takeMVar counter
  putMVar counter (n + 1)

getCount :: Counter -> IO Int
getCount = readMVar
```

```admonish warning title="Проблемы MVar"
`MVar` подвержен дедлокам, гонкам и утечкам (если поток упал, `MVar` может остаться пустым). Для сложной синхронизации предпочитайте STM или `async`.
```

## Библиотека async

### Зачем async

Библиотека **async** предоставляет высокоуровневый API поверх потоков: получение результата, проброс исключений, гарантии завершения.

```yaml
# package.yaml
dependencies:
  - async
```

### async и wait

```haskell
import Control.Concurrent.Async

async :: IO a -> IO (Async a)
wait  :: Async a -> IO a
```

`async` запускает действие в фоне и возвращает дескриптор `Async a`. `wait` блокируется до завершения и возвращает результат (или пробрасывает исключение). Ключевое отличие от `forkIO`: результат доступен, и исключение в дочернем потоке не теряется.

```haskell
example :: IO ()
example = do
  a1 <- async $ threadDelay 1_000_000 >> pure (42 :: Int)
  a2 <- async $ threadDelay 500_000   >> pure (17 :: Int)
  r1 <- wait a1
  r2 <- wait a2
  putStrLn $ "Результаты: " <> show r1 <> ", " <> show r2
```

Оба вычисления параллельны. `wait` пробрасывает исключения из дочернего потока.

### withAsync

Гарантирует отмену потока при выходе из блока:

```haskell
withAsync :: IO a -> (Async a -> IO b) -> IO b
```

Если вычисление завершится или бросит исключение, `withAsync` автоматически отменит дочерний поток. Используйте вместо `async`/`cancel` вручную — так не забудете прибраться.

### concurrently

Запускает два действия параллельно и возвращает оба результата:

```haskell
concurrently :: IO a -> IO b -> IO (a, b)
```

В отличие от `async`+`wait`, `concurrently` — высокоуровневая обёртка: не нужно вручную управлять дескрипторами. Оба действия стартуют одновременно, функция ждёт завершения обоих и возвращает пару результатов:

```haskell
fetchBoth :: IO ()
fetchBoth = do
  (users, tasks) <- concurrently fetchUsers fetchTasks
  putStrLn $ "Пользователей: " <> show (length users)
  putStrLn $ "Задач: " <> show (length tasks)
  where
    fetchUsers = threadDelay 1_000_000 >> pure ["Alice", "Bob"]
    fetchTasks = threadDelay 800_000   >> pure ["Задача 1", "Задача 2"]
```

Если одно из действий бросает исключение, второе отменяется.

### mapConcurrently

Применяет IO-действие к каждому элементу параллельно:

```haskell
mapConcurrently :: Traversable t => (a -> IO b) -> t a -> IO (t b)
```

Все действия запускаются одновременно; функция ждёт завершения всех и возвращает результаты в том же порядке, что и входная коллекция. При исключении в любом из потоков остальные отменяются.

```admonish tip title="Знакомый аналог"
**TypeScript:** `Promise.all(urls.map(url => fetch(url)))` ~ `mapConcurrently fetch urls`.
**Go:** `errgroup.Group` с горутинами.
**Python:** `asyncio.gather(...)`.
```

### race

Возвращает результат **первого** завершившегося действия, второе отменяет:

```haskell
race :: IO a -> IO b -> IO (Either a b)
```

Паттерн тайм-аута:

```haskell
withTimeout :: Int -> IO a -> IO (Maybe a)
withTimeout micros action =
  race (threadDelay micros) action >>= \case
    Left ()     -> pure Nothing
    Right result -> pure (Just result)
```

### Комбинирование

Примитивы `race`, `concurrently` и `withTimeout` хорошо компонуются. Вот реальный паттерн: попробовать два источника параллельно, взять первый ответ, но не ждать дольше 2 секунд:

```haskell
fetchWithFallback :: IO String
fetchWithFallback = do
  result <- withTimeout 2_000_000 $
    race fetchFromPrimary fetchFromBackup
  case result of
    Nothing          -> pure "Оба источника не ответили"
    Just (Left msg)  -> pure $ "Primary: " <> msg
    Just (Right msg) -> pure $ "Backup: " <> msg
  where
    fetchFromPrimary = threadDelay 1_000_000 >> pure "данные от Primary"
    fetchFromBackup  = threadDelay 1_500_000 >> pure "данные от Backup"
```

Primary ответит через 1 с, Backup — через 1.5 с. Тайм-аут — 2 с. Результат: `"Primary: данные от Primary"`, а Backup отменяется через `race`.

## STM — Software Transactional Memory

### Проблема с MVar

При нескольких разделяемых переменных `MVar` не обеспечивает атомарность:

```haskell
-- ОПАСНО: между двумя операциями состояние несогласованно
transfer :: MVar Int -> MVar Int -> Int -> IO ()
transfer from to amount = do
  balance <- takeMVar from
  putMVar from (balance - amount)
  -- другой поток видит неконсистентное состояние!
  balance2 <- takeMVar to
  putMVar to (balance2 + amount)
```

### TVar и atomically

**STM** использует **транзакции**: изолированные, автоматически перезапускаемые, композируемые.

```haskell
import Control.Concurrent.STM

newTVar    :: a -> STM (TVar a)
readTVar   :: TVar a -> STM a
writeTVar  :: TVar a -> a -> STM ()
modifyTVar :: TVar a -> (a -> a) -> STM ()
atomically :: STM a -> IO a
```

Все операции в `STM`, не в `IO`. `atomically` выполняет транзакцию атомарно.

### Атомарный перевод

```haskell
type Account = TVar Int

transfer :: Account -> Account -> Int -> STM ()
transfer from to amount = do
  balanceFrom <- readTVar from
  balanceTo   <- readTVar to
  writeTVar from (balanceFrom - amount)
  writeTVar to   (balanceTo + amount)
```

Другие потоки видят либо старое состояние обоих счетов, либо новое. Промежуточных нет.

```haskell
bankDemo :: IO ()
bankDemo = do
  alice <- newTVarIO 1000
  bob   <- newTVarIO 500
  mapConcurrently_ id
    [ atomically (transfer alice bob 100)
    , atomically (transfer bob alice 50)
    , atomically (transfer alice bob 200)
    ]
  aliceBalance <- readTVarIO alice
  bobBalance   <- readTVarIO bob
  putStrLn $ "Alice: " <> show aliceBalance  -- 750
  putStrLn $ "Bob: "   <> show bobBalance     -- 750
```

Три перевода выполняются параллельно, но итог детерминирован: суммарный баланс (1500) не меняется. Alice отдала 100 + 200 = 300 и получила 50; итого 750. Bob получил 100 + 200 = 300 и отдал 50; итого 750.

```admonish note title="Почему STM безопасна"
STM использует оптимистичную конкурентность: при фиксации рантайм проверяет, не изменились ли прочитанные переменные. Если изменились — перезапуск. Поэтому STM-транзакции не должны выполнять IO — перезапуск повторит побочные эффекты.
```

### retry и orElse

`retry` приостанавливает транзакцию до изменения прочитанных `TVar`:

```haskell
withdraw :: Account -> Int -> STM ()
withdraw account amount = do
  balance <- readTVar account
  if balance < amount
    then retry
    else writeTVar account (balance - amount)
```

`orElse` пробует первую транзакцию; при `retry` — вторую:

```haskell
withdrawFromEither :: Account -> Account -> Int -> STM ()
withdrawFromEither acc1 acc2 amount =
  withdraw acc1 amount `orElse` withdraw acc2 amount
```

`withdrawFromEither` попытается снять с `acc1`; если баланса недостаточно — `retry` сигнализирует о неудаче, и `orElse` переключается на `acc2`. Вся транзакция блокируется до тех пор, пока один из счетов не сможет выдать нужную сумму.

```admonish tip title="Знакомый аналог"
STM не имеет прямых аналогов в mainstream-языках. Ближайшие:
- **Go:** каналы + select (похожи на retry/orElse, но ограничены каналами).
- **Clojure:** `ref` + `dosync` — ближайший аналог.
Haskell-реализация STM считается эталонной благодаря композируемости и гарантиям типов.
```

### TChan — транзакционный канал

```haskell
newTChan   :: STM (TChan a)
writeTChan :: TChan a -> a -> STM ()
readTChan  :: TChan a -> STM a  -- блокирует, если пуст
```

`TChan` — транзакционная очередь FIFO. `readTChan` блокируется (через `retry`) до появления элемента. В отличие от каналов на `MVar`, несколько читателей и писателей могут работать с `TChan` одновременно без дедлоков.

## Проект: параллельный импорт задач

### Прогресс через TVar

Используем три `TVar`: хранилище задач, следующий доступный идентификатор и счётчик прогресса. Каждый файл обрабатывается в своём потоке через `mapConcurrently_`, обновления состояния атомарны через `atomically`.

```haskell
data ImportProgress = ImportProgress
  { ipTotal :: Int, ipCompleted :: Int, ipFailed :: Int, ipErrors :: [String]
  } deriving (Show)

importTasks :: [FilePath] -> IO (TaskStore, ImportProgress)
importTasks files = do
  progressVar <- newTVarIO (ImportProgress (length files) 0 0 [])
  storeVar    <- newTVarIO emptyStore
  nextIdVar   <- newTVarIO (1 :: TaskId)

  withAsync (monitorProgress progressVar) $ \_ ->
    mapConcurrently_ (importFile storeVar nextIdVar progressVar) files

  finalStore    <- readTVarIO storeVar
  finalProgress <- readTVarIO progressVar
  pure (finalStore, finalProgress)

importFile :: TVar TaskStore -> TVar TaskId -> TVar ImportProgress
           -> FilePath -> IO ()
importFile storeVar nextIdVar progressVar path = do
  result <- tryReadTaskFile path
  atomically $ case result of
    Left err -> modifyTVar progressVar $ \p ->
      p { ipFailed = ipFailed p + 1, ipErrors = err : ipErrors p
        , ipCompleted = ipCompleted p + 1 }
    Right tasks -> do
      forM_ tasks $ \task -> do
        nextId <- readTVar nextIdVar
        store  <- readTVar storeVar
        let (newStore, newId) = addTask task nextId store
        writeTVar storeVar newStore
        writeTVar nextIdVar newId
      modifyTVar progressVar $ \p -> p { ipCompleted = ipCompleted p + 1 }
```

Весь блок `atomically` выполняется неделимо: если два потока попытаются добавить задачи одновременно, STM разрешит конфликт, повторно выполнив одну из транзакций.

### Мониторинг прогресса

Параллельно с импортом `withAsync` запускает монитор, который каждые 200 мс печатает текущий прогресс. Функция `fix` реализует цикл без явной рекурсии.

```haskell
monitorProgress :: TVar ImportProgress -> IO ()
monitorProgress progressVar = fix $ \loop -> do
  progress <- readTVarIO progressVar
  putStrLn $ "Прогресс: " <> show (ipCompleted progress)
    <> "/" <> show (ipTotal progress)
    <> " (ошибок: " <> show (ipFailed progress) <> ")"
  if ipCompleted progress >= ipTotal progress
    then putStrLn "Импорт завершён!"
    else threadDelay 200_000 >> loop
```

### Импорт с тайм-аутом

`race` гарантирует, что импорт завершится не дольше заданного времени: победит либо `threadDelay` (тайм-аут), либо `importTasks` (успех).

```haskell
importWithTimeout :: Int -> [FilePath] -> IO (TaskStore, ImportProgress)
importWithTimeout timeoutMicros files = do
  result <- race (threadDelay timeoutMicros) (importTasks files)
  case result of
    Left ()              -> do
      putStrLn "Импорт прерван по таймауту!"
      pure (emptyStore, ImportProgress (length files) 0 0 ["Таймаут"])
    Right (store, progress) -> pure (store, progress)
```

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

### Проект ★☆☆

1. Реализуйте потокобезопасный счётчик на `MVar`. Проверьте, что 1000 параллельных инкрементов дают 1000.

    ```haskell
    type Counter = MVar Int
    newCounter :: IO Counter
    increment  :: Counter -> IO ()
    getCount   :: Counter -> IO Int
    ```

2. Реализуйте `withTimeout :: Int -> IO a -> IO (Maybe a)` через `race`.

### Проект ★★☆

3. Реализуйте параллельное скачивание с прогрессом:

    ```haskell
    data DownloadProgress = DownloadProgress { dpTotal :: Int, dpCompleted :: Int }
    downloadAll :: [String] -> (DownloadProgress -> IO ()) -> IO [String]
    ```

4. Реализуйте банковские переводы на STM. Проверьте инвариант: суммарный баланс не меняется.

    ```haskell
    type Account = TVar Int
    deposit  :: Account -> Int -> STM ()
    withdraw :: Account -> Int -> STM ()  -- retry при недостатке
    transfer :: Account -> Account -> Int -> STM ()
    ```

### Практика ★☆☆

5. Напишите `parallelMap :: (a -> b) -> [a] -> IO [b]` через `mapConcurrently` и `evaluate`.

6. Реализуйте конкурентный лог на `TChan`:

    ```haskell
    type Logger = TChan String
    newLogger  :: IO Logger
    logMessage :: Logger -> String -> IO ()
    flushLog   :: Logger -> IO [String]
    ```

### Практика ★★☆

7. Реализуйте `raceAll :: [IO a] -> IO a` — возвращает результат первого завершившегося действия.

8. Реализуйте worker pool: `N` воркеров обрабатывают задачи из `TChan`:

    ```haskell
    workerPool :: Int -> TChan (IO ()) -> IO ()
    ```

## Заключение

Конкурентность в GHC построена на лёгких потоках — дешёвых и управляемых рантаймом. Низкоуровневые `forkIO` и `MVar` подходят для простых случаев, но для продакшн-кода лучше использовать `async` с его `concurrently`, `race` и `mapConcurrently`. Когда нужна атомарность нескольких переменных, STM предоставляет композируемые транзакции: `TVar`, `retry`, `orElse`. Эти инструменты позволили нам построить параллельный импорт задач с прогрессом и тайм-аутами.

В [следующей главе](chapter17.md) мы создадим REST API с базой данных для трекера задач.

```admonish tip title="Для углубления"
- **Haskell MOOC** — [haskell.mooc.fi](https://haskell.mooc.fi/), лекция 16: «Concurrency».
- **async** — [hackage.haskell.org/package/async](https://hackage.haskell.org/package/async).
- **Parallel and Concurrent Programming in Haskell** (Simon Marlow) — [simonmar.github.io/pages/pcph.html](https://simonmar.github.io/pages/pcph.html).
- **Beautiful Concurrency** (Simon Peyton Jones) — [microsoft.com/en-us/research/wp-content/uploads/2016/02/beautiful.pdf](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/beautiful.pdf).
- **stm** — [hackage.haskell.org/package/stm](https://hackage.haskell.org/package/stm).
```
