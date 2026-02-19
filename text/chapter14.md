# JSON и сериализация

В предыдущих главах мы изучили `Functor`, `Applicative` ([глава 11](chapter11.md)), `Monad` ([глава 12](chapter12.md)) и трансформеры ([глава 13](chapter13.md)). Теперь пора применить эти абстракции на практике. Здесь мы познакомимся с библиотекой **aeson** — стандартным инструментом для работы с JSON в Haskell. Пройдём весь путь: от типа `Value` и ручных инстансов `ToJSON`/`FromJSON` до автоматической деривации через `DeriveGeneric`. По ходу дела увидим `Applicative` в действии — парсинг JSON построен на `<$>` и `<*>`. К концу главы трекер задач научится сохранять состояние между запусками.

## Зачем JSON

JSON (JavaScript Object Notation) — универсальный формат обмена данными. Когда программа должна сохранить данные на диск, принять запрос от веб-клиента или обменяться данными с внешним сервисом — JSON первый кандидат. В Haskell стандартная библиотека для работы с JSON — **aeson** (произносится «эйсон»).

```admonish tip title="Знакомый аналог"
**JavaScript:** `JSON.parse()` / `JSON.stringify()` — встроенные функции.
**Python:** модуль `json` — `json.loads()` / `json.dumps()`.
**Rust:** `serde` + `serde_json` — деривация `Serialize`/`Deserialize`.
aeson ближе всего к подходу Rust: сериализация/десериализация определяется через классы типов (аналог трейтов).
```

## Библиотека aeson

### Тип `Value`

В основе aeson лежит тип `Value`, представляющий произвольный JSON-документ:

```haskell
data Value
  = Object Object     -- {"key": value, ...}
  | Array  Array       -- [value, ...]
  | String Text        -- "строка"
  | Number Scientific  -- 42, 3.14
  | Bool   Bool        -- true, false
  | Null               -- null
```

Это алгебраический тип — сумма шести конструкторов. `Object` внутри — это `HashMap Text Value`, `Array` — `Vector Value`. Работать с `Value` напрямую неудобно, поэтому aeson предлагает два класса типов: `ToJSON` и `FromJSON`.

### Зависимости

Добавьте в `package.yaml`:

```yaml
dependencies:
  - base >= 4.18 && < 5
  - aeson
  - text
  - bytestring
```

Импорты:

```haskell
import Data.Aeson (ToJSON, FromJSON, toJSON, parseJSON, encode,
                   decode, eitherDecode, object, (.=), (.:), (.:?),
                   (.!=), withObject, Value(..))
import Data.Text (Text)
import Data.ByteString.Lazy qualified as BL
```

## Кодирование: ToJSON

Класс `ToJSON` описывает, как превратить значение Haskell в JSON:

```haskell
class ToJSON a where
  toJSON :: a -> Value

encode :: ToJSON a => a -> BL.ByteString
```

Для построения JSON-объектов aeson предоставляет оператор `(.=)` и функцию `object`:

```haskell
(.=) :: ToJSON v => Text -> v -> Pair
object :: [Pair] -> Value
```

```text
> encode (object ["name" .= ("Alice" :: Text), "age" .= (30 :: Int)])
"{\"name\":\"Alice\",\"age\":30}"
```

aeson уже определяет `ToJSON` для стандартных типов:

```text
> encode True
"true"
> encode (42 :: Int)
"42"
> encode [1, 2, 3 :: Int]
"[1,2,3]"
> encode (Nothing :: Maybe Int)
"null"
> encode (Just 42 :: Maybe Int)
"42"
```

`Nothing` кодируется как `null`, а `Just x` — как `x` без обёртки.

## Декодирование: FromJSON

Класс `FromJSON` описывает обратное преобразование:

```haskell
class FromJSON a where
  parseJSON :: Value -> Parser a
```

Метод `parseJSON` возвращает `Parser a` — монаду, способную сообщить об ошибке. Для декодирования байтовой строки есть две функции:

```haskell
decode       :: FromJSON a => BL.ByteString -> Maybe a
eitherDecode :: FromJSON a => BL.ByteString -> Either String a
```

```text
> decode "[1,2,3]" :: Maybe [Int]
Just [1,2,3]
> eitherDecode "invalid" :: Either String [Int]
Left "Error in $: not enough input"
```

