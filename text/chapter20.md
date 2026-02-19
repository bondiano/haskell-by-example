# Линзы и оптики

В предыдущих главах мы освоили GADTs, семейства типов и типобезопасный конструктор запросов. Наш трекер задач стал сложнее: вложенные записи, конфигурации, пользовательские настройки. И тут Haskell сталкивается с одной из своих знаменитых проблем — **обновление вложенных записей**. Эта глава посвящена элегантному решению: **линзам**. Мы разберём, почему обновление глубоко вложенных полей мучительно без специальных инструментов, изучим библиотеку **lens** (`makeLenses`, `view`, `set`, `over` и операторы `(^.)`, `(.~)`, `(%~)`), познакомимся с **призмами** для типов-сумм и **traversal** для обхода нескольких целей одновременно. В проекте применим всё это к вложенной конфигурации трекера задач.

## Подготовка проекта

Код этой главы находится в `exercises/chapter20`. Соберите проект:

```text
$ cd exercises/chapter20
$ stack build
```

В `package.yaml` потребуется зависимость `lens`:

```yaml
dependencies:
  - base >= 4.7 && < 5
  - lens
  - text
```

## Проблема вложенных записей

### Иммутабельность и вложенность

В Haskell все данные иммутабельны. Чтобы «изменить» поле записи, мы создаём *новую* запись с изменённым полем. Для плоских записей это терпимо:

```haskell
data Task = Task
  { taskTitle    :: Text
  , taskPriority :: Priority
  , taskStatus   :: Status
  } deriving (Show, Eq)

-- Изменить статус — одна строка
completeTask :: Task -> Task
completeTask task = task { taskStatus = Done }
```

Но что если записи вложены?

```haskell
data AppConfig = AppConfig
  { appDatabase :: DatabaseConfig
  , appServer   :: ServerConfig
  , appFeatures :: FeatureFlags
  } deriving (Show)

data DatabaseConfig = DatabaseConfig
  { dbHost     :: Text
  , dbPort     :: Int
  , dbPool     :: PoolConfig
  } deriving (Show)

data PoolConfig = PoolConfig
  { poolMinSize :: Int
  , poolMaxSize :: Int
  , poolTimeout :: Int
  } deriving (Show)

data ServerConfig = ServerConfig
  { serverHost :: Text
  , serverPort :: Int
  } deriving (Show)

data FeatureFlags = FeatureFlags
  { enableNotifications :: Bool
  , enableAnalytics     :: Bool
  } deriving (Show)
```

### Кошмар обновлений

Попробуем изменить `poolMaxSize` — поле на глубине трёх уровней:

```haskell
-- Изменить максимальный размер пула соединений
setPoolMaxSize :: Int -> AppConfig -> AppConfig
setPoolMaxSize newSize config =
  config
    { appDatabase = (appDatabase config)
        { dbPool = (dbPool (appDatabase config))
            { poolMaxSize = newSize
            }
        }
    }
```

Это *ужасно*. Каждый уровень вложенности требует повторного разворачивания и заворачивания записи. А если нужно изменить два поля на разных уровнях — код удваивается. Это одна из самых частых жалоб новичков в Haskell.

```admonish tip title="Знакомый аналог"
**JavaScript:** spread-оператор: `{ ...config, database: { ...config.database, pool: { ...config.database.pool, maxSize: 100 } } }` — та же проблема, та же вложенность.
**TypeScript:** аналогично JavaScript, но с типами.
**Rust:** нет записей с именованными полями в стиле Haskell, но аналогичная проблема с вложенными `struct`.
**Clojure:** `assoc-in`, `update-in` — решение на уровне библиотеки. Линзы — Haskell-аналог.
```

## Что такое линза

### Интуиция

**Линза** (lens) — «фокус» на часть структуры данных. Она позволяет *читать* и *модифицировать* фокусируемую часть, не зная о контексте.

Линзу можно представить как пару функций:

```haskell
-- Концептуально (не настоящее определение):
type SimpleLens s a = (s -> a, a -> s -> s)
--                     getter    setter
```

Где:

- `s` — тип всей структуры.
- `a` — тип фокусируемой части.
- `getter` — извлекает `a` из `s`.
- `setter` — заменяет `a` в `s`, возвращая новый `s`.

### Композиция — ключевое свойство

