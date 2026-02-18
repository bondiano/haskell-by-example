# Приключения с монадами

## Цели главы

В этой главе мы познакомимся с *трансформерами монад* — механизмом комбинирования монадических эффектов. Мы разберём `ReaderT`, `StateT`, `ExceptT` и библиотеку `mtl`, а затем применим всё это к созданию текстовой RPG-игры.

Проект главы — подземелье с комнатами, предметами, инвентарём и обработкой ошибок — полностью чистый и тестируемый.

## Проблема: несколько эффектов одновременно

В главе 9 мы работали с `IO` — единственной монадой для побочных эффектов. Но что, если нужны *несколько* эффектов одновременно?

- **Чтение конфигурации** — нужен доступ к настройкам, которые не меняются.
- **Изменяемое состояние** — нужно обновлять позицию игрока, инвентарь.
- **Обработка ошибок** — нужно реагировать на невозможные действия.

Каждый из этих эффектов — отдельная монада:

| Эффект | Монада | Операции |
|--------|--------|----------|
| Чтение окружения | `Reader r` | `ask`, `asks` |
| Изменяемое состояние | `State s` | `get`, `put`, `modify` |
| Ошибки | `Except e` | `throwError`, `catchError` |

Но как их скомбинировать?

## Трансформеры монад

*Трансформер монады* берёт монаду и добавляет к ней эффект:

| Трансформер | Добавляет | Базовая монада |
|-------------|-----------|----------------|
| `ReaderT r m` | Чтение `r` | `m` |
| `StateT s m` | Состояние `s` | `m` |
| `ExceptT e m` | Ошибки `e` | `m` |
| `WriterT w m` | Логирование `w` | `m` |

Трансформеры *стекируются*:

```haskell
type App a = ReaderT Config (StateT AppState (ExceptT AppError IO)) a
```

Этот стек означает: «вычисление с доступом к `Config`, изменяемым `AppState`, ошибками `AppError`, и IO».

### `ReaderT` — окружение

`ReaderT r m a` — вычисление в монаде `m` с доступом к значению типа `r`:

```haskell
import Control.Monad.Reader

type App a = ReaderT Config IO a

data Config = Config { appName :: String, debug :: Bool }

greet :: App ()
greet = do
  name <- asks appName       -- извлечь поле из конфига
  liftIO (putStrLn ("Привет от " <> name))

main :: IO ()
main = runReaderT greet (Config "MyApp" True)
```

Ключевые операции:

```haskell
ask    :: MonadReader r m => m r                    -- получить весь конфиг
asks   :: MonadReader r m => (r -> a) -> m a        -- применить функцию к конфигу
local  :: MonadReader r m => (r -> r) -> m a -> m a -- временно изменить конфиг
```

### `StateT` — изменяемое состояние

`StateT s m a` — вычисление в монаде `m` с состоянием типа `s`:

```haskell
import Control.Monad.State

type Counter a = StateT Int IO a

increment :: Counter ()
increment = modify (+ 1)

getCount :: Counter Int
getCount = get

main :: IO ()
main = do
  (count, finalState) <- runStateT (increment >> increment >> getCount) 0
  putStrLn (show count)       -- 2
  putStrLn (show finalState)  -- 2
```

Ключевые операции:

```haskell
get    :: MonadState s m => m s                    -- прочитать состояние
gets   :: MonadState s m => (s -> a) -> m a        -- применить функцию к состоянию
put    :: MonadState s m => s -> m ()              -- заменить состояние
modify :: MonadState s m => (s -> s) -> m ()       -- изменить состояние
```

### `ExceptT` — обработка ошибок

`ExceptT e m a` — вычисление в монаде `m`, которое может завершиться ошибкой типа `e`:

```haskell
import Control.Monad.Except

data AppError = NotFound String | Forbidden
  deriving stock Show

type App a = ExceptT AppError IO a

findUser :: String -> App String
findUser "admin" = return "Администратор"
findUser name    = throwError (NotFound name)

main :: IO ()
main = do
  result <- runExceptT (findUser "guest")
  case result of
    Left err   -> putStrLn ("Ошибка: " <> show err)
    Right user -> putStrLn user
```

