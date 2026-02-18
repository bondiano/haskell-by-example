# Веб-приложение с базой данных

## Цели главы

В этой главе мы создадим полноценное REST API для списка задач (Todo), используя:

- **persistent** + **persistent-sqlite** — типобезопасный доступ к базе данных;
- **Scotty** — минималистичный веб-фреймворк;
- приёмы из предыдущих глав: `ReaderT`, JSON через `aeson`, обработку ошибок.

Это финальный проект книги, объединяющий всё, что мы изучили.

## Обзор стека

| Библиотека | Роль | Аналог |
|---|---|---|
| `scotty` | HTTP-маршруты | Express (JS), Sinatra (Ruby) |
| `persistent` | ORM / слой доступа к БД | Diesel (Rust), SQLAlchemy (Python) |
| `persistent-sqlite` | Бэкенд SQLite | — |
| `aeson` | JSON-сериализация | serde_json (Rust) |
| `monad-logger` | Логирование (нужно persistent) | — |

Почему Scotty, а не Servant? Scotty проще для первого проекта. Servant — мощнее (типобезопасные API, автогенерация клиентов и документации), но требует глубокого понимания type-level программирования.

## Модели данных с persistent

### Определение модели

`persistent` использует Template Haskell для генерации типов, полей и миграций из компактного описания:

```haskell
{-# LANGUAGE QuasiQuotes, TemplateHaskell, TypeFamilies #-}
{-# LANGUAGE DerivingStrategies, StandaloneDeriving #-}
{-# LANGUAGE UndecidableInstances, DataKinds, GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving, MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}

import Database.Persist.TH

share [mkPersist sqlSettings, mkMigrate "migrateAll"] [persistLowerCase|
Todo
    title Text
    completed Bool
    deriving Show Eq
|]
```

Этот код генерирует:

- **Тип** `Todo` с полями `todoTitle :: Text` и `todoCompleted :: Bool`;
- **Тип ключа** `TodoId` (обёртка над `Int64`);
- **GADT полей** `EntityField Todo a` — для типобезопасных запросов:
  - `TodoTitle :: EntityField Todo Text`
  - `TodoCompleted :: EntityField Todo Bool`
- **Миграцию** `migrateAll :: Migration` — создаёт / обновляет таблицу.

Обратите внимание: имена полей в типе — `todoTitle`, `todoCompleted` (имя модели + поле в camelCase). Это отличается от `lens`, где используется подчёркивание.

### Миграции

При запуске приложения выполняем миграцию:

```haskell
import Database.Persist.Sqlite

main :: IO ()
main = runNoLoggingT $ withSqlitePool "todo.db" 5 $ \pool -> liftIO $ do
  runSqlPool (runMigration migrateAll) pool
  -- ... запуск сервера
```

`runMigration migrateAll` создаёт таблицу `todo`, если её нет, и добавляет новые столбцы, если модель изменилась. Столбцы не удаляются — persistent осторожен.

## CRUD-операции

persistent предоставляет типобезопасный API для работы с базой. Все операции выполняются в `SqlPersistT m`, который является `ReaderT SqlBackend m` — знакомый паттерн из главы 12.

### Вставка

```haskell
insertTodo :: Text -> SqlPersistT IO (Key Todo)
insertTodo title = insert (Todo title False)
```

`insert` возвращает ключ (`TodoId`) вставленной записи.

### Чтение

```haskell
-- По ключу:
getTodo :: Key Todo -> SqlPersistT IO (Maybe Todo)
getTodo = get

-- Все записи:
allTodos :: SqlPersistT IO [Entity Todo]
allTodos = selectList [] []

-- С фильтром:
completedTodos :: SqlPersistT IO [Entity Todo]
completedTodos = selectList [TodoCompleted ==. True] []
```

`Entity Todo` — пара из ключа и значения: `Entity { entityKey :: TodoId, entityVal :: Todo }`.

