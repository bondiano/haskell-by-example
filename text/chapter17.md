# Веб-приложение с базой данных

Это кульминация нашего сквозного проекта. За предыдущие главы мы создали типы данных, бизнес-логику, модульную структуру и параллельный импорт. Теперь превратим трекер задач в полноценный REST API с базой данных. Глава охватывает веб-фреймворк **Servant** (типобезопасные API, автоматическая документация, генерация клиентов), **persistent** + **persistent-sqlite** (модели, миграции, CRUD-запросы), минимум **Template Haskell** для описания моделей, **ReaderT-паттерн** для передачи подключения к БД и обработку ошибок. Мы построим REST API с эндпоинтами `GET /tasks`, `POST /tasks`, `PUT /tasks/:id`, `DELETE /tasks/:id` и соберём полное приложение.

К концу главы у вас будет работающий HTTP-сервер с базой данных — полноценный бэкенд для трекера задач, где **типы гарантируют корректность API**.

## Servant — типобезопасный веб-фреймворк

### Почему Servant

В экосистеме Haskell есть несколько веб-фреймворков:

- **Scotty** — минималистичный, вдохновлён Ruby's Sinatra. Прост, но не типобезопасен.
- **Servant** — типобезопасный, API описывается на уровне типов. Мощный, автогенерация документации и клиентов.
- **Yesod** — полнофункциональный фреймворк с шаблонами, ORM и роутингом.

Мы используем **Servant** — он демонстрирует силу системы типов Haskell и является стандартом для современных API. API описывается как **тип**, и компилятор проверяет корректность обработчиков. Бонусы: автоматическая генерация документации (Swagger/OpenAPI), клиентских библиотек и mock-серверов.

```admonish tip title="Философия Servant"
В других фреймворках API — это набор строк-маршрутов, проверяемых в runtime. В Servant API — это **тип**, и компилятор гарантирует, что обработчики соответствуют описанию. Это типичный для Haskell подход: **«Если компилируется — вероятно, работает»**.
```

### Подключение

Добавьте зависимости в `package.yaml`:

```yaml
dependencies:
  - base >= 4.7 && < 5
  - servant
  - servant-server
  - warp           # HTTP-сервер
  - aeson          # JSON
  - text
```

### Первое приложение

```haskell
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

import Servant
import Network.Wai.Handler.Warp (run)
import Data.Text (Text)

-- Определение API как типа
type API = "hello" :> Capture "name" Text :> Get '[JSON] Text

-- Обработчик
server :: Server API
server = helloHandler
 where
  helloHandler :: Text -> Handler Text
  helloHandler name = pure ("Привет, " <> name <> "!")

-- Приложение
app :: Application
app = serve (Proxy :: Proxy API) server

main :: IO ()
main = do
  putStrLn "Сервер запущен на http://localhost:3000"
  run 3000 app
```

```text
$ stack run &
$ curl http://localhost:3000/hello/Haskell
"Привет, Haskell!"
```

Разберём:

- `type API = ...` — **описание API как типа**. Компилятор проверяет, что обработчик соответствует этому типу.
- `:>` — комбинатор «затем». `"hello" :> Capture "name" Text` означает: путь `/hello/:name`.
- `Capture "name" Text` — извлекает параметр из URL и конвертирует в `Text`.
- `Get '[JSON] Text` — GET-запрос, возвращает `Text` в формате JSON.
- `Server API` — тип обработчика, автоматически выводится из `API`. Для нашего API это `Text -> Handler Text`.
- `serve (Proxy :: Proxy API) server` — связывает описание API и обработчик, создаёт WAI `Application`.

```admonish tip title="Знакомый аналог"
**TypeScript (tRPC):** API описывается через типы, автогенерация клиента.
**Python (FastAPI):** Аннотации типов для автодокументации.
**Go (go-swagger):** Генерация кода из OpenAPI-спецификации.
Servant идёт дальше — API **является** типом, а не описывается через аннотации или spec-файлы.
```

### Комбинаторы маршрутов

Servant использует **type-level DSL** для описания маршрутов:

```haskell
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

import Servant

-- Один эндпоинт
type GetUser = "users" :> Capture "id" Int :> Get '[JSON] User

-- Несколько эндпоинтов (:<|> — OR)
type UsersAPI =
       "users" :> Get '[JSON] [User]
  :<|> "users" :> Capture "id" Int :> Get '[JSON] User
  :<|> "users" :> ReqBody '[JSON] User :> Post '[JSON] User

-- Префикс для всех маршрутов
type API = "api" :> "v1" :> UsersAPI
```

Операторы:
- `:>` — «затем» (chain)
- `:<|>` — «или» (альтернатива, несколько эндпоинтов)
- `Capture "name" Type` — параметр из URL
- `ReqBody '[JSON] Type` — тело запроса (JSON)
- `Get/Post/Put/Delete '[JSON] Type` — HTTP-метод + формат ответа

### Обработчики

Тип обработчика выводится из типа API:

```haskell
-- Один эндпоинт
type API1 = "users" :> Capture "id" Int :> Get '[JSON] User

server1 :: Server API1
server1 = getUser
 where
  getUser :: Int -> Handler User
  getUser userId = ...

-- Несколько эндпоинтов
type API2 =
       "users" :> Get '[JSON] [User]
  :<|> "users" :> Capture "id" Int :> Get '[JSON] User

server2 :: Server API2
server2 = listUsers :<|> getUser
 where
  listUsers :: Handler [User]
  listUsers = ...

  getUser :: Int -> Handler User
  getUser userId = ...
```