Ключевые операции:

```haskell
throwError :: MonadError e m => e -> m a              -- бросить ошибку
catchError :: MonadError e m => m a -> (e -> m a) -> m a  -- поймать ошибку
```

## `mtl` — классы вместо конкретных типов

Библиотека `mtl` предоставляет *классы типов* для эффектов:

- `MonadReader r m` — «`m` поддерживает чтение `r`»
- `MonadState s m` — «`m` поддерживает состояние `s`»
- `MonadError e m` — «`m` поддерживает ошибки `e`»

Это позволяет писать функции, абстрагированные от конкретного стека:

```haskell
greet :: MonadReader Config m => m String
greet = do
  name <- asks appName
  return ("Привет, " <> name)
```

`greet` работает в *любой* монаде с `MonadReader Config`, не только в `ReaderT Config IO`.

## Исключения в IO

До сих пор мы обрабатывали ошибки через чистые типы: `Maybe`, `Either`, `ExceptT`. Но в `IO` существует ещё одна система — **runtime-исключения**.

### Две системы обработки ошибок

| | Чистая (`Either` / `ExceptT`) | IO (`Control.Exception`) |
|---|---|---|
| Видимость | В типах: `Either Error a` | Неявная: любое `IO a` может бросить |
| Предсказуемость | Компилятор заставляет обработать | Может вылететь неожиданно |
| Когда использовать | Бизнес-логика, валидация | I/O, сеть, системные вызовы |

Правило: для ожидаемых ошибок (неверный ввод, бизнес-правила) — `Either` / `ExceptT`. Для непредвиденных (файл не найден, разрыв соединения) — исключения IO.

### Иерархия исключений

Все исключения в Haskell наследуют от `SomeException`:

```text
SomeException
├── IOException          -- файловые и сетевые ошибки
├── AsyncException       -- прерывание потока, тайм-ауты
├── ErrorCall            -- error "сообщение"
└── ... пользовательские типы
```

Под капотом — экзистенциальные типы и `Typeable`, но на практике достаточно знать, что каждый тип исключения — экземпляр класса `Exception`.

### `try`, `catch`, `throwIO`

Модуль `Control.Exception` предоставляет три основных функции:

```haskell
import Control.Exception

-- Поймать исключение и вернуть Either
try :: Exception e => IO a -> IO (Either e a)

-- Поймать исключение обработчиком
catch :: Exception e => IO a -> (e -> IO a) -> IO a

-- Бросить исключение в IO
throwIO :: Exception e => e -> IO a
```

Пример — безопасное чтение файла:

```haskell
import Control.Exception (try)
import System.IO.Error (IOError)

safeReadFile :: FilePath -> IO (Either String String)
safeReadFile path = do
  result <- try (readFile path) :: IO (Either IOError String)
  case result of
    Left err  -> return (Left (show err))
    Right txt -> return (Right txt)
```

`try` перехватывает исключения *указанного типа*. Если мы ловим `IOError` — перехватятся только ошибки ввода-вывода. Другие исключения (например, `ErrorCall`) пролетят мимо.

### `bracket` — гарантия освобождения ресурсов

`bracket` гарантирует, что ресурс будет освобождён даже при исключении:

```haskell
bracket :: IO a          -- захват ресурса
        -> (a -> IO b)   -- освобождение (вызывается ВСЕГДА)
        -> (a -> IO c)   -- использование
        -> IO c
```

Пример:

```haskell
import System.IO (openFile, hClose, hGetContents, IOMode(..))

safeReadContents :: FilePath -> IO String
safeReadContents path =
  bracket (openFile path ReadMode) hClose hGetContents
```

Даже если `hGetContents` бросит исключение, `hClose` всё равно будет вызван. Стандартная функция `withFile` реализована через `bracket`.