```admonish warning title="Всегда используйте eitherDecode"
Функция `decode` возвращает `Nothing` при ошибке, теряя информацию о причине. Используйте `eitherDecode` — она возвращает сообщение об ошибке в `Left`, что критически важно для отладки.
```

### Операторы для извлечения полей

Внутри `parseJSON` для доступа к полям JSON-объекта используются:

```haskell
(.:)  :: FromJSON a => Object -> Text -> Parser a          -- обязательное поле
(.:?) :: FromJSON a => Object -> Text -> Parser (Maybe a)  -- необязательное поле
(.!=) :: Parser (Maybe a) -> a -> Parser a                 -- значение по умолчанию
```

- `o .: "name"` — извлечь обязательное поле; ошибка если отсутствует.
- `o .:? "priority"` — вернуть `Nothing` если поле отсутствует.
- `o .:? "priority" .!= Medium` — подставить значение по умолчанию.

```admonish tip title="Знакомый аналог"
**TypeScript:** `(.:)` ~ `obj.name`, `(.:?)` ~ `obj?.name` (optional chaining).
**Python:** `(.:)` ~ `obj["name"]` (KeyError при отсутствии), `(.:?)` ~ `obj.get("name")`.
```

## Автоматическая деривация

aeson поддерживает автоматическую деривацию через `GHC.Generics`:

```haskell
{-# LANGUAGE DeriveGeneric #-}
import GHC.Generics (Generic)

data Priority = Low | Medium | High
  deriving (Show, Eq, Ord, Generic)

instance ToJSON Priority
instance FromJSON Priority
```

Инстансы объявлены **без тела** — aeson генерирует реализации автоматически, анализируя структуру типа через `Generic`.

```text
> encode High
"\"High\""
> decode "\"Medium\"" :: Maybe Priority
Just Medium
```

Для записей имена полей становятся ключами JSON:

```haskell
data Task = Task
  { taskTitle       :: Text
  , taskDescription :: Text
  , taskPriority    :: Priority
  , taskStatus      :: Status
  } deriving (Show, Eq, Generic)

instance ToJSON Task
instance FromJSON Task
```

```text
> encode (Task "Изучить aeson" "" High Todo)
"{\"taskTitle\":\"Изучить aeson\",\"taskDescription\":\"\",\"taskPriority\":\"High\",\"taskStatus\":\"Todo\"}"
```

Это удобно для внутренних форматов, но для внешних API обычно нужны другие имена ключей.

## Ручные экземпляры

Когда нужно переименовать поля, добавить умолчания или изменить формат — пишутся ручные инстансы.

### Ручной ToJSON

```haskell
instance ToJSON Task where
  toJSON Task{..} = object
    [ "title"       .= taskTitle
    , "description" .= taskDescription
    , "priority"    .= taskPriority
    , "status"      .= taskStatus
    ]
```

### Ручной FromJSON

```haskell
instance FromJSON Task where
  parseJSON = withObject "Task" $ \o -> Task
    <$> o .:  "title"
    <*> o .:  "description"
    <*> o .:? "priority" .!= Medium
    <*> o .:? "status"   .!= Todo
```

Разберём по частям:

1. `withObject "Task"` — проверяет, что значение — JSON-объект; иначе ошибка.
2. `\o -> ...` — лямбда, получающая объект `o`.
3. `Task <$> ... <*> ...` — **аппликативный парсинг**.
4. `o .:? "priority" .!= Medium` — необязательное поле со значением по умолчанию.

```text
> eitherDecode "{\"title\":\"Тест\",\"description\":\"\"}" :: Either String Task
Right (Task {taskTitle = "Тест", taskDescription = "", taskPriority = Medium, taskStatus = Todo})
```

## Applicative в деле

Посмотрите ещё раз на ручной `FromJSON`:

```haskell
Task
  <$> o .:  "title"
  <*> o .:  "description"
  <*> o .:? "priority" .!= Medium
  <*> o .:? "status"   .!= Todo
```

Это **аппликативный стиль** из [главы 11](chapter11.md). Каждый `o .: "field"` возвращает `Parser a`. Цепочка `<$>` и `<*>` собирает результаты в конструктор:

```haskell
--   Task :: Text -> Text -> Priority -> Status -> Task
--   o .: "title"                  :: Parser Text
--   o .:? "priority" .!= Medium   :: Parser Priority
--   Task <$> ... <*> ... <*> ... <*> ...  :: Parser Task
```

Если *любой* парсер завершится ошибкой, вся цепочка вернёт ошибку автоматически.

```admonish note title="Applicative из главы 11 в действии"
Это тот самый `Applicative`, который мы видели на `Maybe` и списках. Здесь он работает на `Parser`, но паттерн тот же: `f <$> x1 <*> x2 <*> ... <*> xN`. aeson — один из самых ярких примеров того, зачем нужен `Applicative` в реальном коде.
```

## Работа с вложенным JSON

JSON в реальных API часто бывает вложенным. Для декодирования можно смешивать монадический и аппликативный стили:

```haskell
data TaskWithMeta = TaskWithMeta
  { twmTitle     :: Text
  , twmCreatedBy :: Text
  , twmTags      :: [Text]
  } deriving (Show, Eq)

instance FromJSON TaskWithMeta where
  parseJSON = withObject "root" $ \root -> do
    taskObj <- root .: "task"
    title   <- taskObj .: "title"
    meta    <- taskObj .: "metadata"
    TaskWithMeta title
      <$> meta .: "created_by"
      <*> meta .:? "tags" .!= []
```

`do`-нотация извлекает промежуточные объекты, а аппликативный стиль собирает результат. `Parser` — и `Monad`, и `Applicative`.

## Проект: JSON-хранилище для трекера задач

Соберём всё вместе — трекер задач сохраняет и восстанавливает состояние из файла.

```haskell
{-# LANGUAGE DeriveGeneric #-}

import Data.Aeson
import Data.Text (Text)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.ByteString.Lazy qualified as BL
import GHC.Generics (Generic)

data Priority = Low | Medium | High
  deriving (Show, Eq, Ord, Generic)

instance ToJSON Priority
instance FromJSON Priority

data Status = Todo | InProgress | Done
  deriving (Show, Eq, Ord, Generic)

instance ToJSON Status
instance FromJSON Status

type Tag = Text

data Task = Task
  { taskTitle       :: Text
  , taskDescription :: Text
  , taskPriority    :: Priority
  , taskStatus      :: Status
  , taskTags        :: Set Tag
  } deriving (Show, Eq, Generic)

instance ToJSON Task where
  toJSON Task{..} = object
    [ "title"       .= taskTitle
    , "description" .= taskDescription
    , "priority"    .= taskPriority
    , "status"      .= taskStatus
    , "tags"        .= Set.toList taskTags
    ]

instance FromJSON Task where
  parseJSON = withObject "Task" $ \o -> Task
    <$> o .:  "title"
    <*> o .:? "description" .!= ""
    <*> o .:? "priority"    .!= Medium
    <*> o .:? "status"      .!= Todo
    <*> (Set.fromList <$> o .:? "tags" .!= [])

data TaskStore = TaskStore
  { storeName  :: Text
  , storeTasks :: [Task]
  } deriving (Show, Eq, Generic)

instance ToJSON TaskStore
instance FromJSON TaskStore

saveTaskStore :: FilePath -> TaskStore -> IO ()
saveTaskStore path store = BL.writeFile path (encode store)

loadTaskStore :: FilePath -> IO (Either String TaskStore)
loadTaskStore path = eitherDecode <$> BL.readFile path
```

В `loadTaskStore` оператор `<$>` применяет `eitherDecode` к результату `IO`-действия — `do`-нотация не нужна.

Пример использования:

```haskell
main :: IO ()
main = do
  let store = TaskStore "Мой проект"
        [ Task "Изучить aeson" "Глава 14" High InProgress
            (Set.fromList ["haskell"])
        , Task "Написать тесты" "" Medium Todo Set.empty
        ]
  saveTaskStore "tasks.json" store
  result <- loadTaskStore "tasks.json"
  case result of
    Left err     -> putStrLn ("Ошибка: " <> err)
    Right store' -> print (store == store')  -- True
```

### Шпаргалка

