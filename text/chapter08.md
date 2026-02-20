# Обработка ошибок

В предыдущих главах мы познакомились с `Maybe` для представления отсутствующих значений и написали CLI-трекер задач с `IORef`. Но трекер пока наивен: он не сообщает *причину* ошибки, а IO-операции могут завершиться исключением, которое мы не обрабатываем. В этой главе мы разберём `Either` для ошибок с информацией, собственные типы ошибок, цепочки операций с `Either`, исключения в `IO` (`try`, `catch`, `throwIO`) и добавим надёжную обработку ошибок в трекер.

## Maybe — значение, которого может не быть

Мы уже знаем `Maybe` из [главы 2](chapter02.md):

```haskell
data Maybe a = Nothing | Just a
```

`Maybe` отлично подходит, когда единственная причина неудачи очевидна из контекста:

```haskell
import qualified Data.Map.Strict as Map

lookupTask :: Int -> Map.Map Int Task -> Maybe Task
lookupTask = Map.lookup
```

Если `lookupTask 42 store` возвращает `Nothing`, причина ясна: задачи с таким идентификатором нет. Дополнительная информация не нужна.

Но иногда `Nothing` недостаточно. Представьте функцию `parseCommand :: String -> Maybe Command`. Если она вернула `Nothing`, пользователь не узнает, *что именно* пошло не так: неизвестная команда? неверный формат? пустой ввод?

## Either — ошибки с информацией

Для таких случаев в Haskell есть `Either`:

```haskell
data Either a b = Left a | Right b
```

По соглашению:

- `Left` — ошибка (содержит описание проблемы).
- `Right` — успех (содержит результат).

```admonish tip title="Знакомый аналог"
**Rust:** `Result<T, E>` — `Ok(value)` / `Err(error)`. Прямой аналог `Either`.
**Scala:** `Try[T]` / `Either[E, T]`.
**TypeScript:** часто используют `{ ok: true, value: T } | { ok: false, error: E }` — те же два варианта, но без поддержки компилятора.
```

Простой пример — парсинг команды:

```haskell
data Command
  = AddCmd String
  | CompleteCmd Int
  | ListCmd
  deriving (Show)

parseCommand :: String -> Either String Command
parseCommand input = case words input of
  ["add", title]     -> Right (AddCmd title)
  ["complete", nStr] -> case reads nStr of
    [(n, "")] -> Right (CompleteCmd n)
    _         -> Left ("Неверный номер задачи: " <> nStr)
  ["list"]           -> Right ListCmd
  []                 -> Left "Пустой ввод"
  (cmd : _)          -> Left ("Неизвестная команда: " <> cmd)
```

Теперь при ошибке пользователь получает конкретное сообщение, а не просто «ничего не найдено».

### Обработка Either через case

Результат `Either` обрабатывается сопоставлением с образцом:

```haskell
handleCommand :: String -> String
handleCommand input =
  case parseCommand input of
    Left err  -> "Ошибка: " <> err
    Right cmd -> "Команда: " <> show cmd
```

```text
> handleCommand "add Купить молоко"
"Команда: AddCmd \"Купить молоко\""

> handleCommand "delete 5"
"Ошибка: Неизвестная команда: delete"

> handleCommand ""
"Ошибка: Пустой ввод"
```

## Собственные типы ошибок

Строки в `Left` — плохая практика для серьёзных приложений. Лучше определить **алгебраический тип ошибок**:

```haskell
newtype TaskId = TaskId Int
  deriving (Show, Eq, Ord)

data AppError
  = TaskNotFound TaskId
  | DuplicateTask String
  | InvalidInput String
  | FileError String
  deriving (Show, Eq)
```

Преимущества перед строками:

- **Исчерпывающий `case`** — компилятор предупредит, если вы забыли обработать какой-то вариант ошибки.
- **Паттерн-матчинг** — можно реагировать на разные ошибки по-разному.
- **Типобезопасность** — нельзя случайно передать произвольную строку вместо ошибки.