### Собственные исключения

Для создания собственного типа исключения нужно:

1. Определить тип данных с `deriving Show`.
2. Объявить экземпляр `Exception`.

```haskell
import Control.Exception

data AppError
  = ConfigNotFound FilePath
  | ParseFailed String
  deriving stock Show

instance Exception AppError
```

Теперь `AppError` можно бросать и ловить:

```haskell
loadConfig :: FilePath -> IO Config
loadConfig path = do
  exists <- doesFileExist path
  unless exists $ throwIO (ConfigNotFound path)
  contents <- readFile path
  case parseConfig contents of
    Left err  -> throwIO (ParseFailed err)
    Right cfg -> return cfg
```

### `ExceptT` vs исключения IO

Когда использовать что:

- **`ExceptT`** — когда все ошибки известны заранее и являются частью бизнес-логики. Компилятор заставляет их обработать. Идеально для чистого кода (как наша RPG-игра ниже).
- **Исключения IO** — когда ошибки непредсказуемы (файл удалён, сеть упала). Используйте `try`/`catch` на границе приложения, преобразуя в `Either` для остального кода.

## Проект: текстовая RPG-игра

### Архитектура

Наша игра — чистое вычисление (без `IO`!):

```haskell
type Game a = ReaderT GameConfig (StateT GameState (ExceptT GameError Identity)) a
```

Три слоя:

1. **`ReaderT GameConfig`** — карта подземелья (комнаты, выходы). Не меняется.
2. **`StateT GameState`** — позиция игрока, инвентарь, здоровье. Меняется.
3. **`ExceptT GameError`** — ошибки (нет выхода, нет предмета). Прерывает выполнение.

Поскольку вместо `IO` используется `Identity`, вся игровая логика чистая и тестируемая:

```haskell
runGame :: GameConfig -> GameState -> Game a -> Either GameError (a, GameState)
runGame config state game =
  runIdentity $ runExceptT $ runStateT (runReaderT game config) state
```

### Типы

```haskell
data Direction = North | South | East | West

data Item = Lamp | Sword | Key | Potion

data RoomDef = RoomDef
  { roomDesc  :: String
  , roomExits :: Map Direction String
  }

data GameConfig = GameConfig
  { configRooms :: Map String RoomDef
  }

data GameState = GameState
  { playerRoom   :: String
  , inventory    :: [Item]
  , playerHealth :: Int
  , roomItems    :: Map String [Item]
  }

data GameError
  = NoExit Direction
  | ItemNotFound Item
  | GameOver String
```

### Разделение статики и динамики

Обратите внимание: структура комнат (`RoomDef`, `GameConfig`) — в `ReaderT` (не меняется). Предметы в комнатах (`roomItems`) — в `StateT` (меняются, когда игрок подбирает предмет).

Это важный паттерн: **конфигурацию** кладём в `ReaderT`, **состояние** — в `StateT`.

### Пример: осмотр комнаты

```haskell
look :: Game String
look = do
  name <- gets playerRoom           -- текущая комната из состояния
  config <- ask                     -- весь конфиг
  case getRoomDef name config of
    Nothing -> throwError (GameOver ("Неизвестная комната: " <> name))
    Just room -> do
      items <- gets (fromMaybe [] . Map.lookup name . roomItems)
      let exits = Map.keys (roomExits room)
      return $ roomDesc room
        <> "\nПредметы: " <> showItems items
        <> "\nВыходы: " <> showExits exits
```

### Пример: перемещение

```haskell
move :: Direction -> Game String
move dir = do
  name <- gets playerRoom
  config <- ask
  case getRoomDef name config of
    Nothing -> throwError (GameOver ("Неизвестная комната: " <> name))
    Just room ->
      case Map.lookup dir (roomExits room) of
        Nothing -> throwError (NoExit dir)
        Just nextRoom -> do
          modify (\s -> s { playerRoom = nextRoom })
          return ("Вы идёте на " <> showDirection dir <> ".")
```

