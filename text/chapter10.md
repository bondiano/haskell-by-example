# Асинхронные эффекты

## Цели главы

В этой главе мы познакомимся с конкурентностью в Haskell. Мы разберём лёгкие потоки (`forkIO`), синхронизацию через `MVar`, структурированную конкурентность с библиотекой `async` и транзакционную память (`STM`).

Проект главы — конкурентный обработчик: параллельное выполнение задач с ограничением и таймаутами.

## От `IO` к конкурентности

В предыдущей главе мы работали с `IO` последовательно: каждое действие ждало завершения предыдущего. Но многие задачи естественно параллельны:

- Скачать несколько файлов одновременно.
- Обработать данные, пока ожидаем ответ от сервера.
- Запустить вычисление с таймаутом.

В Haskell конкурентность встроена в рантайм. Потоки Haskell — *лёгкие* (green threads): рантайм мультиплексирует их на системные потоки ОС. Создание потока обходится в десятки байт памяти, а не мегабайты.

## `forkIO` — лёгкие потоки

`forkIO` запускает IO-действие в отдельном потоке:

```haskell
import Control.Concurrent (forkIO, threadDelay)

main :: IO ()
main = do
  forkIO $ do
    threadDelay 1_000_000  -- 1 секунда
    putStrLn "Поток 1: готово"
  forkIO $ do
    threadDelay 500_000    -- 0.5 секунды
    putStrLn "Поток 2: готово"
  putStrLn "Главный поток"
  threadDelay 2_000_000    -- ждём завершения
```

```text
Главный поток
Поток 2: готово
Поток 1: готово
```

`threadDelay` приостанавливает поток на заданное число микросекунд (1 секунда = 1\_000\_000).

Проблема `forkIO`: главный поток не ждёт дочерние. Если `main` завершится раньше, дочерние потоки будут убиты. Мы скоро увидим, как `async` решает эту проблему.

## `MVar` — синхронизированные переменные

`MVar a` — это ячейка, которая может быть *пустой* или содержать значение типа `a`. Операции:

```haskell
import Control.Concurrent.MVar

newEmptyMVar :: IO (MVar a)           -- создать пустую
newMVar      :: a -> IO (MVar a)      -- создать с начальным значением
takeMVar     :: MVar a -> IO a        -- взять (блокирует, если пусто)
putMVar      :: MVar a -> a -> IO ()  -- положить (блокирует, если полно)
```

`takeMVar` блокирует поток, пока ячейка пуста. `putMVar` блокирует, пока ячейка занята. Это делает `MVar` удобным примитивом синхронизации.

### Пример: ожидание результата

```haskell
import Control.Concurrent
import Control.Concurrent.MVar

compute :: MVar Int -> IO ()
compute result = do
  threadDelay 1_000_000
  putMVar result 42

main :: IO ()
main = do
  result <- newEmptyMVar
  forkIO (compute result)
  putStrLn "Ожидаем результат..."
  value <- takeMVar result    -- блокируется, пока compute не положит значение
  putStrLn ("Результат: " <> show value)
```

### `MVar` как мьютекс

`MVar ()` часто используется как мьютекс (mutex) — блокировка на критическую секцию:

```haskell
withLock :: MVar () -> IO a -> IO a
withLock lock action = do
  takeMVar lock    -- захватить
  result <- action
  putMVar lock ()  -- освободить
  return result
```

## Библиотека `async`

`forkIO` низкоуровневый: нет ожидания завершения, нет передачи исключений. Библиотека `async` (Simon Marlow) предоставляет *структурированную конкурентность*:

```haskell
import Control.Concurrent.Async
```

### `async` / `wait`

`async` запускает действие в потоке и возвращает хэндл `Async a`. `wait` ожидает результат:

```haskell
import Control.Exception (evaluate)

main :: IO ()
main = do
  a <- async (evaluate (fibSlow 35))
  b <- async (evaluate (fibSlow 36))
  x <- wait a
  y <- wait b
  putStrLn ("Результат: " <> show (x + y))
```

