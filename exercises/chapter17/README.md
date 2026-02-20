# Глава 17: Веб-приложение с базой данных (Servant + persistent)

REST API для трекера задач с использованием типобезопасного фреймворка **Servant** и ORM **persistent**.

## Технологии

- **Servant** — типобезопасный веб-фреймворк, где API описывается как тип
- **persistent + persistent-sqlite** — ORM с автоматическими миграциями
- **Warp** — HTTP-сервер
- **Template Haskell** — генерация кода для моделей БД
- **hspec-wai** — тестирование веб-приложений

## API Endpoints

```
GET    /tasks          - список всех задач
GET    /tasks/:id      - получить задачу по ID
POST   /tasks          - создать задачу
PUT    /tasks/:id      - обновить задачу
DELETE /tasks/:id      - удалить задачу
PATCH  /tasks/:id/complete - завершить задачу (статус → done)
GET    /stats          - статистика по статусам
```

## ⚠️ Важно: Миграция базы данных

Если вы ранее запускали chapter17, **удалите старую базу данных** перед запуском:

```bash
cd exercises/chapter17
rm -f tasks.db*
```

Схема БД изменилась — поля `priority` и `status` теперь хранятся как типобезопасные ADT (`Priority` и `Status`) вместо `Text`. Это предотвращает запись некорректных значений в БД.

## Запуск сервера

```bash
stack build
stack exec chapter17-server
```

Сервер запустится на `http://localhost:3000`

## Примеры запросов

### Создать задачу

```bash
curl -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Купить молоко",
    "priority": "low",
    "description": "В магазине на углу"
  }'
```

### Список задач

```bash
curl http://localhost:3000/tasks
```

### Обновить задачу

```bash
curl -X PUT http://localhost:3000/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{"status": "in_progress"}'
```

### Завершить задачу

```bash
curl -X PATCH http://localhost:3000/tasks/1/complete
```

### Статистика

```bash
curl http://localhost:3000/stats
```

### Удалить задачу

```bash
curl -X DELETE http://localhost:3000/tasks/1
```

## Тесты

```bash
stack test chapter17
```

### Структура тестов

- **Unit Tests** — чистые функции (пагинация, валидация, конвертация)
- **Integration Tests** — HTTP-запросы к Servant API
- **End-to-End** — полный цикл работы (создание → обновление → завершение → удаление)

## Упражнения

Реализуйте функции в `test/MySolutions.hs`:

### Чистые функции (★☆☆)

1. `handleCompleteLogic` — логика завершения задачи (проверка статуса)
2. `computeStatsMap` — статистика по статусам
3. `paginate` — пагинация списка
4. `searchByTitle` — поиск по подстроке (регистронезависимый)
5. `validatePriority` — валидация и нормализация приоритета
6. `entityToResponsePure` — конвертация Task → TaskResponse

### Servant handlers (★★☆)

7. `handleListPaginated` — GET /tasks с query-параметрами `?page=1&per_page=20`
8. `handleSearch` — GET /tasks с query-параметром `?search=молоко`

## Архитектура

```
src/
├── TaskTracker.hs   # Типы данных (Priority, Status, Task)
│                    # DTO (CreateTaskRequest, UpdateTaskRequest, TaskResponse)
│                    # Конвертация Priority/Status ↔ Text
└── API.hs           # Servant API, persistent модели, обработчики

app/
└── Main.hs          # Точка входа, инициализация БД, запуск сервера

test/
├── MySolutions.hs   # Студенческие решения (стабы)
└── Spec.hs          # Unit + Integration тесты
```

## Ключевые концепции

### Типобезопасность Servant

```haskell
type TaskAPI =
       "tasks" :> Get '[JSON] [TaskResponse]
  :<|> "tasks" :> Capture "id" Int64 :> Get '[JSON] TaskResponse
  :<|> "tasks" :> ReqBody '[JSON] CreateTaskRequest :> Post '[JSON] TaskResponse

taskServer :: ConnectionPool -> Server TaskAPI
taskServer pool =
       handleList pool
  :<|> handleGet pool
  :<|> handleCreate pool
```

Компилятор **гарантирует**, что обработчики соответствуют описанию API.

### persistent models (Template Haskell)

```haskell
share [mkPersist sqlSettings, mkMigrate "migrateAll"] [persistLowerCase|
TaskItem
  title       Text
  description Text default=''
  priority    Text default='medium'
  status      Text default='todo'
|]
```

Генерирует:
- Тип `TaskItem` с полями `taskItemTitle`, `taskItemDescription`, ...
- Тип ключа `TaskItemId`
- Функцию миграции `migrateAll`
- CRUD-функции: `insert`, `get`, `update`, `delete`, `selectList`

### ReaderT-паттерн

```haskell
type ConnectionPool = Pool.Pool SqlBackend

runDB :: ConnectionPool -> SqlPersistT IO a -> Handler a
runDB pool query = liftIO $ runSqlPool query pool

handleList :: ConnectionPool -> Handler [TaskResponse]
handleList pool = do
  items <- runDB pool $ selectList [] [Asc TaskItemTitle]
  pure (map entityToResponse items)
```

Пул соединений передаётся через аргументы обработчиков.

## Преимущества Servant

1. **Типобезопасность** — ошибки в API ловятся на этапе компиляции
2. **Автогенерация клиентов** — из типа API можно сгенерировать клиентскую библиотеку
3. **Автогенерация документации** — OpenAPI/Swagger из типа API
4. **Композиция** — API собирается из маленьких переиспользуемых частей

## Дополнительные материалы

- [Servant documentation](https://docs.servant.dev/)
- [persistent documentation](https://hackage.haskell.org/package/persistent)
- [Yesod book (persistent)](https://www.yesodweb.com/book/persistent)