Используем `AppError` в функциях трекера:

```haskell
import qualified Data.Map.Strict as Map

newtype TaskStore = TaskStore { unTaskStore :: Map.Map TaskId Task }
  deriving (Show)

addTaskSafe :: TaskId -> Task -> TaskStore -> Either AppError TaskStore
addTaskSafe tid task store
  | Map.member tid (unTaskStore store) = Left (DuplicateTask (taskTitle task))
  | otherwise = Right (TaskStore (Map.insert tid task (unTaskStore store)))

findTaskSafe :: TaskId -> TaskStore -> Either AppError Task
findTaskSafe tid store =
  case Map.lookup tid (unTaskStore store) of
    Nothing   -> Left (TaskNotFound tid)
    Just task -> Right task

completeTaskSafe :: TaskId -> TaskStore -> Either AppError TaskStore
completeTaskSafe tid store =
  case Map.lookup tid (unTaskStore store) of
    Nothing   -> Left (TaskNotFound tid)
    Just task ->
      let updated = task { taskStatus = Done }
      in  Right (TaskStore (Map.insert tid updated (unTaskStore store)))
```

### Отображение ошибок

Для пользователя ADT-ошибку нужно преобразовать в читаемое сообщение:

```haskell
showError :: AppError -> String
showError (TaskNotFound (TaskId n)) = "Задача #" <> show n <> " не найдена"
showError (DuplicateTask title)     = "Задача \"" <> title <> "\" уже существует"
showError (InvalidInput msg)        = "Неверный ввод: " <> msg
showError (FileError msg)           = "Ошибка файла: " <> msg
```

## Цепочки операций с Either

Допустим, мы хотим: найти задачу, проверить что она не завершена, и завершить её. Каждый шаг может вернуть ошибку:

```haskell
completeIfNotDone :: TaskId -> TaskStore -> Either AppError TaskStore
completeIfNotDone tid store =
  case findTaskSafe tid store of
    Left err   -> Left err
    Right task ->
      case taskStatus task of
        Done -> Left (InvalidInput "Задача уже завершена")
        _    ->
          let updated = task { taskStatus = Done }
          in  Right (TaskStore (Map.insert tid updated (unTaskStore store)))
```

Каждая операция с `Either` добавляет уровень вложенности. С тремя-четырьмя шагами код превращается в «лесенку»:

```haskell
-- Три последовательных операции — три уровня вложенности
processThreeSteps :: TaskId -> TaskStore -> Either AppError TaskStore
processThreeSteps tid store =
  case step1 tid store of
    Left err -> Left err
    Right store1 ->
      case step2 tid store1 of
        Left err -> Left err
        Right store2 ->
          case step3 tid store2 of
            Left err     -> Left err
            Right store3 -> Right store3
```

Этот паттерн повторяется: «если `Left` — пробросить ошибку дальше, если `Right` — передать значение в следующий шаг». Можно вынести его в вспомогательную функцию:

```haskell
andThen :: Either e a -> (a -> Either e b) -> Either e b
andThen (Left err) _ = Left err
andThen (Right x)  f = f x
```

Теперь цепочка выглядит чище:

```haskell
processThreeSteps :: TaskId -> TaskStore -> Either AppError TaskStore
processThreeSteps tid store =
  step1 tid store `andThen` \store1 ->
  step2 tid store1 `andThen` \store2 ->
  step3 tid store2
```

```admonish note title="Заглядывая вперёд: do-нотация для Either"
Функция `andThen` — это в точности оператор `>>=` (bind) для `Either`. В [главе 12](chapter12.md) мы узнаем, что `Either` — монада, и научимся писать такой код:

```haskell
completeIfNotDone :: TaskId -> TaskStore -> Either AppError TaskStore
completeIfNotDone tid store = do
  task <- findTaskSafe tid store
  when (taskStatus task == Done) $
    Left (InvalidInput "Задача уже завершена")
  updateStatus Done task store