`Server API` автоматически выводится:
- Один эндпоинт → одна функция
- `:<|>` → `:<|>` между обработчиками
- `Capture` → дополнительный аргумент функции
- `ReqBody` → дополнительный аргумент функции

### Монада Handler

Все обработчики работают в монаде `Handler`:

```haskell
newtype Handler a = ...  -- упрощённо: ExceptT ServerError IO a
```

`Handler` — это `IO` с возможностью бросить HTTP-ошибку:

```haskell
import Servant

-- Успешный ответ
getUser :: Int -> Handler User
getUser userId = pure (User userId "Alice")

-- Ошибка 404
getUser :: Int -> Handler User
getUser userId = throwError err404 { errBody = "User not found" }

-- IO-действия
getUserFromDB :: Int -> Handler User
getUserFromDB userId = do
  mUser <- liftIO $ queryDatabase userId
  case mUser of
    Nothing -> throwError err404
    Just u  -> pure u
```

Предопределённые ошибки: `err400`, `err401`, `err403`, `err404`, `err500`.

### Автоматическая документация

Servant может сгенерировать OpenAPI/Swagger документацию:

```yaml
# package.yaml
dependencies:
  - servant-swagger
  - swagger2
```

```haskell
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE DataKinds #-}

import Servant
import Servant.Swagger
import Data.Swagger

type API = "users" :> Get '[JSON] [User]
      :<|> "users" :> Capture "id" Int :> Get '[JSON] User

swagger :: Swagger
swagger = toSwagger (Proxy :: Proxy API)

main :: IO ()
main = do
  print swagger  -- Полная спецификация OpenAPI
```

Servant **генерирует** документацию из типа API. Не нужно писать YAML вручную — если API компилируется, документация корректна.

## persistent — ORM для Haskell

### Зачем persistent

Библиотека **persistent** — стандартный ORM в экосистеме Haskell. Она предоставляет:

- Описание моделей через квази-цитаты (Template Haskell).
- Автоматические миграции.
- Типобезопасные запросы.
- Поддержку SQLite, PostgreSQL, MySQL и других БД.

### Подключение

```yaml
dependencies:
  - persistent
  - persistent-sqlite
  - persistent-template    # для mkPersist / share
  - monad-logger           # логирование запросов
  - resourcet              # управление ресурсами
  - transformers           # для ReaderT
```

### Определение моделей

persistent использует **Template Haskell** для генерации типов данных, миграций и CRUD-функций из декларативного описания:

```haskell
{-# LANGUAGE TemplateHaskell          #-}
{-# LANGUAGE QuasiQuotes              #-}
{-# LANGUAGE TypeFamilies             #-}
{-# LANGUAGE GADTs                    #-}
{-# LANGUAGE DerivingStrategies       #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE StandaloneDeriving       #-}
{-# LANGUAGE UndecidableInstances       #-}
{-# LANGUAGE DataKinds                #-}
{-# LANGUAGE FlexibleInstances        #-}
{-# LANGUAGE MultiParamTypeClasses    #-}
{-# LANGUAGE OverloadedStrings        #-}

import Database.Persist
import Database.Persist.TH
import Database.Persist.Sqlite
import Data.Text (Text)

share [mkPersist sqlSettings, mkMigrate "migrateAll"] [persistLowerCase|
Task
  title       Text
  description Text default=''
  priority    Text
  status      Text default='todo'
  deriving Show Eq
|]
```

Блок `persistLowerCase|...|` (квази-цитата) генерирует:

- Тип данных `Task` с полями `taskTitle`, `taskDescription`, `taskPriority`, `taskStatus`.
- Тип ключа `TaskId` (обёртка над `Int64`).
- Функцию миграции `migrateAll` для создания/обновления таблиц.
- Инстансы `PersistEntity`, `PersistField` и другие для типобезопасных запросов.

```admonish note title="О Template Haskell"
Template Haskell (TH) — метапрограммирование: код, который генерирует код на этапе компиляции. `persistLowerCase` — квази-цитата, которая парсит строку в описание модели и генерирует Haskell-код. TH мощный, но увеличивает время компиляции. В этой главе мы используем его как «чёрный ящик» — достаточно понимать, *что* генерируется, не *как*.
```

### Инициализация и миграции

```haskell
import Control.Monad.Logger (runStdoutLoggingT)
import Database.Persist.Sqlite (runSqlite, runMigration)

initDB :: IO ()
initDB = runStdoutLoggingT $ runSqlite "tasks.db" $ do
  runMigration migrateAll
```

`runSqlite "tasks.db"` открывает (или создаёт) файл SQLite и выполняет действия с БД. `runMigration` создаёт таблицы, если их нет, или обновляет схему.

```text
$ stack run
Migrating: CREATE TABLE "task"(
  "id" INTEGER PRIMARY KEY,
  "title" VARCHAR NOT NULL,
  "description" VARCHAR NOT NULL DEFAULT '',
  "priority" VARCHAR NOT NULL,
  "status" VARCHAR NOT NULL DEFAULT 'todo'
)
```

