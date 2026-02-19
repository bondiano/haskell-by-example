# Организация проекта

Добро пожаловать в четвёртую часть книги! До сих пор мы писали код в отдельных упражнениях — один пакет, один модуль, никакой структуры. Реальные Haskell-проекты устроены иначе. Здесь мы разберём систему модулей (объявления, экспорт, импорт), научимся ограничивать видимость, освоим паттерны реэкспорта и `Internal`-модулей, поймём структуру пакета с library/executable/test и настроим базовый CI/CD. Завершим главу реструктуризацией трекера задач в модульную иерархию.

## Модули Haskell

Каждый файл `.hs` начинается с объявления модуля:

```haskell
module TaskTracker.Types where

data Priority = Low | Medium | High
  deriving (Show, Eq, Ord)
```

Имя модуля должно совпадать с путём к файлу: `TaskTracker.Types` живёт в `src/TaskTracker/Types.hs`. Точка соответствует разделителю директорий.

```text
src/
├── TaskTracker/
│   ├── Types.hs       -- module TaskTracker.Types
│   ├── Storage.hs     -- module TaskTracker.Storage
│   ├── Filter.hs      -- module TaskTracker.Filter
│   └── CLI.hs         -- module TaskTracker.CLI
└── TaskTracker.hs     -- module TaskTracker (реэкспорт)
```

Если объявление `module` отсутствует, модуль получает имя `Main` — допустимо только для исполняемых файлов.

```admonish tip title="Знакомый аналог"
**TypeScript:** каждый файл — модуль, путь = имя (`import { Task } from './TaskTracker/Types'`).
**Python:** пакеты через каталоги с `__init__.py` (`from task_tracker.types import Task`).
**Go:** пакеты = каталоги (`import "tasktracker/types"`).
Haskell ближе всего к Java: имя модуля = путь к файлу.
```

## Экспорт и импорт

### Экспорт

По умолчанию (`module M where`) экспортируется **всё**. Чтобы ограничить видимость, перечислите имена в скобках:

```haskell
module TaskTracker.Types
  ( Priority(..)    -- тип и ВСЕ конструкторы
  , Status(..)
  , Task(..)        -- тип и все поля-аксессоры
  , TaskId
  , mkTask
  ) where
```

| Запись | Что экспортирует |
|---|---|
| `Priority(..)` | Тип и все конструкторы (`Low`, `Medium`, `High`) |
| `Priority` | Только тип, без конструкторов (абстрактный тип) |
| `Priority(Low, High)` | Тип и только указанные конструкторы |
| `mkTask` | Функция `mkTask` |

Экспорт без конструкторов создаёт **абстрактный тип** — основной механизм инкапсуляции:

```haskell
module TaskTracker.Types (TaskId, mkTaskId, unTaskId) where

newtype TaskId = TaskId Int deriving (Show, Eq, Ord)

mkTaskId :: Int -> Maybe TaskId
mkTaskId n
  | n > 0     = Just (TaskId n)
  | otherwise = Nothing

unTaskId :: TaskId -> Int
unTaskId (TaskId n) = n
```

Клиентский код не может создать `TaskId` с отрицательным значением — инвариант гарантирован на уровне модуля.

```admonish warning title="Не экспортируйте всё подряд"
`module M where` (без списка экспорта) удобно при прототипировании, но в библиотечном коде всегда указывайте явный список экспорта. Это документирует API, защищает инварианты и позволяет рефакторить без риска сломать клиентов.
```

### Импорт

```haskell
import TaskTracker.Types                       -- всё из модуля
import TaskTracker.Types (Task, Priority(..))  -- только перечисленное
import Data.Map.Strict qualified as Map        -- квалифицированный
import Prelude hiding (lookup)                 -- всё кроме lookup
```

С расширением `ImportQualifiedPost` (включённым в нашем проекте) `qualified` пишется *после* имени модуля — это читается естественнее и лучше группируется визуально.

```admonish note title="Правила хорошего тона"
1. Группируйте: стандартные, сторонние, внутренние модули.
2. Квалифицируйте контейнеры: `Map`, `Set`, `Text` — через `qualified as`.
3. Явный импорт для небольших наборов: `import Data.Maybe (fromMaybe, isJust)`.
```

## Конвенция Internal и реэкспорт

### Internal-модули

В Haskell нет `private`/`protected`. Вместо этого модули с суффиксом `Internal` содержат детали реализации:

```haskell
-- TaskTracker.Types.Internal: конструкторы и внутренние функции
module TaskTracker.Types.Internal where

newtype TaskId = TaskId Int deriving (Show, Eq, Ord)
unsafeMkTaskId :: Int -> TaskId
unsafeMkTaskId = TaskId
```

```haskell
-- TaskTracker.Types: публичный API, реэкспортирует безопасные функции
module TaskTracker.Types (TaskId, mkTaskId, unTaskId) where

import TaskTracker.Types.Internal (TaskId(..))

mkTaskId :: Int -> Maybe TaskId
mkTaskId n | n > 0 = Just (TaskId n) | otherwise = Nothing

unTaskId :: TaskId -> Int
unTaskId (TaskId n) = n
```