Самое мощное свойство линз — **композиция**. Если у нас есть линза на `database` в `config` и линза на `pool` в `database`, их *композиция* — линза на `pool` в `config`:

```text
configToDatabase . databaseToPool . poolToMaxSize
^^^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^
AppConfig →         DbConfig →      PoolConfig →
  DatabaseConfig      PoolConfig       Int
```

Композиция линз — это обычная композиция функций `(.)`. Вместо трёх уровней вложенности — одна строка.

## Библиотека lens

### Установка и импорт

```haskell
import Control.Lens

-- Или точечные импорты для контроля:
import Control.Lens (makeLenses, view, set, over, (^.), (.~), (%~), (&))
```

### `makeLenses` — генерация линз через Template Haskell

```haskell
{-# LANGUAGE TemplateHaskell #-}

data PoolConfig = PoolConfig
  { _poolMinSize :: Int
  , _poolMaxSize :: Int
  , _poolTimeout :: Int
  } deriving (Show)

makeLenses ''PoolConfig
-- Генерирует:
-- poolMinSize :: Lens' PoolConfig Int
-- poolMaxSize :: Lens' PoolConfig Int
-- poolTimeout :: Lens' PoolConfig Int
```

```admonish warning title="Конвенция: подчёркивание"
`makeLenses` ожидает, что имена полей начинаются с `_` (подчёркивание). Без подчёркивания — используйте `makeLensesWith` или `makeClassy`. Подчёркивание убирается в имени линзы: `_poolMaxSize` -> `poolMaxSize`.
```

Аналогично для остальных типов:

```haskell
data DatabaseConfig = DatabaseConfig
  { _dbHost :: Text
  , _dbPort :: Int
  , _dbPool :: PoolConfig
  } deriving (Show)
makeLenses ''DatabaseConfig

data ServerConfig = ServerConfig
  { _serverHost :: Text
  , _serverPort :: Int
  } deriving (Show)
makeLenses ''ServerConfig

data FeatureFlags = FeatureFlags
  { _enableNotifications :: Bool
  , _enableAnalytics     :: Bool
  } deriving (Show)
makeLenses ''FeatureFlags

data AppConfig = AppConfig
  { _appDatabase :: DatabaseConfig
  , _appServer   :: ServerConfig
  , _appFeatures :: FeatureFlags
  } deriving (Show)
makeLenses ''AppConfig
```

После каждого `makeLenses` в области видимости появляются линзы с именами, совпадающими с именами полей без подчёркивания: `dbHost :: Lens' DatabaseConfig Text`, `dbPool :: Lens' DatabaseConfig PoolConfig`, `appDatabase :: Lens' AppConfig DatabaseConfig` и т.д. Теперь все эти линзы можно компоновать через `.`.

### `view` (`^.`) — чтение

```haskell
-- view :: Lens' s a -> s -> a
-- (^.) :: s -> Lens' s a -> a  (инфиксная версия)

getMaxPoolSize :: AppConfig -> Int
getMaxPoolSize config = view (appDatabase . dbPool . poolMaxSize) config

-- Или через оператор:
getMaxPoolSize' :: AppConfig -> Int
getMaxPoolSize' config = config ^. appDatabase . dbPool . poolMaxSize
```

```text
> config ^. appDatabase . dbPool . poolMaxSize
10
> config ^. appServer . serverPort
8080
```

Композиция через `.` читается *слева направо* — от внешнего к внутреннему. Это может показаться контринтуитивным (обычная композиция функций работает справа налево), но для линз именно такой порядок естественен.

### `set` (`.~`) — запись

```haskell
-- set :: Lens' s a -> a -> s -> s
-- (.~) :: Lens' s a -> a -> s -> s  (инфиксная версия)

setMaxPoolSize :: Int -> AppConfig -> AppConfig
setMaxPoolSize n = set (appDatabase . dbPool . poolMaxSize) n

-- Через оператор и (&):
setMaxPoolSize' :: Int -> AppConfig -> AppConfig
setMaxPoolSize' n config = config & appDatabase . dbPool . poolMaxSize .~ n
```

```text
> config & appDatabase . dbPool . poolMaxSize .~ 50
-- AppConfig с изменённым poolMaxSize = 50
```

Оператор `(&)` — это `flip ($)`: он позволяет писать «объект, а потом операции», как в ООП-стиле.

### `over` (`%~`) — модификация