### CRUD-операции

persistent предоставляет функции для базовых операций:

```haskell
-- Создание
insert :: (PersistStoreWrite backend, PersistRecordBackend record backend)
       => record -> ReaderT backend m (Key record)

-- Чтение
get :: (PersistStoreRead backend, PersistRecordBackend record backend)
    => Key record -> ReaderT backend m (Maybe record)

-- Обновление
update :: (PersistStoreWrite backend, PersistRecordBackend record backend)
       => Key record -> [Update record] -> ReaderT backend m ()

-- Удаление
delete :: (PersistStoreWrite backend, PersistRecordBackend record backend)
       => Key record -> ReaderT backend m ()

-- Список
selectList :: (PersistQueryRead backend, PersistRecordBackend record backend)
           => [Filter record] -> [SelectOpt record]
           -> ReaderT backend m [Entity record]
```

Сигнатуры выглядят устрашающе, но на практике всё просто:

```haskell
-- Создать задачу
createTask :: Task -> SqlPersistT IO TaskId
createTask = insert

-- Получить задачу по ID
getTask :: TaskId -> SqlPersistT IO (Maybe Task)
getTask = get

-- Получить все задачи
getAllTasks :: SqlPersistT IO [Entity Task]
getAllTasks = selectList [] [Asc TaskTitle]

-- Обновить статус задачи
updateTaskStatus :: TaskId -> Text -> SqlPersistT IO ()
updateTaskStatus taskId newStatus =
  update taskId [TaskStatus =. newStatus]

-- Удалить задачу
deleteTask :: TaskId -> SqlPersistT IO ()
deleteTask = delete
```

`Entity Task` — пара из ключа и значения: `Entity { entityKey :: TaskId, entityVal :: Task }`.

```admonish tip title="Знакомый аналог"
**TypeScript (Prisma):** `prisma.task.create({ data: { title: "...", ... } })`.
**Python (SQLAlchemy):** `session.add(Task(title="..."))`.
**Go (GORM):** `db.Create(&task)`.
persistent близок к ActiveRecord/Prisma — декларативные модели, автомиграции, типобезопасные запросы.
```

### Фильтрация и сортировка

persistent поддерживает типобезопасные фильтры:

```haskell
-- Задачи со статусом "todo"
todoTasks :: SqlPersistT IO [Entity Task]
todoTasks = selectList [TaskStatus ==. "todo"] []

-- Задачи с высоким приоритетом, отсортированные по заголовку
highPriorityTasks :: SqlPersistT IO [Entity Task]
highPriorityTasks = selectList
  [TaskPriority ==. "high"]
  [Asc TaskTitle]

-- Комбинация фильтров (AND)
urgentTodoTasks :: SqlPersistT IO [Entity Task]
urgentTodoTasks = selectList
  [TaskPriority ==. "high", TaskStatus ==. "todo"]
  []

-- Фильтр OR
activeOrUrgent :: SqlPersistT IO [Entity Task]
activeOrUrgent = selectList
  ([TaskStatus ==. "in_progress"] ||. [TaskPriority ==. "high"])
  []
```

Операторы фильтрации: `==.`, `!=.`, `>.`, `>=.`, `<.`, `<=.`, `||.` (OR).

### Типобезопасность в БД: PersistField

По умолчанию persistent хранит ADT как `Text`. Но можно сделать лучше — определить `PersistField` instances для типобезопасного хранения:

```haskell
import Database.Persist (PersistField (..), PersistValue (..))
import Database.Persist.Sql (PersistFieldSql (..), SqlType (..))

instance PersistField Priority where
  toPersistValue Low = PersistText "low"
  toPersistValue Medium = PersistText "medium"
  toPersistValue High = PersistText "high"

  fromPersistValue (PersistText "low") = Right Low
  fromPersistValue (PersistText "medium") = Right Medium
  fromPersistValue (PersistText "high") = Right High
  fromPersistValue (PersistText x) =
    Left $ "Неизвестный приоритет: " <> x
  fromPersistValue x =
    Left $ "Ожидался Text, получено: " <> T.pack (show x)

instance PersistFieldSql Priority where
  sqlType _ = SqlString
```

Теперь в схеме можно использовать `Priority` напрямую:

```haskell
TaskItem
  title       Text
  description Text default=''
  priority    Priority default='Medium'  -- ADT, не Text!
  status      Status default='Todo'
```

**Преимущества:**

1. **Невозможно** записать `"invalid_priority"` — компилятор запретит
2. Queries типобезопасны: `[TaskItemStatus ==. Done]` вместо `[TaskItemStatus ==. "done"]`
3. Refactoring-friendly — переименование конструктора автоматически исправит все uses

```admonish tip title="Best practice"
Для production-кода ВСЕГДА определяйте `PersistField` instances для ADT. Это предотвращает ошибки времени выполнения и делает код более надёжным.
```

## ReaderT-паттерн для подключения к БД

### Проблема

Каждый обработчик Servant должен иметь доступ к подключению к БД. Передавать его через аргументы каждой функции утомительно. **ReaderT-паттерн** решает эту проблему.

### Пул соединений

Для веб-приложения нужен **пул соединений** — набор переиспользуемых подключений к БД:

```haskell
import Database.Persist.Sqlite (createSqlitePool, runSqlPool)
import Control.Monad.Logger (runStdoutLoggingT)

type ConnectionPool = Pool SqlBackend

createPool :: IO ConnectionPool
createPool = runStdoutLoggingT $
  createSqlitePool "tasks.db" 5  -- 5 соединений в пуле
```

Пул держит несколько открытых соединений к БД и выдаёт их по требованию. Это критически важно для параллельных HTTP-запросов: если бы соединение было одно, все запросы выстраивались бы в очередь, а не обрабатывались параллельно.

### Конфигурация приложения

```haskell
data AppConfig = AppConfig
  { appPool :: ConnectionPool
  }
```

Конфигурацию удобно хранить в одной записи. В более крупных приложениях её передают через `ReaderT AppConfig IO`, чтобы обработчики получали настройки без явных аргументов.

### Запуск запросов через пул

```haskell
runDB :: ConnectionPool -> SqlPersistT IO a -> Handler a
runDB pool query = liftIO $ runSqlPool query pool
```

В обработчиках Servant:

```haskell
listTasksHandler :: ConnectionPool -> Handler [Entity Task]
listTasksHandler pool = runDB pool getAllTasks
```

## Servant API для трекера задач

### Модели запросов и ответов

Определим типы для JSON-тела запросов и ответов:

```haskell
{-# LANGUAGE DeriveGeneric #-}

import Data.Aeson
import GHC.Generics (Generic)

-- Запрос на создание задачи
data CreateTaskRequest = CreateTaskRequest
  { ctrTitle       :: Text
  , ctrDescription :: Text
  , ctrPriority    :: Text
  } deriving (Show, Generic)

instance FromJSON CreateTaskRequest where
  parseJSON = withObject "CreateTaskRequest" $ \v -> CreateTaskRequest
    <$> v .:  "title"
    <*> v .:? "description" .!= ""
    <*> v .:? "priority"    .!= "medium"

-- Запрос на обновление задачи
data UpdateTaskRequest = UpdateTaskRequest
  { utrTitle       :: Maybe Text
  , utrDescription :: Maybe Text
  , utrPriority    :: Maybe Text
  , utrStatus      :: Maybe Text
  } deriving (Show, Generic)

instance FromJSON UpdateTaskRequest where
  parseJSON = withObject "UpdateTaskRequest" $ \v -> UpdateTaskRequest
    <$> v .:? "title"
    <*> v .:? "description"
    <*> v .:? "priority"
    <*> v .:? "status"

-- Ответ с задачей
data TaskResponse = TaskResponse
  { taskRespId          :: Int64
  , taskRespTitle       :: Text
  , taskRespDescription :: Text
  , taskRespPriority    :: Text
  , taskRespStatus      :: Text
  } deriving (Show, Generic)

instance ToJSON TaskResponse where
  toJSON TaskResponse{..} = object
    [ "id"          .= taskRespId
    , "title"       .= taskRespTitle
    , "description" .= taskRespDescription
    , "priority"    .= taskRespPriority
    , "status"      .= taskRespStatus
    ]

-- Ответ с ошибкой
data ErrorResponse = ErrorResponse
  { errMessage :: Text
  } deriving (Show, Generic)

instance ToJSON ErrorResponse where
  toJSON (ErrorResponse msg) = object ["error" .= msg]
```

Оператор `.:?` парсит необязательное поле (возвращает `Maybe`), а `.!=` задаёт значение по умолчанию.

### Определение API

```haskell
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

import Servant

type TaskAPI =
       "tasks" :> Get '[JSON] [TaskResponse]
  :<|> "tasks" :> Capture "id" Int64 :> Get '[JSON] TaskResponse
  :<|> "tasks" :> ReqBody '[JSON] CreateTaskRequest :> Post '[JSON] TaskResponse
  :<|> "tasks" :> Capture "id" Int64 :> ReqBody '[JSON] UpdateTaskRequest :> Put '[JSON] TaskResponse
  :<|> "tasks" :> Capture "id" Int64 :> DeleteNoContent
```

`DeleteNoContent` — специальный тип для DELETE с ответом 204 (без тела).

### Конвертация между моделями

```haskell
import Database.Persist (Entity(..))

entityToResponse :: Entity Task -> TaskResponse
entityToResponse (Entity key task) = TaskResponse
  { taskRespId          = fromSqlKey key
  , taskRespTitle       = taskTitle task
  , taskRespDescription = taskDescription task
  , taskRespPriority    = taskPriority task
  , taskRespStatus      = taskStatus task
  }

requestToTask :: CreateTaskRequest -> Task
requestToTask CreateTaskRequest{..} = Task
  { taskTitle       = ctrTitle
  , taskDescription = ctrDescription
  , taskPriority    = ctrPriority
  , taskStatus      = "todo"
  }
```

`entityToResponse` разворачивает `Entity Task` (пару ключ + запись) в плоский DTO для клиента: `fromSqlKey` преобразует типобезопасный `TaskId` в `Int64`. `requestToTask` всегда задаёт начальный статус `"todo"` — клиент не может указать произвольный статус при создании задачи.

### Обработчики

