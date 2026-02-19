# Веб-приложение с базой данных

Это кульминация нашего сквозного проекта. За предыдущие главы мы создали типы данных, бизнес-логику, модульную структуру и параллельный импорт. Теперь превратим трекер задач в полноценный REST API с базой данных. Глава охватывает веб-фреймворк **Scotty** (маршруты, параметры, JSON-ответы), **persistent** + **persistent-sqlite** (модели, миграции, CRUD-запросы), минимум **Template Haskell** для описания моделей, **ReaderT-паттерн** для передачи подключения к БД и обработку ошибок. Мы построим REST API с эндпоинтами `GET /tasks`, `POST /tasks`, `PUT /tasks/:id`, `DELETE /tasks/:id` и соберём полное приложение.

К концу главы у вас будет работающий HTTP-сервер с базой данных — полноценный бэкенд для трекера задач.

## Scotty — минималистичный веб-фреймворк

### Почему Scotty

В экосистеме Haskell есть несколько веб-фреймворков:

- **Scotty** — минималистичный, вдохновлён Ruby's Sinatra. Идеален для обучения и небольших сервисов.
- **Servant** — типобезопасный, API описывается на уровне типов. Мощный, но требует продвинутых знаний.
- **Yesod** — полнофункциональный фреймворк с шаблонами, ORM и роутингом.

Мы используем Scotty — он прост и позволяет сосредоточиться на Haskell, а не на фреймворке.

### Подключение

Добавьте зависимости в `package.yaml`:

```yaml
dependencies:
  - base >= 4.7 && < 5
  - scotty
  - aeson        # JSON
  - text
  - wai          # Web Application Interface
  - http-types   # HTTP status codes
```

### Первое приложение

```haskell
{-# LANGUAGE OverloadedStrings #-}

import Web.Scotty
import Data.Text.Lazy (Text)

main :: IO ()
main = scotty 3000 $ do
  get "/" $ do
    text "Трекер задач v1.0"

  get "/hello/:name" $ do
    name <- pathParam "name" :: ActionM Text
    text ("Привет, " <> name <> "!")
```

```text
$ stack run
$ curl http://localhost:3000/
Трекер задач v1.0

$ curl http://localhost:3000/hello/Haskell
Привет, Haskell!
```

Разберём:

- `scotty 3000` — запускает HTTP-сервер на порту 3000.
- `get "/" $ do ...` — обработчик GET-запроса на корневой путь.
- `pathParam "name"` — извлекает параметр из URL (`:name` в маршруте).
- `text` — отправляет текстовый ответ.

```admonish tip title="Знакомый аналог"
**TypeScript (Express):**
`app.get('/hello/:name', (req, res) => { res.send('Hello, ' + req.params.name) })`.
**Python (Flask):**
`@app.route('/hello/<name>') def hello(name): return f'Hello, {name}!'`.
**Go (net/http + gorilla/mux):**
`r.HandleFunc("/hello/{name}", handler)`.
Scotty практически идентичен Sinatra/Flask/Express по API.
```

### Маршруты и методы

Scotty поддерживает все стандартные HTTP-методы:

```haskell
import Web.Scotty
import Network.HTTP.Types.Status (status201, status204, status404)

routes :: ScottyM ()
routes = do
  get    "/tasks"     listTasks
  get    "/tasks/:id" getTask
  post   "/tasks"     createTask
  put    "/tasks/:id" updateTask
  delete "/tasks/:id" deleteTask
```

Функции `listTasks`, `getTask`, `createTask`, `updateTask`, `deleteTask` — это *обработчики*, которые реализуются отдельно. Scotty связывает HTTP-метод + путь с обработчиком и вызывает нужный при каждом входящем запросе.

### Параметры и тело запроса

```haskell
-- Параметр из URL:  /tasks/:id
getTaskId :: ActionM Int
getTaskId = pathParam "id"

-- Query-параметр:  /tasks?status=done
getStatusFilter :: ActionM (Maybe Text)
getStatusFilter = queryParamMaybe "status"

-- Тело запроса как JSON
getTaskBody :: ActionM TaskRequest
getTaskBody = jsonData
```

Scotty автоматически парсит параметры: `pathParam` извлекает именованный сегмент URL и конвертирует его в нужный тип, `queryParamMaybe` возвращает `Nothing`, если query-параметр отсутствует, а `jsonData` десериализует тело запроса через инстанс `FromJSON`.

### JSON-ответы

Scotty работает с **aeson** для сериализации/десериализации JSON:

```haskell
{-# LANGUAGE DeriveGeneric #-}

import Data.Aeson (ToJSON, FromJSON)
import GHC.Generics (Generic)

data TaskResponse = TaskResponse
  { trId       :: Int
  , trTitle    :: Text
  , trPriority :: Text
  , trStatus   :: Text
  } deriving (Show, Generic)

instance ToJSON TaskResponse
instance FromJSON TaskResponse
```

```haskell
listTasks :: ActionM ()
listTasks = do
  let tasks = [ TaskResponse 1 "Купить молоко" "low" "todo"
              , TaskResponse 2 "Написать отчёт" "high" "in_progress"
              ]
  json tasks
```

```text
$ curl http://localhost:3000/tasks
[{"trId":1,"trTitle":"Купить молоко","trPriority":"low","trStatus":"todo"},
 {"trId":2,"trTitle":"Написать отчёт","trPriority":"high","trStatus":"in_progress"}]
```

### HTTP-статусы

```haskell
import Network.HTTP.Types.Status

createTask :: ActionM ()
createTask = do
  taskReq <- jsonData :: ActionM TaskRequest
  -- ... создание задачи ...
  status status201
  json (TaskResponse 3 (trqTitle taskReq) (trqPriority taskReq) "todo")

notFoundHandler :: ActionM ()
notFoundHandler = do
  status status404
  json (ErrorResponse "Ресурс не найден")
```

Функция `status` устанавливает HTTP-статус ответа. По умолчанию Scotty возвращает 200 OK; для созданного ресурса правильный код — 201 Created, для отсутствующего — 404 Not Found. Обработчик ошибок лучше выносить отдельно, чтобы не дублировать логику формирования ответа.

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
{-# LANGUAGE UndeclarededFields       #-}
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

## ReaderT-паттерн для подключения к БД

### Проблема

Каждый обработчик Scotty должен иметь доступ к подключению к БД. Передавать его через аргументы каждой функции утомительно. **ReaderT-паттерн** решает эту проблему.

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
  , appPort :: Int
  }
```

Конфигурацию удобно хранить в одной записи. В более крупных приложениях её передают через `ReaderT AppConfig IO`, чтобы обработчики получали настройки без явных аргументов — мы делаем упрощённый вариант и передаём `ConnectionPool` напрямую.

### Запуск запросов через пул

```haskell
runDB :: ConnectionPool -> SqlPersistT IO a -> IO a
runDB = flip runSqlPool
```

В обработчиках Scotty:

```haskell
listTasksHandler :: ConnectionPool -> ActionM ()
listTasksHandler pool = do
  tasks <- liftIO $ runDB pool getAllTasks
  json (map entityToResponse tasks)
```

`liftIO` поднимает `IO`-действие в монаду `ActionM` (монада обработчика Scotty).

```admonish note title="Зачем liftIO"
Scotty-обработчики работают в монаде `ActionM`, а не в `IO`. `liftIO :: IO a -> ActionM a` позволяет выполнить IO-действие внутри обработчика. Это частный случай `MonadIO` — класса типов, который мы встретили в [главе 13](chapter13.md) (трансформеры).
```

## REST API для трекера задач

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
    <$> v .: "title"
    <*> v .: "description"
    <*> v .:? "priority" .!= "medium"

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
import Web.Scotty
import Network.HTTP.Types.Status
import Database.Persist
import Database.Persist.Sqlite (fromSqlKey, toSqlKey)
import Data.Int (Int64)
import Control.Monad.IO.Class (liftIO)

-- GET /tasks — список всех задач
listTasksHandler :: ConnectionPool -> ActionM ()
listTasksHandler pool = do
  statusFilter <- queryParamMaybe "status" :: ActionM (Maybe Text)
  tasks <- liftIO $ runDB pool $ case statusFilter of
    Nothing -> selectList [] [Asc TaskTitle]
    Just s  -> selectList [TaskStatus ==. s] [Asc TaskTitle]
  json (map entityToResponse tasks)

-- GET /tasks/:id — одна задача
getTaskHandler :: ConnectionPool -> ActionM ()
getTaskHandler pool = do
  taskId <- pathParam "id" :: ActionM Int64
  mTask <- liftIO $ runDB pool $ get (toSqlKey taskId :: TaskId)
  case mTask of
    Nothing   -> do
      status status404
      json (ErrorResponse "Задача не найдена")
    Just task -> json (entityToResponse (Entity (toSqlKey taskId) task))

-- POST /tasks — создать задачу
createTaskHandler :: ConnectionPool -> ActionM ()
createTaskHandler pool = do
  req <- jsonData :: ActionM CreateTaskRequest
  let task = requestToTask req
  newId <- liftIO $ runDB pool $ insert task
  status status201
  json (entityToResponse (Entity newId task))

-- PUT /tasks/:id — обновить задачу
updateTaskHandler :: ConnectionPool -> ActionM ()
updateTaskHandler pool = do
  taskId <- pathParam "id" :: ActionM Int64
  req <- jsonData :: ActionM UpdateTaskRequest
  let key = toSqlKey taskId :: TaskId
  mTask <- liftIO $ runDB pool $ get key
  case mTask of
    Nothing -> do
      status status404
      json (ErrorResponse "Задача не найдена")
    Just _task -> do
      let updates = buildUpdates req
      liftIO $ runDB pool $ update key updates
      updated <- liftIO $ runDB pool $ get key
      case updated of
        Nothing   -> do
          status status404
          json (ErrorResponse "Задача не найдена")
        Just task -> json (entityToResponse (Entity key task))

-- DELETE /tasks/:id — удалить задачу
deleteTaskHandler :: ConnectionPool -> ActionM ()
deleteTaskHandler pool = do
  taskId <- pathParam "id" :: ActionM Int64
  let key = toSqlKey taskId :: TaskId
  mTask <- liftIO $ runDB pool $ get key
  case mTask of
    Nothing -> do
      status status404
      json (ErrorResponse "Задача не найдена")
    Just _ -> do
      liftIO $ runDB pool $ delete key
      status status204
      raw ""
```