```

Вместо вложенных `case` — линейный поток операций. `Either` — монада, и `do`-нотация автоматически пробрасывает ошибки вверх. Мы вернёмся к этому в главе 12.
```

### Мост между Maybe и Either

Часто нужно превратить `Maybe` в `Either`, добавив описание ошибки. Напишем вспомогательную функцию:

```haskell
maybeToEither :: e -> Maybe a -> Either e a
maybeToEither err Nothing  = Left err
maybeToEither _   (Just x) = Right x
```

С ней `findTaskSafe` становится однострочником:

```haskell
findTaskSafe :: TaskId -> TaskStore -> Either AppError Task
findTaskSafe tid store =
  maybeToEither (TaskNotFound tid) (Map.lookup tid (unTaskStore store))
```

```admonish warning title="Осторожно: парциальные функции"
Не используйте `fromJust`, `head`, `read` без проверки — они падают с ошибкой на пустом вводе:

- `fromJust Nothing` — `*** Exception: Maybe.fromJust: Nothing`
- `head []` — `*** Exception: Prelude.head: empty list`
- `read "abc" :: Int` — `*** Exception: Prelude.read: no parse`

Вместо них используйте безопасные аналоги: паттерн-матчинг на `Maybe`, `listToMaybe`, `readMaybe` из `Text.Read`.
```

## Исключения в IO

Чистые функции сигнализируют об ошибках через `Maybe` и `Either` — это *значения*, которые компилятор заставляет обработать. Но в `IO` ситуация другая: файл может не существовать, сеть может быть недоступна, диск может быть переполнен. Для таких случаев в Haskell есть **исключения**.

### Иерархия исключений

В Haskell все исключения наследуют от `SomeException`:

```text
SomeException
├── IOException        -- файлы, сеть, права доступа
├── ArithException     -- деление на ноль и т.д.
├── ErrorCall          -- вызов error "..."
└── ...                -- пользовательские типы
```

Наиболее частый тип — `IOException` (ошибки ввода-вывода).

### try — перехват исключения в Either

Функция `try` превращает IO-действие, которое может бросить исключение, в `Either`:

```haskell
import Control.Exception (try, IOException)

-- try :: Exception e => IO a -> IO (Either e a)

loadFile :: FilePath -> IO (Either String String)
loadFile path = do
  result <- try (readFile path) :: IO (Either IOException String)
  case result of
    Left err       -> pure (Left (show err))
    Right contents -> pure (Right contents)
```

Обратите внимание: нам нужна аннотация типа `:: IO (Either IOException String)`, чтобы указать, какой *тип* исключений мы ловим. Без неё GHC не знает, что перехватывать.

```text
> loadFile "существующий-файл.txt"
Right "содержимое файла..."

> loadFile "несуществующий-файл.txt"
Left "несуществующий-файл.txt: openFile: does not exist (No such file or directory)"
```

### catch — обработка исключения

`catch` перехватывает исключение и вызывает обработчик:

```haskell
import Control.Exception (catch, IOException)

loadFileWithDefault :: FilePath -> String -> IO String
loadFileWithDefault path def =
  readFile path `catch` handler
  where
    handler :: IOException -> IO String
    handler _ = pure def
```

### throwIO — выбрасывание исключения

`throwIO` бросает исключение из IO-кода. Для пользовательских исключений нужен экземпляр `Exception`:

```haskell
import Control.Exception (throwIO, Exception, try, IOException)

data AppException = ConfigMissing FilePath
  deriving (Show)

instance Exception AppException

loadConfig :: FilePath -> IO String
loadConfig path = do
  result <- try (readFile path) :: IO (Either IOException String)
  case result of
    Left _         -> throwIO (ConfigMissing path)
    Right contents -> pure contents
```

```admonish tip title="Знакомый аналог"
**JavaScript/Python:** `try { ... } catch (e) { ... }` — синтаксически похоже, но в Haskell есть принципиальное отличие: чистые функции *не могут* бросать исключения (кроме `error` и `undefined`, которых следует избегать). Исключения живут только в `IO`.
```

### Файловые операции трекера