```haskell
-- over :: Lens' s a -> (a -> a) -> s -> s
-- (%~) :: Lens' s a -> (a -> a) -> s -> s

doublePoolSize :: AppConfig -> AppConfig
doublePoolSize config = config & appDatabase . dbPool . poolMaxSize %~ (* 2)

incrementPort :: AppConfig -> AppConfig
incrementPort config = config & appServer . serverPort %~ (+ 1)
```

```text
> config & appDatabase . dbPool . poolMaxSize %~ (* 2)
-- poolMaxSize стал 20 (был 10)

> config & appFeatures . enableAnalytics %~ not
-- переключили флаг аналитики
```

### Множественные обновления

Оператор `(&)` позволяет цеплять обновления:

```haskell
updateConfig :: AppConfig -> AppConfig
updateConfig config = config
  & appDatabase . dbPool . poolMaxSize .~ 50
  & appDatabase . dbPool . poolTimeout .~ 30
  & appServer . serverPort .~ 9090
  & appFeatures . enableNotifications .~ True
```

Сравните с кодом без линз — разница драматическая.

```admonish note title="Шпаргалка по операторам"
| Оператор | Функция | Что делает |
|----------|---------|------------|
| `^.` | `view` | Прочитать значение через линзу |
| `.~` | `set` | Установить значение через линзу |
| `%~` | `over` | Применить функцию через линзу |
| `&` | `flip ($)` | Цепочка операций (pipe) |
| `+~` | — | Прибавить к числовому полю |
| `-~` | — | Вычесть из числового поля |
| `*~` | — | Умножить числовое поле |
| `<>~` | — | Конкатенировать моноидное поле |
```

## Prism: линзы для типов-сумм

### Проблема: фокус может отсутствовать

Линзы работают с типами-произведениями (записями) — фокус всегда существует. Но что делать с типами-суммами, где значение может быть *одним из* вариантов?

```haskell
data FilterExpr
  = StatusFilter Text
  | PriorityFilter Text
  | TagFilter Text
  | NotFilter FilterExpr
```

Если у нас `StatusFilter "done"`, мы можем извлечь текст. Но если `NotFilter (...)` — текста в `StatusFilter` нет. Нужен инструмент, который *может не совпасть*.

### Prism — «линза» для конструкторов

**Prism** — оптика для типов-сумм. Она может *попытаться* сфокусироваться на конструкторе:

```haskell
import Control.Lens

-- makePrisms генерирует призмы для конструкторов
makePrisms ''FilterExpr
-- Генерирует:
-- _StatusFilter   :: Prism' FilterExpr Text
-- _PriorityFilter :: Prism' FilterExpr Text
-- _TagFilter      :: Prism' FilterExpr Text
-- _NotFilter      :: Prism' FilterExpr FilterExpr
```

```admonish note title="Конвенция: подчёркивание для призм"
`makePrisms` генерирует призмы с префиксом `_` и именем конструктора. В отличие от `makeLenses`, здесь подчёркивание *добавляется*, а не убирается.
```

### Использование призм

```haskell
-- preview (^?) — попытка чтения (возвращает Maybe)
-- (^?) :: s -> Prism' s a -> Maybe a

expr1 = StatusFilter "done"
expr2 = NotFilter (TagFilter "work")

expr1 ^? _StatusFilter    -- Just "done"
expr2 ^? _StatusFilter    -- Nothing
expr2 ^? _NotFilter       -- Just (TagFilter "work")

-- review (#) — создание значения через призму
_StatusFilter # "done"    -- StatusFilter "done"
_TagFilter # "work"       -- TagFilter "work"
```

### `_Just`, `_Nothing`, `_Left`, `_Right`

Библиотека lens предоставляет призмы для стандартных типов:

```haskell
Just 42 ^? _Just     -- Just 42
Nothing ^? _Just     -- Nothing

Left "err" ^? _Left  -- Just "err"
Right 42 ^? _Right   -- Just 42
```

## Traversal: обход нескольких целей

### Фокус на несколько элементов

**Traversal** — оптика, которая фокусируется на *нескольких* элементах одновременно. Линза фокусируется ровно на одном, призма — на нуле или одном, traversal — на нуле или более.

```haskell
-- each — traversal для элементов контейнера
[1, 2, 3] & each %~ (* 10)
-- [10, 20, 30]

-- traverse всё через линзу
("hello", "world") & each %~ T.toUpper
-- ("HELLO", "WORLD")

-- Только чётные элементы: filteredIndexed или traversed с filtered
[1, 2, 3, 4, 5] ^.. traversed . filtered even
-- [2, 4]
```