### Тестирование

Поскольку `Game` не использует `IO`, тесты — чистые:

```haskell
it "перемещает на север" $ do
  let Right (_, st) = runGame exampleConfig initialState (move North)
  playerRoom st `shouldBe` "hall"

it "ошибка при невозможном направлении" $ do
  let result = runGame exampleConfig initialState (move East)
  result `shouldBe` Left (NoExit East)
```

### Композиция действий

Действия `Game` компонуются через `do`:

```haskell
adventure :: Game [String]
adventure = do
  msg1 <- look                  -- осмотреться
  msg2 <- pickUp Lamp           -- подобрать лампу
  msg3 <- move North            -- идти на север
  msg4 <- pickUp Sword          -- подобрать меч
  return [msg1, msg2, msg3, msg4]
```

Если любое действие бросит ошибку (`throwError`), вся цепочка прерывается — это поведение `ExceptT`.

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

Модуль `Game` предоставляет типы, `runGame`, `getRoomDef`, `exampleConfig`, `initialState`, а также форматирование `showItem`, `showDirection`, `showItems`, `showExits`.

1. **(Лёгкое)** Реализуйте `look` — описание текущей комнаты.

    ```haskell
    look :: Game String
    ```

    Результат должен содержать описание комнаты, список предметов и выходы. Используйте `gets` для доступа к состоянию, `ask` для конфига, `getRoomDef` для поиска комнаты.

    *Подсказка:* при отсутствии комнаты в конфиге бросьте `GameOver`.

2. **(Среднее)** Реализуйте `move` — перемещение в заданном направлении.

    ```haskell
    move :: Direction -> Game String
    ```

    Проверьте, есть ли выход из текущей комнаты в данном направлении (`roomExits`). Если есть — обновите `playerRoom` через `modify`. Если нет — бросьте `NoExit`.

3. **(Среднее)** Реализуйте `pickUp` — подбор предмета из текущей комнаты.

    ```haskell
    pickUp :: Item -> Game String
    ```

    Проверьте наличие предмета в `roomItems` для текущей комнаты. Если предмет есть — уберите из комнаты (`Map.adjust`, `delete`), добавьте в `inventory`. Если нет — бросьте `ItemNotFound`.

4. **(Сложное)** Реализуйте `useItem` — использование предмета из инвентаря.

    ```haskell
    useItem :: Item -> Game String
    ```

    Проверьте наличие предмета в `inventory`. Если есть — уберите из инвентаря и примените эффект:
    - `Potion` — увеличить `playerHealth` на 25 (максимум 100).
    - Остальные — вернуть описательное сообщение.

    Если предмета нет — бросьте `ItemNotFound`.

5. **(Среднее)** Реализуйте функцию `safeReadJSON`, которая безопасно читает JSON-файл, обрабатывая оба вида ошибок: `IOException` (файл не найден) и ошибку парсинга.

    ```haskell
    safeReadJSON :: FromJSON a => FilePath -> IO (Either String a)
    ```

    ```text
    > safeReadJSON "nonexistent.json" :: IO (Either String [Int])
    Left "nonexistent.json: openFile: does not exist ..."

    > safeReadJSON "valid.json" :: IO (Either String [Int])
    Right [1,2,3]
    ```

    *Подсказка:* используйте `try` из `Control.Exception` для перехвата `IOException`, затем `eitherDecode` из `Data.Aeson` для парсинга.

## Заключение

В этой главе мы:

- Познакомились с трансформерами монад: `ReaderT`, `StateT`, `ExceptT`.
- Разобрали стекирование трансформеров для комбинирования эффектов.
- Освоили `mtl`-классы: `MonadReader`, `MonadState`, `MonadError`.
- Разобрали исключения в IO: `try`, `catch`, `throwIO`, `bracket` и собственные типы исключений.
- Применили всё это к текстовой RPG-игре с чистой, тестируемой архитектурой.

В следующей главе мы перейдём к 2D-графике с библиотекой `gloss`.