```haskell
import Servant
import Database.Persist
import Database.Persist.Sqlite (fromSqlKey, toSqlKey)
import Data.Int (Int64)

-- GET /tasks — список всех задач
listTasksHandler :: ConnectionPool -> Handler [TaskResponse]
listTasksHandler pool = do
  tasks <- runDB pool $ selectList [] [Asc TaskTitle]
  pure (map entityToResponse tasks)

-- GET /tasks/:id — одна задача
getTaskHandler :: ConnectionPool -> Int64 -> Handler TaskResponse
getTaskHandler pool taskId = do
  let key = toSqlKey taskId :: TaskId
  mTask <- runDB pool $ get key
  case mTask of
    Nothing   -> throwError err404 { errBody = "Задача не найдена" }
    Just task -> pure (entityToResponse (Entity key task))

-- POST /tasks — создать задачу
createTaskHandler :: ConnectionPool -> CreateTaskRequest -> Handler TaskResponse
createTaskHandler pool req = do
  case validateCreate req of
    Left err -> throwError err400 { errBody = encodeUtf8 err }
    Right validReq -> do
      let task = requestToTask validReq
      newId <- runDB pool $ insert task
      pure (entityToResponse (Entity newId task))

-- PUT /tasks/:id — обновить задачу
updateTaskHandler :: ConnectionPool -> Int64 -> UpdateTaskRequest -> Handler TaskResponse
updateTaskHandler pool taskId req = do
  let key = toSqlKey taskId :: TaskId
  mTask <- runDB pool $ get key
  case mTask of
    Nothing -> throwError err404 { errBody = "Задача не найдена" }
    Just _ -> do
      let updates = buildUpdates req
      runDB pool $ update key updates
      updated <- runDB pool $ get key
      case updated of
        Nothing   -> throwError err404 { errBody = "Задача не найдена" }
        Just task -> pure (entityToResponse (Entity key task))

-- DELETE /tasks/:id — удалить задачу
deleteTaskHandler :: ConnectionPool -> Int64 -> Handler NoContent
deleteTaskHandler pool taskId = do
  let key = toSqlKey taskId :: TaskId
  mTask <- runDB pool $ get key
  case mTask of
    Nothing -> throwError err404 { errBody = "Задача не найдена" }
    Just _ -> do
      runDB pool $ delete key
      pure NoContent
```

Все пять обработчиков следуют одному паттерну: извлечь параметры, обратиться к БД через `runDB`, проверить результат через `case` и вернуть ответ или бросить ошибку через `throwError`.

### Построение списка обновлений

```haskell
import Data.Maybe (catMaybes)

buildUpdates :: UpdateTaskRequest -> [Update Task]
buildUpdates UpdateTaskRequest{..} = catMaybes
  [ (TaskTitle       =.) <$> utrTitle
  , (TaskDescription =.) <$> utrDescription
  , (TaskPriority    =.) <$> utrPriority
  , (TaskStatus      =.) <$> utrStatus
  ]
```

Функция `catMaybes` отфильтровывает `Nothing`, оставляя только заданные поля. Если клиент передал `{"title": "Новый заголовок"}` — обновится только `title`.

### Валидация

Добавим проверку данных перед созданием задачи:

```haskell
import Data.Text qualified as Text

validateCreate :: CreateTaskRequest -> Either Text CreateTaskRequest
validateCreate req
  | Text.null (ctrTitle req) =
      Left "Заголовок не может быть пустым"
  | ctrPriority req `notElem` ["low", "medium", "high"] =
      Left "Приоритет: low, medium, high"
  | otherwise =
      Right req
```

### Сборка сервера

```haskell
-- Сервер с доступом к пулу
taskServer :: ConnectionPool -> Server TaskAPI
taskServer pool =
       listTasksHandler pool
  :<|> getTaskHandler pool
  :<|> createTaskHandler pool
  :<|> updateTaskHandler pool
  :<|> deleteTaskHandler pool

-- WAI Application
app :: ConnectionPool -> Application
app pool = serve (Proxy :: Proxy TaskAPI) (taskServer pool)

-- Точка входа
main :: IO ()
main = do
  pool <- runStdoutLoggingT $ createSqlitePool "tasks.db" 5
  runStdoutLoggingT $ runSqlPool (runMigration migrateAll) pool
  putStrLn "Сервер запущен на http://localhost:3000"
  run 3000 (app pool)
```

## Полный пример

Соберём всё вместе:

```haskell
{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE DerivingStrategies         #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GADTs                      #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE QuasiQuotes                #-}
{-# LANGUAGE RecordWildCards            #-}
{-# LANGUAGE StandaloneDeriving         #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE TypeOperators              #-}
{-# LANGUAGE UndecidableInstances       #-}

module Main where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Logger (runStdoutLoggingT)
import Data.Aeson
import Data.Int (Int64)
import Data.Maybe (catMaybes)
import Data.Pool (Pool)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding (encodeUtf8)
import Database.Persist
import Database.Persist.Sqlite
import Database.Persist.TH
import GHC.Generics (Generic)
import Network.Wai (Application)
import Network.Wai.Handler.Warp (run)
import Servant

-- ── Модели persistent ──────────────────────────────────────

share [mkPersist sqlSettings, mkMigrate "migrateAll"] [persistLowerCase|
TaskItem
  title       Text
  description Text default=''
  priority    Text default='medium'
  status      Text default='todo'
  deriving Show Eq
|]

-- ── JSON-типы ──────────────────────────────────────────────

data CreateTaskRequest = CreateTaskRequest
  { ctrTitle       :: Text
  , ctrDescription :: Text
  , ctrPriority    :: Text
  } deriving (Show, Generic)

instance FromJSON CreateTaskRequest where
  parseJSON = withObject "CreateTaskRequest" $ \v -> CreateTaskRequest
    <$> v .:  "title"
    <*> v .:? "description" .!= ""
    <*> v .:? "priority"    .!= "medium"

data UpdateTaskRequest = UpdateTaskRequest
  { utrTitle       :: Maybe Text
  , utrDescription :: Maybe Text
  , utrPriority    :: Maybe Text
  , utrStatus      :: Maybe Text
  } deriving (Show, Generic)

instance FromJSON UpdateTaskRequest where
  parseJSON = withObject "UpdateTaskRequest" $ \v -> UpdateTaskRequest
    <$> v .:? "title"
    <*> v .:? "description"
    <*> v .:? "priority"
    <*> v .:? "status"

data TaskResponse = TaskResponse
  { trId          :: Int64
  , trTitle       :: Text
  , trDescription :: Text
  , trPriority    :: Text
  , trStatus      :: Text
  } deriving (Show, Generic)

instance ToJSON TaskResponse where
  toJSON TaskResponse{..} = object
    [ "id"          .= trId
    , "title"       .= trTitle
    , "description" .= trDescription
    , "priority"    .= trPriority
    , "status"      .= trStatus
    ]

-- ── Определение API ────────────────────────────────────────

type TaskAPI =
       "tasks" :> Get '[JSON] [TaskResponse]
  :<|> "tasks" :> Capture "id" Int64 :> Get '[JSON] TaskResponse
  :<|> "tasks" :> ReqBody '[JSON] CreateTaskRequest :> Post '[JSON] TaskResponse
  :<|> "tasks" :> Capture "id" Int64 :> ReqBody '[JSON] UpdateTaskRequest :> Put '[JSON] TaskResponse
  :<|> "tasks" :> Capture "id" Int64 :> DeleteNoContent

-- ── Конвертация ────────────────────────────────────────────

entityToResponse :: Entity TaskItem -> TaskResponse
entityToResponse (Entity key item) = TaskResponse
  { trId          = fromSqlKey key
  , trTitle       = taskItemTitle item
  , trDescription = taskItemDescription item
  , trPriority    = taskItemPriority item
  , trStatus      = taskItemStatus item
  }

requestToTaskItem :: CreateTaskRequest -> TaskItem
requestToTaskItem CreateTaskRequest{..} = TaskItem
  { taskItemTitle       = ctrTitle
  , taskItemDescription = ctrDescription
  , taskItemPriority    = ctrPriority
  , taskItemStatus      = "todo"
  }

-- ── Вспомогательные функции ────────────────────────────────

type DB a = SqlPersistT IO a
type ConnectionPool = Pool SqlBackend

runDB :: ConnectionPool -> DB a -> Handler a
runDB pool query = liftIO $ runSqlPool query pool

buildUpdates :: UpdateTaskRequest -> [Update TaskItem]
buildUpdates UpdateTaskRequest{..} = catMaybes
  [ (TaskItemTitle       =.) <$> utrTitle
  , (TaskItemDescription =.) <$> utrDescription
  , (TaskItemPriority    =.) <$> utrPriority
  , (TaskItemStatus      =.) <$> utrStatus
  ]

validateCreate :: CreateTaskRequest -> Either Text CreateTaskRequest
validateCreate req
  | Text.null (ctrTitle req) =
      Left "Заголовок не может быть пустым"
  | ctrPriority req `notElem` ["low", "medium", "high"] =
      Left "Приоритет: low, medium, high"
  | otherwise =
      Right req

-- ── Обработчики ────────────────────────────────────────────

handleList :: ConnectionPool -> Handler [TaskResponse]
handleList pool = do
  items <- runDB pool $ selectList [] [Asc TaskItemTitle]
  pure (map entityToResponse items)

handleGet :: ConnectionPool -> Int64 -> Handler TaskResponse
handleGet pool tid = do
  let key = toSqlKey tid :: TaskItemId
  mItem <- runDB pool $ get key
  case mItem of
    Nothing   -> throwError err404 { errBody = "Задача не найдена" }
    Just item -> pure (entityToResponse (Entity key item))

handleCreate :: ConnectionPool -> CreateTaskRequest -> Handler TaskResponse
handleCreate pool req = do
  case validateCreate req of
    Left err -> throwError err400 { errBody = encodeUtf8 err }
    Right validReq -> do
      let item = requestToTaskItem validReq
      newId <- runDB pool $ insert item
      pure (entityToResponse (Entity newId item))

handleUpdate :: ConnectionPool -> Int64 -> UpdateTaskRequest -> Handler TaskResponse
handleUpdate pool tid req = do
  let key = toSqlKey tid :: TaskItemId
  mItem <- runDB pool $ get key
  case mItem of
    Nothing -> throwError err404 { errBody = "Задача не найдена" }
    Just _ -> do
      runDB pool $ update key (buildUpdates req)
      mUpdated <- runDB pool $ get key
      case mUpdated of
        Nothing   -> throwError err404 { errBody = "Задача не найдена" }
        Just item -> pure (entityToResponse (Entity key item))

handleDelete :: ConnectionPool -> Int64 -> Handler NoContent
handleDelete pool tid = do
  let key = toSqlKey tid :: TaskItemId
  mItem <- runDB pool $ get key
  case mItem of
    Nothing -> throwError err404 { errBody = "Задача не найдена" }
    Just _  -> do
      runDB pool $ Database.Persist.delete key
      pure NoContent

-- ── Приложение ─────────────────────────────────────────────

taskServer :: ConnectionPool -> Server TaskAPI
taskServer pool =
       handleList pool
  :<|> handleGet pool
  :<|> handleCreate pool
  :<|> handleUpdate pool
  :<|> handleDelete pool

application :: ConnectionPool -> Application
application pool = serve (Proxy :: Proxy TaskAPI) (taskServer pool)

-- ── Точка входа ────────────────────────────────────────────

main :: IO ()
main = do
  pool <- runStdoutLoggingT $ createSqlitePool "tasks.db" 5
  runStdoutLoggingT $ runSqlPool (runMigration migrateAll) pool
  putStrLn "Сервер запущен на http://localhost:3000"
  run 3000 (application pool)
```