### `toListOf` (`^..`) — собрать все фокусы

```haskell
-- (^..) :: s -> Traversal' s a -> [a]

config ^.. appDatabase . dbPool . poolMinSize
-- [5]    -- линза всегда даёт один элемент

tasks ^.. traversed . taskPriority'
-- [High, Low, Medium, High]   -- приоритеты всех задач
```

### Traversal в проекте

```haskell
-- Увеличить все числовые настройки пула на 10
boostPool :: AppConfig -> AppConfig
boostPool config = config
  & appDatabase . dbPool . poolMinSize +~ 10
  & appDatabase . dbPool . poolMaxSize +~ 10
```

## Проект: конфигурация трекера задач

### Определение типов с линзами

```haskell
{-# LANGUAGE TemplateHaskell #-}

import Control.Lens
import Data.Text (Text)

data NotificationConfig = NotificationConfig
  { _notifEmail   :: Bool
  , _notifSlack   :: Bool
  , _notifWebhook :: Maybe Text
  } deriving (Show)
makeLenses ''NotificationConfig

data DisplayConfig = DisplayConfig
  { _pageSize      :: Int
  , _showCompleted :: Bool
  , _dateFormat    :: Text
  } deriving (Show)
makeLenses ''DisplayConfig

data TrackerConfig = TrackerConfig
  { _trackerDb       :: DatabaseConfig
  , _trackerServer   :: ServerConfig
  , _trackerNotif    :: NotificationConfig
  , _trackerDisplay  :: DisplayConfig
  } deriving (Show)
makeLenses ''TrackerConfig
```

### Операции с конфигурацией

Сгенерированные линзы позволяют удобно читать и обновлять вложенные поля через цепочки операторов:

```haskell
-- Прочитать формат даты
getDateFormat :: TrackerConfig -> Text
getDateFormat cfg = cfg ^. trackerDisplay . dateFormat

-- Включить email-уведомления
enableEmail :: TrackerConfig -> TrackerConfig
enableEmail = trackerNotif . notifEmail .~ True

-- Установить webhook URL
setWebhook :: Text -> TrackerConfig -> TrackerConfig
setWebhook url = trackerNotif . notifWebhook .~ Just url

-- Увеличить размер страницы
bumpPageSize :: TrackerConfig -> TrackerConfig
bumpPageSize = trackerDisplay . pageSize %~ min 100 . (+ 10)

-- Комплексное обновление для продакшена
productionConfig :: TrackerConfig -> TrackerConfig
productionConfig cfg = cfg
  & trackerDb . dbPool . poolMaxSize .~ 50
  & trackerDb . dbPool . poolTimeout .~ 5
  & trackerServer . serverPort .~ 443
  & trackerNotif . notifEmail .~ True
  & trackerNotif . notifSlack .~ True
  & trackerDisplay . showCompleted .~ False
  & trackerDisplay . pageSize .~ 25
```

### Работа с Maybe через `_Just`

Призма `_Just` позволяет применять операции к полям типа `Maybe`, игнорируя `Nothing` без явной проверки:

```haskell
-- Преобразовать webhook URL, если он задан
uppercaseWebhook :: TrackerConfig -> TrackerConfig
uppercaseWebhook = trackerNotif . notifWebhook . _Just %~ T.toUpper

-- Проверить, задан ли webhook
hasWebhook :: TrackerConfig -> Bool
hasWebhook cfg = has (trackerNotif . notifWebhook . _Just) cfg
```

### Работа со списком задач

Traversal `traversed` обходит все элементы списка, позволяя применять операции ко всем задачам или к подмножеству через `filtered`:

```haskell
-- Линзы для Task (допустим, поля с подчёркиванием)
data Task = Task
  { _taskTitle    :: Text
  , _taskPriority :: Priority
  , _taskStatus   :: Status
  , _taskTags     :: [Text]
  } deriving (Show)
makeLenses ''Task

-- Завершить все задачи с приоритетом High
completeHighPriority :: [Task] -> [Task]
completeHighPriority = traversed . filtered (\t -> t ^. taskPriority == High) . taskStatus .~ Done

-- Собрать все уникальные теги
allTags :: [Task] -> [Text]
allTags tasks = tasks ^.. traversed . taskTags . traversed

-- Добавить тег ко всем незавершённым задачам
tagPending :: Text -> [Task] -> [Task]
tagPending tag = traversed . filtered (\t -> t ^. taskStatus /= Done) . taskTags %~ (tag :)
```