Все пять обработчиков следуют одному паттерну: извлечь параметры из запроса, обратиться к БД через `liftIO . runDB`, проверить результат через `case` и вернуть ответ с правильным HTTP-статусом. При 404 возвращается JSON-объект с полем `"error"`, а не пустое тело.

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

## Обработка ошибок

### Проблема с jsonData

Если клиент отправит невалидный JSON, `jsonData` бросит исключение, и Scotty вернёт ответ с кодом 500 и стандартным сообщением. Это не информативно.

### defaultHandler и rescue

Scotty позволяет перехватывать ошибки:

```haskell
import Web.Scotty (defaultHandler, ActionM, ScottyM)
import Web.Scotty.Trans (ActionError(..))
import Data.Text.Lazy qualified as LT

app :: ConnectionPool -> ScottyM ()
app pool = do
  -- Обработчик ошибок по умолчанию
  defaultHandler $ \err -> do
    status status400
    json (ErrorResponse (LT.toStrict (LT.pack (show err))))

  -- Маршруты
  get    "/tasks"     (listTasksHandler pool)
  get    "/tasks/:id" (getTaskHandler pool)
  post   "/tasks"     (createTaskHandler pool)
  put    "/tasks/:id" (updateTaskHandler pool)
  delete "/tasks/:id" (deleteTaskHandler pool)
```

### Валидация

Добавим проверку данных перед созданием задачи:

```haskell
import Data.Text qualified as Text

validateCreateRequest :: CreateTaskRequest -> Either Text CreateTaskRequest
validateCreateRequest req
  | Text.null (ctrTitle req) =
      Left "Заголовок не может быть пустым"
  | ctrPriority req `notElem` ["low", "medium", "high"] =
      Left "Приоритет должен быть: low, medium, high"
  | otherwise =
      Right req

createTaskHandler :: ConnectionPool -> ActionM ()
createTaskHandler pool = do
  req <- jsonData :: ActionM CreateTaskRequest
  case validateCreateRequest req of
    Left err -> do
      status status400
      json (ErrorResponse err)
    Right validReq -> do
      let task = requestToTask validReq
      newId <- liftIO $ runDB pool $ insert task
      status status201
      json (entityToResponse (Entity newId task))
```

```admonish warning title="Валидация на уровне типов"
В нашем примере приоритет и статус хранятся как `Text` — это упрощение для учебных целей. В продакшн-коде стоит использовать собственные типы (`Priority`, `Status`) с инстансами `PersistField`. Тогда невалидные значения будут невозможны на уровне типов.
```

## Полный пример

Соберём всё вместе в одном файле для наглядности:

```haskell
{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE DerivingStrategies         #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GADTs                      #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE QuasiQuotes                #-}
{-# LANGUAGE StandaloneDeriving         #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE UndecidableInstances       #-}
{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE RecordWildCards            #-}

module Main where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Logger (runStdoutLoggingT)
import Data.Aeson
import Data.Int (Int64)
import Data.Maybe (catMaybes)
import Data.Pool (Pool)
import Data.Text (Text)
import Data.Text qualified as Text
import Database.Persist
import Database.Persist.Sqlite
import Database.Persist.TH
import GHC.Generics (Generic)
import Network.HTTP.Types.Status
import Web.Scotty

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

newtype ErrorResponse = ErrorResponse { errMessage :: Text }
  deriving (Show, Generic)

instance ToJSON ErrorResponse where
  toJSON (ErrorResponse msg) = object ["error" .= msg]

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

runDB :: ConnectionPool -> DB a -> IO a
runDB = flip runSqlPool

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

handleList :: ConnectionPool -> ActionM ()
handleList pool = do
  statusFilter <- queryParamMaybe "status" :: ActionM (Maybe Text)
  items <- liftIO $ runDB pool $ case statusFilter of
    Nothing -> selectList [] [Asc TaskItemTitle]
    Just s  -> selectList [TaskItemStatus ==. s] [Asc TaskItemTitle]
  json (map entityToResponse items)

handleGet :: ConnectionPool -> ActionM ()
handleGet pool = do
  tid <- pathParam "id" :: ActionM Int64
  let key = toSqlKey tid :: TaskItemId
  mItem <- liftIO $ runDB pool $ get key
  case mItem of
    Nothing   -> status status404 >> json (ErrorResponse "Не найдена")
    Just item -> json (entityToResponse (Entity key item))

handleCreate :: ConnectionPool -> ActionM ()
handleCreate pool = do
  req <- jsonData :: ActionM CreateTaskRequest
  case validateCreate req of
    Left err -> status status400 >> json (ErrorResponse err)
    Right validReq -> do
      let item = requestToTaskItem validReq
      newId <- liftIO $ runDB pool $ insert item
      status status201
      json (entityToResponse (Entity newId item))

handleUpdate :: ConnectionPool -> ActionM ()
handleUpdate pool = do
  tid <- pathParam "id" :: ActionM Int64
  req <- jsonData :: ActionM UpdateTaskRequest
  let key = toSqlKey tid :: TaskItemId
  mItem <- liftIO $ runDB pool $ get key
  case mItem of
    Nothing -> status status404 >> json (ErrorResponse "Не найдена")
    Just _ -> do
      liftIO $ runDB pool $ update key (buildUpdates req)
      mUpdated <- liftIO $ runDB pool $ get key
      case mUpdated of
        Nothing   -> status status404 >> json (ErrorResponse "Не найдена")
        Just item -> json (entityToResponse (Entity key item))

handleDelete :: ConnectionPool -> ActionM ()
handleDelete pool = do
  tid <- pathParam "id" :: ActionM Int64
  let key = toSqlKey tid :: TaskItemId
  mItem <- liftIO $ runDB pool $ get key
  case mItem of
    Nothing -> status status404 >> json (ErrorResponse "Не найдена")
    Just _  -> do
      liftIO $ runDB pool $ Database.Persist.delete key
      status status204
      raw ""

-- ── Приложение ─────────────────────────────────────────────

application :: ConnectionPool -> ScottyM ()
application pool = do
  get    "/tasks"     (handleList pool)
  get    "/tasks/:id" (handleGet pool)
  post   "/tasks"     (handleCreate pool)
  put    "/tasks/:id" (handleUpdate pool)
  delete "/tasks/:id" (handleDelete pool)

-- ── Точка входа ────────────────────────────────────────────

main :: IO ()
main = do
  pool <- runStdoutLoggingT $ createSqlitePool "tasks.db" 5
  runStdoutLoggingT $ runSqlPool (runMigration migrateAll) pool
  putStrLn "Сервер запущен на http://localhost:3000"
  scotty 3000 (application pool)
```

Вот что делает каждая секция: `share [mkPersist, mkMigrate]` через Template Haskell генерирует типы и функции для работы с БД; секции JSON-типов и конвертации изолируют HTTP-слой от слоя хранилища; обработчики делегируют работу в `runDB`; `main` инициализирует пул, запускает авто-миграцию и запускает Scotty-сервер.

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

$ curl http://localhost:3000/tasks?status=todo

[{"id":2,"title":"Написать отчёт",...}]

$ curl -X DELETE http://localhost:3000/tasks/1 -w "%{http_code}"