Вот что делает каждая секция: `share [mkPersist, mkMigrate]` через Template Haskell генерирует типы и функции для работы с БД; секции JSON-типов и конвертации изолируют HTTP-слой от слоя хранилища; **тип API описывает контракт**, обработчики реализуют логику, `taskServer` связывает их через `:<|>`; `main` инициализирует пул, запускает авто-миграцию и запускает Warp-сервер.

### Тестирование API

```text
$ stack run &

$ curl -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Купить молоко", "priority": "low"}'

{"id":1,"title":"Купить молоко","description":"","priority":"low","status":"todo"}

$ curl -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Написать отчёт", "priority": "high"}'

{"id":2,"title":"Написать отчёт","description":"","priority":"high","status":"todo"}

$ curl http://localhost:3000/tasks

[{"id":1,"title":"Купить молоко",...},{"id":2,"title":"Написать отчёт",...}]

$ curl -X PUT http://localhost:3000/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{"status": "done"}'

{"id":1,"title":"Купить молоко","description":"","priority":"low","status":"done"}

$ curl -X DELETE http://localhost:3000/tasks/1 -i

HTTP/1.1 204 No Content
```

## Преимущества Servant

### Типобезопасность

Если обработчик не соответствует API — код не компилируется:

```haskell
type API = "users" :> Capture "id" Int :> Get '[JSON] User

-- ✗ ОШИБКА КОМПИЛЯЦИИ
server :: Server API
server = getUser
 where
  getUser :: Text -> Handler User  -- Тип не совпадает! Ожидается Int
  getUser = ...
```

Компилятор не даст вам перепутать типы параметров или забыть обработчик.

### Автогенерация клиентов

Из типа API можно сгенерировать клиентскую библиотеку:

```haskell
import Servant.Client

type API = "tasks" :> Get '[JSON] [TaskResponse]
      :<|> "tasks" :> Capture "id" Int64 :> Get '[JSON] TaskResponse

getTasks :: ClientM [TaskResponse]
getTask  :: Int64 -> ClientM TaskResponse

getTasks :<|> getTask = client (Proxy :: Proxy API)

-- Использование
main :: IO ()
main = do
  manager <- newManager defaultManagerSettings
  let baseUrl = BaseUrl Http "localhost" 3000 ""
  result <- runClientM getTasks (mkClientEnv manager baseUrl)
  print result
```

Клиент **выведен из типа API**. Если API изменится — клиент обновится автоматически. Нет рассинхронизации между сервером и клиентом.

### Автогенерация документации

```haskell
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE DataKinds #-}

import Servant
import Servant.Swagger
import Data.Swagger

type TaskAPI = "tasks" :> Get '[JSON] [TaskResponse]
          :<|> "tasks" :> Capture "id" Int64 :> Get '[JSON] TaskResponse

swagger :: Swagger
swagger = toSwagger (Proxy :: Proxy TaskAPI)
```

Servant генерирует OpenAPI/Swagger-спецификацию. Её можно отдать клиентам или использовать в Swagger UI для интерактивной документации.

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

### Проект ★☆☆

1. **Эндпоинт для завершения задачи.** Добавьте в API эндпоинт `PATCH /tasks/:id/complete`, который устанавливает статус задачи в `"done"`. Верните обновлённую задачу в ответе:

    ```haskell
    type CompleteAPI = "tasks" :> Capture "id" Int64 :> "complete" :> Patch '[JSON] TaskResponse

    handleComplete :: ConnectionPool -> Int64 -> Handler TaskResponse
    ```

    **Подсказка:** используйте `update key [TaskItemStatus =. "done"]`.

2. **Эндпоинт статистики.** Добавьте `GET /stats`, который возвращает количество задач по статусам:

    ```json
    {
      "total": 10,
      "todo": 5,
      "in_progress": 3,
      "done": 2
    }
    ```

    Используйте `count` из persistent для подсчёта:

    ```haskell
    count :: [Filter record] -> ReaderT backend m Int
    ```

### Проект ★★☆