Применим `try` к нашему трекеру — загрузка и сохранение задач:

```haskell
import Control.Exception (try, IOException)

loadTasksFromFile :: FilePath -> IO (Either AppError TaskStore)
loadTasksFromFile path = do
  result <- try (readFile path) :: IO (Either IOException String)
  case result of
    Left err       -> pure (Left (FileError (show err)))
    Right contents -> pure (parseTaskStore contents)

parseTaskStore :: String -> Either AppError TaskStore
parseTaskStore contents =
  case reads contents of
    [(store, "")] -> Right store
    _             -> Left (InvalidInput "Не удалось разобрать файл задач")

saveTasksToFile :: FilePath -> TaskStore -> IO (Either AppError ())
saveTasksToFile path store = do
  result <- try (writeFile path (show store)) :: IO (Either IOException ())
  case result of
    Left err -> pure (Left (FileError (show err)))
    Right () -> pure (Right ())
```

IO-исключение (`IOException`) превращается в значение нашего типа `AppError` и дальше обрабатывается единообразно с остальными ошибками.

## Когда что использовать

| Механизм | Когда применять | Примеры |
|----------|----------------|---------|
| `Maybe` | Единственная очевидная причина неудачи | `Map.lookup`, `listToMaybe`, `find` |
| `Either` | Нужна информация о причине ошибки; чистый код | Валидация, парсинг, бизнес-логика |
| Исключения (`try`/`catch`) | Непредсказуемые внешние сбои в `IO` | Файлы, сеть, системные вызовы |

Практическое правило: **чистый код** — только `Maybe` и `Either`; **граница IO** — `try` для перехвата, немедленная конвертация в `Either AppError`; **верхний уровень** — обработка `Either` и вывод сообщения пользователю.

```text
Внешний мир ─── try/catch ──→ Either AppError ──→ case ... of Left/Right
IOException                   AppError             паттерн-матчинг
```

## Обновляем трекер: надёжная обработка ошибок

Объединим всё в обновлённом цикле трекера:

```haskell
import Data.IORef
import Control.Exception (try, IOException)

runTracker :: IO ()
runTracker = do
  ref <- newIORef (TaskStore Map.empty)
  nextIdRef <- newIORef (TaskId 1)
  loop ref nextIdRef

loop :: IORef TaskStore -> IORef TaskId -> IO ()
loop storeRef nextIdRef = do
  putStr "> "
  input <- getLine
  case parseCommand input of
    Left err -> putStrLn ("Ошибка: " <> err)
    Right cmd -> do
      result <- executeCommand cmd storeRef nextIdRef
      case result of
        Left appErr -> putStrLn (showError appErr)
        Right msg   -> putStrLn msg
  loop storeRef nextIdRef

executeCommand
  :: Command -> IORef TaskStore -> IORef TaskId -> IO (Either AppError String)
executeCommand (AddCmd title) storeRef nextIdRef = do
  tid <- readIORef nextIdRef
  store <- readIORef storeRef
  let task = Task title "" Medium Todo
  case addTaskSafe tid task store of
    Left err -> pure (Left err)
    Right newStore -> do
      writeIORef storeRef newStore
      modifyIORef nextIdRef (\(TaskId n) -> TaskId (n + 1))
      pure (Right ("Добавлена задача #" <> show tid))

executeCommand (CompleteCmd n) storeRef _ = do
  store <- readIORef storeRef
  case completeTaskSafe (TaskId n) store of
    Left err -> pure (Left err)
    Right newStore -> do
      writeIORef storeRef newStore
      pure (Right ("Задача #" <> show n <> " завершена"))

executeCommand ListCmd storeRef _ = do
  store <- readIORef storeRef
  pure (Right (formatTasks (Map.toList (unTaskStore store))))
```

Архитектура следует паттерну **Functional Core, Imperative Shell** из [главы 7](chapter07.md): парсинг и бизнес-логика — чистые функции с `Either`, IO-слой — только `IORef` и перехват исключений, вывод ошибок — чистая функция `showError`.

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