```admonish tip title="Знакомый аналог"
**JavaScript/Lodash:** `_.get(config, 'database.pool.maxSize')` и `_.set(...)` — линзы через строковые пути. В Haskell линзы типобезопасны: несуществующий путь не скомпилируется.
**Immer (JS):** `produce(config, draft => { draft.database.pool.maxSize = 50 })` — мутабельный API для иммутабельных данных. Линзы решают ту же задачу, но чисто функционально.
```

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

### Проект

1. Определите типы `TrackerConfig`, `DatabaseConfig`, `PoolConfig` с полями, начинающимися на `_`, и сгенерируйте линзы с `makeLenses`. Реализуйте `getPoolMax` и `setPoolMax`:

    ```haskell
    getPoolMax :: TrackerConfig -> Int
    setPoolMax :: Int -> TrackerConfig -> TrackerConfig
    ```

2. Реализуйте `productionConfig`, которая настраивает конфигурацию для продакшена (увеличить пул, сменить порт, включить уведомления) — одной цепочкой `(&)`.

    ```haskell
    productionConfig :: TrackerConfig -> TrackerConfig
    ```

3. Реализуйте `completeHighPriority`, которая завершает все задачи с приоритетом `High` в списке, используя `traversed` и `filtered`.

    ```haskell
    completeHighPriority :: [Task] -> [Task]
    ```

### Практика

4. Без использования Template Haskell определите линзу вручную для поля `_poolMaxSize`:

    ```haskell
    poolMaxSizeL :: Lens' PoolConfig Int
    poolMaxSizeL f pool = (\newMax -> pool { _poolMaxSize = newMax }) <$> f (_poolMaxSize pool)
    ```

    Проверьте, что `view poolMaxSizeL`, `set poolMaxSizeL` и `over poolMaxSizeL` работают.

5. Используя `_Just` и `_Left`, реализуйте функции:

    ```haskell
    -- Увеличить число внутри Just, если оно там
    incrementMaybe :: Maybe Int -> Maybe Int
    -- incrementMaybe (Just 5) == Just 6
    -- incrementMaybe Nothing  == Nothing

    -- Преобразовать ошибку в Left, если она там
    uppercaseError :: Either Text a -> Either Text a
    -- uppercaseError (Left "err") == Left "ERR"
    -- uppercaseError (Right 42)   == Right 42
    ```

6. Реализуйте `allTags`, которая собирает все теги из списка задач:

    ```haskell
    allTags :: [Task] -> [Text]
    -- allTags [Task{_taskTags=["a","b"]}, Task{_taskTags=["b","c"]}]
    -- == ["a","b","b","c"]
    ```

    *Подсказка:* `tasks ^.. traversed . taskTags . traversed`.

## Заключение

Линзы — одна из самых характерных библиотек экосистемы Haskell. Они показывают, как функциональный подход решает проблемы, которые в императивных языках решаются мутабельностью. Кривая обучения крутая, но результат того стоит: код становится компактным, композируемым и типобезопасным. Мы прошли от проблемы вложенных записей через основные операции (`view`, `set`, `over`) к призмам для типов-сумм и traversal для обхода нескольких целей. Всё это работает через единый механизм — композицию оптик обычным оператором `(.)`.

В [следующей главе](chapter21.md) мы подведём итоги книги и наметим пути для дальнейшего изучения Haskell.

```admonish tip title="Для углубления"
- **lens** — [официальная документация](https://hackage.haskell.org/package/lens) и [вики](https://github.com/ekmett/lens/wiki). Обширна, но может быть сложна для начинающих.
- **Program Imperatively using Haskell Lenses** — [туториал от FP Complete](https://www.fpcomplete.com/haskell/tutorial/lens/): практичное введение.
- **optics** — [альтернативная библиотека](https://hackage.haskell.org/package/optics) с более простыми типами. Стоит рассмотреть как альтернативу `lens`.
- **Haskell Lens Operator Onboarding** — [шпаргалка по операторам](https://github.com/ekmett/lens/wiki/operators): незаменима при работе с lens.
```