Технически `Internal`-модуль можно импортировать — но конвенция ясна: на свой страх и риск.

### Паттерн реэкспорта

Единая точка входа для библиотеки:

```haskell
module TaskTracker
  ( module TaskTracker.Types
  , module TaskTracker.Storage
  , module TaskTracker.Filter
  ) where

import TaskTracker.Types
import TaskTracker.Storage
import TaskTracker.Filter
```

Пользователю хватит `import TaskTracker` вместо трёх отдельных импортов.

## Организация пакета

### Структура реального проекта

```text
task-tracker/
├── package.yaml              -- описание пакета (hpack)
├── stack.yaml                -- конфигурация Stack
├── src/                      -- библиотека (library)
│   ├── TaskTracker.hs
│   └── TaskTracker/
│       ├── Types.hs
│       ├── Storage.hs
│       └── Filter.hs
├── app/                      -- исполняемый файл (executable)
│   └── Main.hs
└── test/                     -- тесты
    ├── Spec.hs
    └── TaskTracker/
        └── TypesSpec.hs
```

### package.yaml

```yaml
name: task-tracker
version: 0.1.0.0

dependencies:
  - base >= 4.7 && < 5
  - text
  - containers

default-extensions:
  - OverloadedStrings
  - DerivingStrategies
  - ImportQualifiedPost
  - NamedFieldPuns
  - LambdaCase

library:
  source-dirs: src
  exposed-modules:
    - TaskTracker
    - TaskTracker.Types
    - TaskTracker.Storage
    - TaskTracker.Filter

executables:
  task-tracker-exe:
    main: Main.hs
    source-dirs: app
    dependencies:
      - task-tracker   # зависимость от собственной библиотеки

tests:
  task-tracker-test:
    main: Spec.hs
    source-dirs: test
    dependencies:
      - task-tracker
      - hspec
```

- **library** — бизнес-логика в `src/`.
- **executables** — точка входа, зависит от библиотеки.
- **tests** — тесты, тоже зависят от библиотеки.

```haskell
-- app/Main.hs — минимальная точка входа
module Main where

import TaskTracker.CLI (runApp)

main :: IO ()
main = runApp
```

```admonish note title="hpack vs. cabal"
`package.yaml` (hpack) — более лаконичная альтернатива `.cabal`-файлу. Stack автоматически генерирует `.cabal` из `package.yaml`. При использовании `cabal-install` без Stack можно писать `.cabal` напрямую.
```

## Custom Prelude

В больших проектах стандартный `Prelude` иногда заменяют собственным — чтобы исключить частичные функции (`head`, `tail`) и добавить часто используемые типы:

```haskell
module TaskTracker.Prelude
  ( module Prelude, Text, tshow ) where

import Prelude hiding (head, tail, read)
import Data.Text (Text, pack)

tshow :: Show a => a -> Text
tshow = pack . show
```

Использование: в `package.yaml` добавьте `NoImplicitPrelude`, в модулях — `import TaskTracker.Prelude`.

```admonish warning title="Когда НЕ стоит"
Custom Prelude вносит порог входа для новых участников. Для небольших проектов и библиотек стандартный `Prelude` — лучший выбор.
```

## CI/CD с GitHub Actions

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: haskell-actions/setup@v2
        with:
          ghc-version: '9.6.7'
          enable-stack: true

      - name: Cache Stack
        uses: actions/cache@v4
        with:
          path: |
            ~/.stack
            .stack-work
          key: ${{ runner.os }}-stack-${{ hashFiles('stack.yaml.lock') }}

      - name: Build
        run: stack build

      - name: Test
        run: stack test

      - name: HLint
        run: curl -sSL https://raw.github.com/ndmitchell/hlint/master/misc/run.sh | sh -s src/

      - name: Fourmolu
        run: |
          stack install fourmolu
          fourmolu --mode check src/
```

**HLint** — линтер с идиоматическими подсказками. **Fourmolu** — форматтер кода.

```admonish tip title="Знакомый аналог"
**TypeScript:** ESLint + Prettier. **Python:** ruff + black. **Go:** golangci-lint + gofmt.
```

## Проект: модульная структура трекера

### TaskTracker.Types

```haskell
module TaskTracker.Types
  ( Priority(..), showPriority
  , Status(..), showStatus
  , Task(..), mkTask
  , TaskId, TaskStore(..)
  ) where

import Data.Map.Strict qualified as Map
import Data.Text (Text)

data Priority = Low | Medium | High
  deriving (Show, Eq, Ord, Enum, Bounded)

showPriority :: Priority -> String
showPriority Low = "Низкий"; showPriority Medium = "Средний"; showPriority High = "Высокий"

data Status = Todo | InProgress | Done
  deriving (Show, Eq, Ord, Enum, Bounded)

showStatus :: Status -> String
showStatus Todo = "К выполнению"; showStatus InProgress = "В работе"; showStatus Done = "Выполнено"