### Проект ★☆☆

1. Реализуйте функцию `deleteTaskSafe`, которая удаляет задачу из хранилища. Если задачи с этим `TaskId` нет — возвращает `Left (TaskNotFound ...)`.

    ```haskell
    deleteTaskSafe :: TaskId -> TaskStore -> Either AppError TaskStore
    ```

    ```text
    > deleteTaskSafe (TaskId 1) exampleStore
    Right (TaskStore ...)

    > deleteTaskSafe (TaskId 99) exampleStore
    Left (TaskNotFound (TaskId 99))
    ```

2. Реализуйте функцию `updateTitle`, которая обновляет заголовок задачи. Если задача не найдена — `Left (TaskNotFound ...)`. Если новый заголовок пустой — `Left (InvalidInput "Заголовок не может быть пустым")`.

    ```haskell
    updateTitle :: TaskId -> String -> TaskStore -> Either AppError TaskStore
    ```

### Проект ★★☆

1. Реализуйте функцию `loadTasksFromFile`, которая читает файл и парсит содержимое. Используйте `try` для перехвата `IOException` и `readMaybe` (из `Text.Read`) для парсинга.

    ```haskell
    loadTasksFromFile :: FilePath -> IO (Either AppError TaskStore)
    ```

    *Подсказка:* перехватите `IOException` через `try`, затем используйте `case` на результате `readMaybe`.

### Практика ★☆☆

1. Реализуйте функцию `safeDiv`, которая делит два числа. При делении на ноль возвращает `Left`.

    ```haskell
    safeDiv :: Int -> Int -> Either String Int
    ```

    ```text
    > safeDiv 10 3
    Right 3

    > safeDiv 10 0
    Left "Деление на ноль"
    ```

2. Реализуйте функцию `parsePriority`, которая превращает строку в `Priority`. Допустимые значения: `"low"`, `"medium"`, `"high"` (без учёта регистра).

    ```haskell
    parsePriority :: String -> Either String Priority
    ```

    ```text
    > parsePriority "high"
    Right High

    > parsePriority "urgent"
    Left "Неизвестный приоритет: urgent"
    ```

### Практика ★★☆

1. Реализуйте функцию `chainOperations`, которая последовательно применяет список операций `TaskStore -> Either AppError TaskStore` к начальному хранилищу. При первой ошибке — остановка.

    ```haskell
    chainOperations :: [TaskStore -> Either AppError TaskStore]
                    -> TaskStore
                    -> Either AppError TaskStore
    ```

    *Подсказка:* используйте рекурсию и `case` на результате каждой операции. Или вспомните функцию `andThen` из этой главы и `foldl`.

## Заключение

`Maybe` подходит, когда причина неудачи очевидна из контекста; `Either` несёт информацию об ошибке и позволяет определить собственный ADT ошибок с исчерпывающим `case`. Цепочки операций с `Either` через вложенные `case` многословны — вспомогательная функция `andThen` убирает часть шаблонного кода, а в [главе 12](chapter12.md) мы увидим, что это в точности монадический `>>=`, и `do`-нотация сделает цепочки линейными. Исключения (`try`, `catch`, `throwIO`) живут в `IO` и предназначены для непредсказуемых внешних сбоев; на границе IO их стоит сразу конвертировать в `Either AppError`. Вложенные `case` — главная боль этой главы, и именно они формируют интуицию, которая в будущем поможет понять монады.

```admonish tip title="Для углубления"
- **Haskell Wiki: Error handling** — [wiki.haskell.org/Error](https://wiki.haskell.org/Error) — обзор подходов к ошибкам.
- **Matt Parsons: Exceptions Best Practices** — [www.fpcomplete.com/haskell/tutorial/exceptions](https://www.fpcomplete.com/haskell/tutorial/exceptions/) — практические рекомендации.
- **Control.Exception** — [hackage.haskell.org](https://hackage.haskell.org/package/base/docs/Control-Exception.html) — полная документация модуля исключений.
```