> **Важно:** здесь мы используем `evaluate`, а не `return` или `pure`. Выражение `return (fibSlow 35)` создаёт IO-действие, мгновенно возвращающее *thunk* — отложенное вычисление. Сам `fibSlow 35` выполнится только когда thunk будет вынужден (при `show`), то есть последовательно в главном потоке. `evaluate` заставляет вычислить аргумент до WHNF *прямо в потоке*, обеспечивая реальный параллелизм.

### `concurrently`

`concurrently` запускает два действия параллельно и ждёт оба:

```haskell
concurrently :: IO a -> IO b -> IO (a, b)
```

```haskell
(result1, result2) <- concurrently
  (readFile "file1.txt")
  (readFile "file2.txt")
```

Если одно действие бросает исключение, второе автоматически отменяется.

### `race`

`race` запускает два действия и возвращает результат *первого* завершившегося. Второе отменяется:

```haskell
race :: IO a -> IO b -> IO (Either a b)
```

Классическое применение — таймаут:

```haskell
withTimeout :: Int -> IO a -> IO (Maybe a)
withTimeout usec action = do
  result <- race (threadDelay usec) action
  case result of
    Left ()  -> return Nothing   -- таймер сработал первым
    Right a  -> return (Just a)  -- действие завершилось вовремя
```

### `mapConcurrently`

`mapConcurrently` — параллельный `mapM`:

```haskell
mapConcurrently :: Traversable t => (a -> IO b) -> t a -> IO (t b)
```

```haskell
-- Прочитать три файла параллельно
contents <- mapConcurrently readFile ["a.txt", "b.txt", "c.txt"]
```

### Сравнение: последовательно vs параллельно

```haskell
import Control.Exception (evaluate)
import Concurrent (fibSlow, timed)
import Control.Concurrent.Async (mapConcurrently)

main :: IO ()
main = do
  let inputs = [32, 33, 34, 35]

  (seqResults, seqTime) <- timed $
    mapM (\n -> evaluate (fibSlow n)) inputs

  (parResults, parTime) <- timed $
    mapConcurrently (\n -> evaluate (fibSlow n)) inputs

  putStrLn ("Последовательно: " <> show seqTime <> " с")
  putStrLn ("Параллельно:     " <> show parTime <> " с")
```

Обратите внимание на `evaluate` вместо `pure`: `pure (fibSlow n)` мгновенно вернёт thunk, и фактическое вычисление произойдёт позже — последовательно. `evaluate` гарантирует, что `fibSlow n` вычисляется до WHNF *внутри* потока, поэтому `mapConcurrently` действительно выполняет вычисления параллельно.

На многоядерной машине (с `+RTS -N`) параллельная версия будет значительно быстрее.

## STM — транзакционная память

`MVar` прост, но при работе с несколькими переменными легко получить дедлок. STM (Software Transactional Memory) решает эту проблему через *транзакции*:

```haskell
import Control.Concurrent.STM
```

### `TVar` — транзакционная переменная

```haskell
newTVarIO  :: a -> IO (TVar a)
readTVar   :: TVar a -> STM a
writeTVar  :: TVar a -> a -> STM ()
modifyTVar :: TVar a -> (a -> a) -> STM ()
```

Обратите внимание: `readTVar` и `writeTVar` работают в монаде `STM`, а не `IO`. Чтобы выполнить транзакцию, используется `atomically`:

```haskell
atomically :: STM a -> IO a
```

### Пример: перевод между счетами

```haskell
type Account = TVar Int

transfer :: Account -> Account -> Int -> STM ()
transfer from to amount = do
  balanceFrom <- readTVar from
  balanceTo   <- readTVar to
  writeTVar from (balanceFrom - amount)
  writeTVar to   (balanceTo + amount)

main :: IO ()
main = do
  alice <- newTVarIO 100
  bob   <- newTVarIO 50
  atomically (transfer alice bob 30)
  aliceBalance <- readTVarIO alice
  bobBalance   <- readTVarIO bob
  putStrLn ("Алиса: " <> show aliceBalance)  -- 70
  putStrLn ("Боб: "   <> show bobBalance)     -- 80
```

Транзакция `transfer` атомарна: либо оба счёта обновлены, либо ни один. Если другой поток параллельно читает те же `TVar`, STM автоматически повторит транзакцию при конфликте.

### `retry` и `orElse`

`retry` откладывает транзакцию до изменения одной из прочитанных `TVar`:

```haskell
withdrawIfEnough :: Account -> Int -> STM ()
withdrawIfEnough acc amount = do
  balance <- readTVar acc
  if balance < amount
    then retry          -- подождать, пока баланс увеличится
    else writeTVar acc (balance - amount)
```

`orElse` пробует первую транзакцию; если она вызовет `retry`, пробует вторую:

```haskell
orElse :: STM a -> STM a -> STM a
```

## `QSem` — ограничение конкурентности

Иногда нужно ограничить число одновременных задач (например, не открывать 10 000 HTTP-соединений). `QSem` — семафор из `base`:

```haskell
import Control.Concurrent.QSem

newQSem    :: Int -> IO QSem      -- создать с начальным значением
waitQSem   :: QSem -> IO ()       -- захватить (блокирует, если 0)
signalQSem :: QSem -> IO ()       -- освободить
```

Пример — ограничение до 3 параллельных задач:

```haskell
import Control.Concurrent.Async (mapConcurrently)
import Control.Concurrent.QSem

mapConcurrentlyLimited :: Int -> (a -> IO b) -> [a] -> IO [b]
mapConcurrentlyLimited n f xs = do
  sem <- newQSem n
  mapConcurrently (withSem sem . f) xs
  where
    withSem sem action = do
      waitQSem sem
      result <- action
      signalQSem sem
      return result
```

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

1. **(Лёгкое)** Реализуйте функцию `concurrentSum`, которая суммирует подсписки параллельно.

    ```haskell
    concurrentSum :: [[Int]] -> IO Int
    ```

    ```text
    > concurrentSum [[1, 2, 3], [4, 5], [6]]
    21
    ```

    *Подсказка:* используйте `mapConcurrently` — вычислите `sum` каждого подсписка параллельно, затем сложите результаты.

2. **(Среднее)** Реализуйте функцию `withTimeout`, которая запускает действие с ограничением по времени (в микросекундах).

    ```haskell
    withTimeout :: Int -> IO a -> IO (Maybe a)
    ```

    ```text
    > withTimeout 1_000_000 (return 42)
    Just 42
    > withTimeout 50_000 (threadDelay 1_000_000 >> return 42)
    Nothing
    ```

    *Подсказка:* используйте `race` из `Control.Concurrent.Async` и `threadDelay` из `Control.Concurrent`.

3. **(Среднее)** Реализуйте конкурентный подсчёт слов в нескольких файлах.

    ```haskell
    concurrentWordCount :: [FilePath] -> IO [(FilePath, Int)]
    ```

    ```text
    > writeFile "/tmp/a.txt" "один два три"
    > writeFile "/tmp/b.txt" "четыре пять"
    > concurrentWordCount ["/tmp/a.txt", "/tmp/b.txt"]
    [("/tmp/a.txt", 3), ("/tmp/b.txt", 2)]
    ```

    *Подсказка:* используйте `mapConcurrently`. Для каждого файла прочитайте содержимое (`readFile`), разбейте на слова (`words`) и подсчитайте длину.

4. **(Сложное)** Реализуйте `mapConcurrentlyLimited` — аналог `mapConcurrently`, но с ограничением максимального числа одновременных задач.

    ```haskell
    mapConcurrentlyLimited :: Int -> (a -> IO b) -> [a] -> IO [b]
    ```

    ```text
    > mapConcurrentlyLimited 2 (\x -> threadDelay 100_000 >> return (x * 2)) [1..5]
    [2, 4, 6, 8, 10]
    ```

    *Подсказка:* используйте `QSem` из `Control.Concurrent.QSem`. Создайте семафор с ёмкостью `n`, оберните каждую задачу в `waitQSem` / `signalQSem`, а запуск делегируйте `mapConcurrently`.

## Заключение

В этой главе мы:

- Познакомились с лёгкими потоками (`forkIO`) и синхронизацией через `MVar`.
- Освоили структурированную конкурентность с `async`: `concurrently`, `race`, `mapConcurrently`.
- Разобрали STM — транзакционную память для безопасной работы с разделяемым состоянием.
- Научились ограничивать конкурентность через `QSem`.

В следующей главе мы познакомимся с FFI (Foreign Function Interface) — вызовом C-функций из Haskell и работой с JSON через `aeson`.