| Функция / Оператор | Тип | Описание |
|---|---|---|
| `encode` | `ToJSON a => a -> BL.ByteString` | Кодировать в JSON |
| `eitherDecode` | `FromJSON a => BL.ByteString -> Either String a` | Декодировать с ошибками |
| `object` | `[Pair] -> Value` | Собрать JSON-объект |
| `(.=)` | `ToJSON v => Text -> v -> Pair` | Пара ключ-значение |
| `(.:)` | `FromJSON a => Object -> Text -> Parser a` | Обязательное поле |
| `(.:?)` | `FromJSON a => Object -> Text -> Parser (Maybe a)` | Необязательное поле |
| `(.!=)` | `Parser (Maybe a) -> a -> Parser a` | Значение по умолчанию |
| `withObject` | `String -> (Object -> Parser a) -> Value -> Parser a` | Проверить, что это объект |

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

### Проект ★☆☆

1. Определите типы `Priority` и `Status` с деривацией `Generic`, `ToJSON`, `FromJSON`. Проверьте, что `encode` и `decode` работают корректно.

    ```haskell
    data Priority = Low | Medium | High
      deriving (Show, Eq, Ord, Generic)

    instance ToJSON Priority
    instance FromJSON Priority
    ```

2. Определите тип `Task` с деривацией `Generic` и автоматическими инстансами `ToJSON`/`FromJSON`. Проверьте round-trip: `decode (encode task) == Just task`.

### Проект ★★☆

3. Напишите **ручные** инстансы `ToJSON` и `FromJSON` для `Task` с короткими ключами (`"title"`, `"priority"`, `"status"`) и значениями по умолчанию: `priority` = `Medium`, `status` = `Todo`. Проверьте, что JSON без `priority` и `status` декодируется:

    ```text
    > eitherDecode "{\"title\":\"Тест\"}" :: Either String Task
    Right (Task {taskTitle = "Тест", taskPriority = Medium, taskStatus = Todo})
    ```

### Практика ★☆☆

4. Напишите функцию `encodePerson`, которая кодирует запись `Person` в JSON:

    ```haskell
    data Person = Person { personName :: Text, personAge :: Int }
      deriving (Show, Eq, Generic)

    encodePerson :: Person -> BL.ByteString
    encodePerson = encode
    ```

5. Напишите функцию `decodePerson :: BL.ByteString -> Either String Person` и проверьте round-trip: `decodePerson (encodePerson p) == Right p`.

### Практика ★★☆

6. Напишите `FromJSON` для типа `Config`, который парсит вложенный JSON с необязательными полями:

    ```json
    {
      "app": {
        "name": "MyApp",
        "settings": { "debug": true, "max_retries": 5 }
      }
    }
    ```

    ```haskell
    data Config = Config
      { configName :: Text, configDebug :: Bool, configMaxRetries :: Int }
      deriving (Show, Eq)
    ```

    Значения по умолчанию: `debug` = `False`, `max_retries` = `3`. JSON без блока `settings` должен декодироваться корректно.

## Заключение

Библиотека aeson превращает работу с JSON в типобезопасную операцию. Тип `Value` представляет произвольный JSON, а классы `ToJSON`/`FromJSON` связывают его с типами Haskell. Для внутренних форматов хватает автоматической деривации через `Generic`; для внешних API пишутся ручные инстансы с переименованием полей и значениями по умолчанию. Парсинг через `<$>` и `<*>` — один из самых наглядных примеров `Applicative` в реальном коде.

Эта глава завершает **Часть III: Абстракции**. Мы прошли путь от `Functor` до реального применения `Applicative` в парсинге JSON. В [Части IV](chapter15.md) мы перейдём к реальным приложениям: организация проекта, конкурентность и веб-сервер с базой данных. Абстракции, изученные в Части III, станут фундаментом для всего, что впереди.

```admonish tip title="Для углубления"
- **Haskell MOOC** — [haskell.mooc.fi](https://haskell.mooc.fi/), лекция 14: обзор aeson и других библиотек.
- **Документация aeson** — [hackage.haskell.org/package/aeson](https://hackage.haskell.org/package/aeson) — полный API с примерами.
- **24 Days of Hackage: aeson** — [ocharles.org.uk/blog/posts/2012-12-07-24-days-of-hackage-aeson.html](https://ocharles.org.uk/blog/posts/2012-12-07-24-days-of-hackage-aeson.html) — классическое введение.
```