204
```

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

### Проект ★☆☆

1. Добавьте эндпоинт `PATCH /tasks/:id/complete`, который устанавливает статус задачи в `"done"`. Верните обновлённую задачу в ответе:

    ```haskell
    handleComplete :: ConnectionPool -> ActionM ()
    ```

2. Добавьте эндпоинт `GET /stats`, который возвращает статистику:

    ```json
    {
      "total": 10,
      "todo": 5,
      "in_progress": 3,
      "done": 2
    }
    ```

    Используйте `count` из persistent для подсчёта.

### Проект ★★☆

3. Реализуйте пагинацию в `GET /tasks`. Принимайте query-параметры `page` (по умолчанию 1) и `per_page` (по умолчанию 20). Используйте `SelectOpt` для `LimitTo` и `OffsetBy`:

    ```haskell
    handleListPaginated :: ConnectionPool -> ActionM ()
    ```

    Верните в ответе мета-информацию: `{ "data": [...], "page": 1, "per_page": 20, "total": 42 }`.

4. Добавьте поиск по заголовку: `GET /tasks?search=молоко`. Используйте фильтр persistent с оператором `like` или реализуйте фильтрацию в Haskell через `filter` после получения всех записей.

### Практика ★☆☆

5. Напишите функцию `validatePriority :: Text -> Either Text Text`, которая проверяет, что строка — допустимый приоритет (`"low"`, `"medium"`, `"high"`), и нормализует регистр (например, `"HIGH"` -> `"high"`):

    ```haskell
    validatePriority :: Text -> Either Text Text
    ```

6. Напишите функцию `entityToResponse`, которая конвертирует `Entity TaskItem` в JSON-совместимый `TaskResponse`. Убедитесь, что `fromSqlKey` корректно конвертирует `TaskItemId` в `Int64`.

### Практика ★★☆

7. Реализуйте middleware для логирования запросов. Используйте `middleware` из Scotty и WAI:

    ```haskell
    import Network.Wai (Middleware)
    import Network.Wai.Middleware.RequestLogger (logStdout)

    -- В application:
    middleware logStdout
    ```

    Добавьте также middleware для CORS (пакет `wai-cors`) и замерьте время обработки каждого запроса.

8. Перенесите приоритет и статус из `Text` в собственные типы данных с инстансами `PersistField`:

    ```haskell
    data Priority = Low | Medium | High
      deriving (Show, Eq, Ord)

    instance PersistField Priority where
      toPersistValue Low    = PersistText "low"
      toPersistValue Medium = PersistText "medium"
      toPersistValue High   = PersistText "high"

      fromPersistValue (PersistText "low")    = Right Low
      fromPersistValue (PersistText "medium") = Right Medium
      fromPersistValue (PersistText "high")   = Right High
      fromPersistValue x = Left $ "Invalid Priority: " <> Text.pack (show x)
    ```

    Обновите модель persistent и все обработчики.

## Заключение

Трекер задач прошёл путь от типов данных ([глава 2](chapter02.md)) через модульную структуру ([глава 15](chapter15.md)) и конкурентность ([глава 16](chapter16.md)) до работающего REST API с базой данных. По дороге мы освоили **Scotty** (маршруты, параметры, JSON, HTTP-статусы), **persistent** с **Template Haskell** (декларативные модели, автомиграции, типобезопасные CRUD-операции), **ReaderT-паттерн** с пулом соединений и обработку ошибок с валидацией. Результат — полноценный HTTP-сервер с SQLite.

В [следующей главе](chapter18.md) мы перейдём к продвинутым темам — DSL и парсерам.

```admonish tip title="Для углубления"
- **Haskell MOOC** — [haskell.mooc.fi](https://haskell.mooc.fi/), лекция 14: «Web Programming» — введение в веб-разработку на Haskell.
- **Scotty** — [hackage.haskell.org/package/scotty](https://hackage.haskell.org/package/scotty) — документация фреймворка.
- **persistent** — [hackage.haskell.org/package/persistent](https://hackage.haskell.org/package/persistent) — документация ORM.
- **Yesod book** — [yesodweb.com/book](https://www.yesodweb.com/book) — подробно о persistent и веб-разработке на Haskell.
- **Servant** — [docs.servant.dev](https://docs.servant.dev/) — типобезопасный веб-фреймворк для продвинутых.
- **Three Layer Haskell Cake** (Matt Parsons) — [www.parsonsmatt.org/2018/03/22/three_layer_haskell_cake.html](https://www.parsonsmatt.org/2018/03/22/three_layer_haskell_cake.html) — архитектура Haskell-приложений.
```