3. **Пагинация.** Реализуйте пагинацию в `GET /tasks`. Принимайте query-параметры `page` (по умолчанию 1) и `per_page` (по умолчанию 20):

    ```haskell
    type PaginatedAPI = "tasks"
      :> QueryParam "page" Int
      :> QueryParam "per_page" Int
      :> Get '[JSON] [TaskResponse]

    handleListPaginated :: ConnectionPool -> Maybe Int -> Maybe Int -> Handler [TaskResponse]
    ```

    Используйте `SelectOpt` для `LimitTo` и `OffsetBy`. Верните в ответе мета-информацию: `{ "data": [...], "page": 1, "per_page": 20, "total": 42 }`.

4. **Поиск по заголовку.** Добавьте query-параметр `search`:

    ```haskell
    type SearchAPI = "tasks" :> QueryParam "search" Text :> Get '[JSON] [TaskResponse]
    ```

    Для SQLite используйте `like` оператор или фильтруйте в Haskell через `filter` после получения записей.

### Практика ★☆☆

5. **Валидация приоритета.** Напишите функцию `validatePriority :: Text -> Either Text Text`, которая проверяет, что строка — допустимый приоритет (`"low"`, `"medium"`, `"high"`), и нормализует регистр (например, `"HIGH"` -> `"high"`):

    ```haskell
    validatePriority :: Text -> Either Text Text
    ```

6. **Конвертация Entity → TaskResponse.** Напишите функцию `entityToResponse`, которая конвертирует `Entity TaskItem` в JSON-совместимый `TaskResponse`. Убедитесь, что `fromSqlKey` корректно конвертирует `TaskItemId` в `Int64`.

### Практика ★★☆

7. **Custom типы для приоритета и статуса.** Перенесите приоритет и статус из `Text` в собственные типы данных с инстансами `PersistField` и `ToJSON`/`FromJSON`:

    ```haskell
    data Priority = Low | Medium | High
      deriving (Show, Eq, Ord, Generic)

    instance PersistField Priority where
      toPersistValue Low    = PersistText "low"
      toPersistValue Medium = PersistText "medium"
      toPersistValue High   = PersistText "high"

      fromPersistValue (PersistText "low")    = Right Low
      fromPersistValue (PersistText "medium") = Right Medium
      fromPersistValue (PersistText "high")   = Right High
      fromPersistValue x = Left $ "Invalid Priority: " <> Text.pack (show x)

    instance PersistFieldSql Priority where
      sqlType _ = SqlString

    instance ToJSON Priority where
      toJSON Low    = "low"
      toJSON Medium = "medium"
      toJSON High   = "high"

    instance FromJSON Priority where
      parseJSON = withText "Priority" $ \case
        "low"    -> pure Low
        "medium" -> pure Medium
        "high"   -> pure High
        x        -> fail ("Unknown priority: " <> Text.unpack x)
    ```

    Обновите модель persistent и все обработчики.

8. **Генерация Swagger-документации.** Добавьте зависимость `servant-swagger` и создайте эндпоинт `GET /swagger.json`, который возвращает OpenAPI-спецификацию вашего API:

    ```haskell
    type APIWithSwagger = TaskAPI :<|> "swagger.json" :> Get '[JSON] Swagger

    serverWithSwagger :: ConnectionPool -> Server APIWithSwagger
    serverWithSwagger pool = taskServer pool :<|> pure swaggerDoc
     where
      swaggerDoc = toSwagger (Proxy :: Proxy TaskAPI)
    ```

## Заключение

Трекер задач прошёл путь от типов данных ([глава 2](chapter02.md)) через модульную структуру ([глава 15](chapter15.md)) и конкурентность ([глава 16](chapter16.md)) до работающего REST API с базой данных. По дороге мы освоили **Servant** (типобезопасные API, автогенерация клиентов и документации), **persistent** с **Template Haskell** (декларативные модели, автомиграции, типобезопасные CRUD-операции), **ReaderT-паттерн** с пулом соединений и обработку ошибок с валидацией. Результат — полноценный HTTP-сервер с SQLite, где **типы гарантируют корректность API**.

В [следующей главе](chapter18.md) мы перейдём к продвинутым темам — DSL и парсерам.

```admonish tip title="Для углубления"
- **Haskell MOOC** — [haskell.mooc.fi](https://haskell.mooc.fi/), лекция 14: «Web Programming» — введение в веб-разработку на Haskell.
- **Servant документация** — [docs.servant.dev](https://docs.servant.dev/) — официальное руководство, туториалы, cookbook.
- **persistent** — [hackage.haskell.org/package/persistent](https://hackage.haskell.org/package/persistent) — документация ORM.
- **Yesod book** — [yesodweb.com/book](https://www.yesodweb.com/book) — подробно о persistent и веб-разработке на Haskell.
- **Three Layer Haskell Cake** (Matt Parsons) — [www.parsonsmatt.org/2018/03/22/three_layer_haskell_cake.html](https://www.parsonsmatt.org/2018/03/22/three_layer_haskell_cake.html) — архитектура Haskell-приложений.
- **Type-level Web APIs with Servant** (paper) — [www.andres-loeh.de/Servant/servant-wgp.pdf](https://www.andres-loeh.de/Servant/servant-wgp.pdf) — академическая статья о дизайне Servant.
```