data Task = Task
  { taskTitle :: Text, taskDescription :: Text
  , taskPriority :: Priority, taskStatus :: Status
  } deriving (Show, Eq)

mkTask :: Text -> Priority -> Task
mkTask title prio = Task title "" prio Todo

type TaskId = Int
newtype TaskStore = TaskStore { unTaskStore :: Map.Map TaskId Task }
  deriving (Show, Eq)
```

Обратите внимание на явный список экспорта: `Priority(..)` открывает конструкторы (`Low`, `Medium`, `High`), тогда как `TaskId` экспортируется без конструктора (он — `type`-синоним). `Enum` и `Bounded` позволяют перечислять все значения через `[minBound..maxBound]`. `mkTask` — умный конструктор, который задаёт разумные значения по умолчанию.

### TaskTracker.Storage

```haskell
module TaskTracker.Storage
  ( emptyStore, addTask, deleteTask, completeTask, lookupTask, allTasks ) where

import Data.Map.Strict qualified as Map
import TaskTracker.Types

emptyStore :: TaskStore
emptyStore = TaskStore Map.empty

addTask :: Task -> TaskId -> TaskStore -> (TaskStore, TaskId)
addTask task nextId (TaskStore m) =
  (TaskStore (Map.insert nextId task m), nextId + 1)

deleteTask :: TaskId -> TaskStore -> TaskStore
deleteTask tid (TaskStore m) = TaskStore (Map.delete tid m)

completeTask :: TaskId -> TaskStore -> Either String TaskStore
completeTask tid (TaskStore m) = case Map.lookup tid m of
  Nothing   -> Left $ "Задача #" <> show tid <> " не найдена"
  Just task -> Right (TaskStore (Map.insert tid (task { taskStatus = Done }) m))

lookupTask :: TaskId -> TaskStore -> Maybe Task
lookupTask tid (TaskStore m) = Map.lookup tid m

allTasks :: TaskStore -> [(TaskId, Task)]
allTasks (TaskStore m) = Map.toAscList m
```

Каждая функция хранилища принимает и возвращает `TaskStore` явно — без глобального состояния. `completeTask` возвращает `Either String`: это позволяет вызывающей стороне обработать случай отсутствия задачи без исключений. `addTask` возвращает `(TaskStore, TaskId)` — следующий свободный идентификатор, чтобы вызывающий код мог отслеживать его без отдельного счётчика.

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

### Проект ★☆☆

1. Определите модуль `TaskTracker.Stats` с явным экспортом и функцией:

    ```haskell
    data TaskStats = TaskStats
      { totalTasks :: Int, todoCount :: Int, doneCount :: Int, highPriority :: Int
      } deriving (Show, Eq)

    computeStats :: TaskStore -> TaskStats
    ```

2. Определите «умный конструктор» `mkPriority :: String -> Maybe Priority` — парсит `"low"`, `"medium"`, `"high"` (регистронезависимо).

### Проект ★★☆

3. Вынесите `parseCommand` в модуль `TaskTracker.Command`. Экспортируйте `Command(..)` и `parseCommand`, но скройте внутреннюю `parsePriority`.

4. Создайте модуль `TaskTracker.Render` с функциями форматирования:

    ```haskell
    renderTask :: (TaskId, Task) -> String
    renderTaskList :: [(TaskId, Task)] -> String
    renderStats :: TaskStats -> String
    ```

### Практика ★☆☆

5. Напишите модуль с абстрактным типом `NonEmptyText` — гарантирует, что текст не пустой:

    ```haskell
    module NonEmptyText (NonEmptyText, mkNonEmptyText, unNonEmptyText) where
    ```

6. Напишите модуль, реэкспортирующий `Data.Map.Strict` с утилитой `lookupDefault :: Ord k => v -> k -> Map k v -> v`.

### Практика ★★☆

7. Создайте `TaskTracker.Import`, парсящий CSV в список задач:

    ```haskell
    parseCSV :: Text -> Either String [Task]
    ```

8. Напишите `package.yaml` для трекера с тремя компонентами (library, executable, test) и `exposed-modules`.

## Заключение

Система модулей в Haskell проста, но выразительна: явный экспорт создаёт абстрактные типы, конвенция `Internal` заменяет `private`, реэкспорт собирает библиотеку в единую точку входа. Структура пакета (library + executable + test) отделяет бизнес-логику от точки входа и тестов. С этими знаниями трекер задач превратился из монолитного файла в модульную иерархию.

В [следующей главе](chapter16.md) мы перейдём к конкурентности — потокам, `async` и STM.

```admonish tip title="Для углубления"
- **Haskell MOOC** — [haskell.mooc.fi](https://haskell.mooc.fi/), лекция 13: «Modules».
- **Cabal User Guide** — [cabal.readthedocs.io](https://cabal.readthedocs.io/).
- **hpack** — [github.com/sol/hpack](https://github.com/sol/hpack).
- **HLint** — [github.com/ndmitchell/hlint](https://github.com/ndmitchell/hlint).
- **Fourmolu** — [github.com/fourmolu/fourmolu](https://github.com/fourmolu/fourmolu).
```