Фильтры типобезопасны. Попытка написать `TodoCompleted ==. "да"` вызовет ошибку компиляции — `TodoCompleted` имеет тип `EntityField Todo Bool`, а не `Text`.

### Обновление

```haskell
completeTodo :: Key Todo -> SqlPersistT IO ()
completeTodo todoId = update todoId [TodoCompleted =. True]

renameTodo :: Key Todo -> Text -> SqlPersistT IO ()
renameTodo todoId newTitle = update todoId [TodoTitle =. newTitle]
```

Оператор `(=.)` устанавливает значение поля. Есть также `(+=.)`, `(-=.)`, `(*=.)` для числовых полей.

### Удаление

```haskell
deleteTodo :: Key Todo -> SqlPersistT IO ()
deleteTodo = delete

-- Массовое удаление:
deleteCompleted :: SqlPersistT IO ()
deleteCompleted = deleteWhere [TodoCompleted ==. True]
```

### Выполнение запросов

Запросы выполняются через пул соединений:

```haskell
runDB :: ConnectionPool -> SqlPersistT IO a -> IO a
runDB = flip runSqlPool
```

```text
> pool <- createPool  -- in-memory для демонстрации
> runDB pool $ insertTodo "Купить молоко"
TodoKey {unTodoKey = SqlBackendKey {unSqlBackendKey = 1}}

> runDB pool allTodos
[Entity {entityKey = ..., entityVal = Todo {todoTitle = "Купить молоко", todoCompleted = False}}]
```

## HTTP-маршруты со Scotty

### Основы Scotty

Scotty — минималистичный DSL для описания маршрутов:

```haskell
import Web.Scotty
import Data.Aeson (ToJSON, FromJSON)

main :: IO ()
main = scotty 3000 $ do
  get "/hello" $ do
    text "Привет, мир!"

  get "/hello/:name" $ do
    name <- pathParam "name"
    text ("Привет, " <> name <> "!")
```

Основные функции:
- `get`, `post`, `put`, `delete` — маршруты по HTTP-методу;
- `pathParam` — параметр из URL (`/todos/:id`);
- `queryParam` — параметр из строки запроса (`?completed=true`);
- `jsonData` — десериализация JSON из тела запроса;
- `json` — сериализация ответа в JSON;
- `status` — установка HTTP-статуса.

### REST API для Todo

```haskell
{-# LANGUAGE DeriveGeneric, OverloadedStrings #-}

import GHC.Generics (Generic)
import Data.Aeson (ToJSON, FromJSON)
import Network.HTTP.Types.Status
import Web.Scotty

-- JSON-представление для API
data TodoDTO = TodoDTO
  { dtoTitle     :: Text
  , dtoCompleted :: Bool
  } deriving stock (Show, Generic)
    deriving anyclass (ToJSON, FromJSON)

todoRoutes :: ConnectionPool -> ScottyM ()
todoRoutes pool = do
  -- GET /todos — список всех задач
  get "/todos" $ do
    todos <- liftIO $ runDB pool allTodos
    json (map toDTO todos)

  -- POST /todos — создать задачу
  post "/todos" $ do
    dto <- jsonData
    todoId <- liftIO $ runDB pool $ insertTodo (dtoTitle dto)
    status created201
    json todoId

  -- GET /todos/:id — получить задачу
  get "/todos/:id" $ do
    todoId <- pathParam "id"
    mTodo <- liftIO $ runDB pool $ get (toSqlKey todoId)
    case mTodo of
      Nothing   -> status notFound404
      Just todo -> json (todoDTOFromModel todo)

  -- DELETE /todos/:id — удалить задачу
  delete "/todos/:id" $ do
    todoId <- pathParam "id"
    liftIO $ runDB pool $ delete (toSqlKey todoId :: Key Todo)
    status noContent204
```

## Связываем всё вместе

Полный `Main.hs`:

```haskell
module Main where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Logger (runNoLoggingT)
import Database.Persist.Sqlite
import Web.Scotty

main :: IO ()
main = runNoLoggingT $ withSqlitePool "todo.db" 5 $ \pool -> liftIO $ do
  runSqlPool (runMigration migrateAll) pool
  putStrLn "Сервер запущен на порту 3000"
  scotty 3000 (todoRoutes pool)
```

Обратите внимание на знакомый паттерн: `withSqlitePool` создаёт пул, передаёт его замыканию, а при завершении автоматически закрывает все соединения — аналог `bracket` из главы 12.

### Тестирование с curl

```bash
# Создать задачу
$ curl -X POST http://localhost:3000/todos \
  -H "Content-Type: application/json" \
  -d '{"dtoTitle": "Купить молоко", "dtoCompleted": false}'

# Список задач
$ curl http://localhost:3000/todos

# Удалить задачу
$ curl -X DELETE http://localhost:3000/todos/1
```

## Когда что использовать

| Задача | Библиотека |
|---|---|
| Простой REST API, прототип | Scotty |
| Типобезопасный API, автодокументация | Servant |
| Базовые SQL-запросы | persistent |
| Сложные SQL (JOIN, подзапросы) | Esqueleto (надстройка над persistent) |
| Работа с PostgreSQL | persistent-postgresql |

### Дальнейшие шаги

- **Servant** — типобезопасные API: тип маршрута кодирует URL, методы, типы запросов/ответов. Компилятор проверяет корректность сервера и клиента.
- **Esqueleto** — SQL DSL для persistent: `JOIN`, подзапросы, агрегации.
- **Beam** — альтернативная ORM с type-safe SQL без Template Haskell.
- **Docker / Nix** — деплой Haskell-приложений.

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

Модуль `Data.Todo` предоставляет тип `Todo` (с полями `todoTitle`, `todoCompleted`), `TodoId`, `EntityField` для фильтров, а также `withTestDb` и `runDB` для работы с in-memory SQLite.

Все функции работают в `SqlPersistT IO` — это `ReaderT SqlBackend IO`. Используйте функции из `Database.Persist`: `insert`, `get`, `update`, `selectList`, `deleteWhere` и операторы `(=.)`, `(==.)`.

1. **(Лёгкое)** Реализуйте вставку задачи:

    ```haskell
    insertTodo :: Text -> SqlPersistT IO (Key Todo)
    ```

    Вставьте `Todo` с заданным заголовком и `completed = False`. Верните ключ.

2. **(Среднее)** Реализуйте переключение статуса задачи:

    ```haskell
    toggleTodo :: Key Todo -> SqlPersistT IO ()
    ```

    Прочитайте задачу по ключу (`get`), инвертируйте `completed` (`not`), запишите обратно (`update` с `=.`). Если задача не найдена — ничего не делайте.

3. **(Среднее)** Реализуйте фильтрацию по статусу:

    ```haskell
    filteredTodos :: Bool -> SqlPersistT IO [Entity Todo]
    ```

    Используйте `selectList` с фильтром `[TodoCompleted ==. status]`.

4. **(Продвинутое)** Реализуйте архивацию завершённых задач:

    ```haskell
    archiveDone :: SqlPersistT IO Int
    ```

    Подсчитайте количество завершённых задач, удалите их (`deleteWhere`), верните количество удалённых.

## Заключение

В этой главе мы:

- Познакомились со стеком для веб-разработки на Haskell: Scotty + persistent.
- Определили модель данных с persistent и Template Haskell.
- Освоили типобезопасные CRUD-операции: `insert`, `get`, `update`, `delete`, `selectList`.
- Построили REST API со Scotty.
- Связали всё вместе через пул соединений и `ReaderT`.

Это финальная техническая глава книги. В [заключении](conclusion.md) — карта пройденного пути и направления для дальнейшего роста.
