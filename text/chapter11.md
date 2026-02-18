# Интерфейс внешних функций (FFI)

## Цели главы

В этой главе мы познакомимся с двумя способами взаимодействия Haskell с внешним миром: вызов C-функций через FFI (Foreign Function Interface) и работа с JSON через библиотеку `aeson`.

FFI позволяет вызывать функции из C-библиотек напрямую из Haskell. `aeson` — стандартная библиотека для кодирования и декодирования JSON, основной формат обмена данными в современных приложениях.

## FFI — вызов C из Haskell

### Зачем FFI?

Haskell — высокоуровневый язык, но иногда нужен доступ к:

- системным вызовам ОС,
- существующим C-библиотекам (OpenSSL, SQLite, zlib),
- критически производительному коду на C.

FFI позволяет импортировать C-функции в Haskell и вызывать их как обычные функции.

### `foreign import ccall`

Базовый синтаксис:

```haskell
foreign import ccall "заголовок функция" имя_haskell :: тип
```

Пример — импорт `abs` из стандартной библиотеки C:

```haskell
import Foreign.C.Types (CInt(..))

foreign import ccall "stdlib.h abs" c_abs :: CInt -> CInt
```

`c_abs` теперь вызывает C-функцию `abs`. `CInt` — Haskell-обёртка над C-типом `int`.

### Обёртка для удобства

Прямой вызов FFI-функции оперирует C-типами. Обычно пишут Haskell-обёртку:

```haskell
cAbs :: Int -> Int
cAbs = fromIntegral . c_abs . fromIntegral
```

`fromIntegral` конвертирует между `Int` и `CInt`.

### Типы маршаллинга

Модуль `Foreign.C.Types` предоставляет Haskell-аналоги C-типов:

| C-тип | Haskell-тип | Модуль |
|-------|-------------|--------|
| `int` | `CInt` | `Foreign.C.Types` |
| `double` | `CDouble` | `Foreign.C.Types` |
| `char*` | `CString` | `Foreign.C.String` |
| `size_t` | `CSize` | `Foreign.C.Types` |
| `void*` | `Ptr a` | `Foreign.Ptr` |

### Работа со строками: `CString`

C-строки (`char*`) — нуль-терминированные массивы байт. В Haskell для работы с ними используются:

```haskell
import Foreign.C.String

withCString  :: String -> (CString -> IO a) -> IO a  -- Haskell → C
peekCString  :: CString -> IO String                  -- C → Haskell
```

Пример — обёртка над `strlen`:

```haskell
foreign import ccall "string.h strlen" c_strlen :: CString -> CSize

cStrlen :: String -> IO Int
cStrlen s = withCString s $ \cs ->
  return (fromIntegral (c_strlen cs))
```

`withCString` временно преобразует `String` в `CString`, передаёт его в лямбду и гарантирует освобождение памяти.

### Безопасные и небезопасные вызовы

```haskell
foreign import ccall safe   "compute" c_compute_safe   :: CInt -> IO CInt
foreign import ccall unsafe "compute" c_compute_unsafe :: CInt -> IO CInt
```

- **safe** (по умолчанию) — C-функция может вызывать Haskell-код обратно или выполняться долго. Рантайм корректно обрабатывает многопоточность.
- **unsafe** — быстрее (нет переключения контекста), но C-функция не должна вызывать Haskell-код и должна завершиться быстро.

Правило: используйте `unsafe` только для быстрых, чистых C-функций без обратных вызовов.

## Text и ByteString

Прежде чем перейти к JSON, разберёмся с типами строк в Haskell. В следующей секции мы увидим, что `aeson` оперирует типами `Text` и `ByteString`, а не `String`. Почему?

### Проблема `String`

`String` в Haskell — это просто синоним для списка символов:

```haskell
type String = [Char]
```

Связный список символов — удобная учебная структура, но крайне неэффективная:

- **O(n)** доступ по индексу и вычисление длины.
- Каждый символ хранится в отдельном узле списка с указателем — огромный расход памяти.
- Непригоден для обработки больших текстов, файлов, сетевого ввода-вывода.

Для реального кода используются `Text` и `ByteString`.

### `Data.Text`

`Text` — компактное представление текста в кодировке UTF-8:

```haskell
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
```

Основные функции:

```text
> :t T.pack
T.pack :: String -> Text

> :t T.unpack
T.unpack :: Text -> String

> T.toUpper (T.pack "hello")
"HELLO"

> T.words (T.pack "один два три")
["один","два","три"]

> T.intercalate (T.pack ", ") [T.pack "a", T.pack "b", T.pack "c"]
"a, b, c"
```

Существуют **строгая** (`Data.Text`) и **ленивая** (`Data.Text.Lazy`) версии. Строгая хранит весь текст в памяти одним куском; ленивая — цепочкой кусков (chunks), удобна для потоковой обработки больших файлов.

Для ввода-вывода используйте `Data.Text.IO` вместо стандартных функций:

```haskell
TIO.readFile  :: FilePath -> IO Text
TIO.writeFile :: FilePath -> Text -> IO ()
TIO.putStrLn  :: Text -> IO ()
```

### `Data.ByteString`

`ByteString` — массив **байтов**, не символов. Это важное различие:

```haskell
import qualified Data.ByteString as BS         -- строгая версия
import qualified Data.ByteString.Lazy as BL    -- ленивая версия
```

Когда использовать `ByteString`:

- бинарные данные (изображения, архивы),
- сетевой ввод-вывод,
- чтение/запись файлов как сырых байтов,
- JSON, HTTP-ответы — форматы, работающие на уровне байтов.

### Кодирование текста

Для преобразования между `Text` и `ByteString` нужно указать кодировку:

```haskell
import Data.Text.Encoding (encodeUtf8, decodeUtf8)

encodeUtf8 :: Text -> ByteString        -- текст → байты (UTF-8)
decodeUtf8 :: ByteString -> Text         -- байты → текст (UTF-8, может упасть)
```

`decodeUtf8` бросает исключение на невалидном UTF-8. Безопасная альтернатива:

```haskell
decodeUtf8' :: ByteString -> Either UnicodeException Text
```

### `OverloadedStrings`

Расширение `OverloadedStrings` (включено в нашем проекте) позволяет строковым литералам иметь любой тип, реализующий класс `IsString`:

```haskell
{-# LANGUAGE OverloadedStrings #-}

greeting :: Text
greeting = "Привет"    -- литерал автоматически становится Text

path :: ByteString
path = "/api/users"    -- литерал автоматически становится ByteString
```

Без этого расширения пришлось бы писать `T.pack "Привет"` каждый раз.

### Когда что использовать

| Тип | Когда использовать |
|-----|-------------------|
| `String` | REPL, прототипы, учебные примеры |
| `Text` | Любой текст в приложении |
| `ByteString` | Бинарные данные, JSON (`aeson`), HTTP, файловый I/O |

### Конвертации

```text
String  ←→  Text:         T.pack / T.unpack
Text    →   ByteString:   encodeUtf8
ByteString → Text:        decodeUtf8 (или decodeUtf8' для безопасности)
String  ←→  ByteString:   через Text (pack → encodeUtf8, decodeUtf8 → unpack)
```

Теперь, когда мы знаем разницу между этими типами, `aeson` будет понятнее — он использует `Text` для ключей JSON и `ByteString` для сериализованных данных.

## JSON и `aeson`

### Почему `aeson`?

`aeson` — стандартная библиотека Haskell для работы с JSON. Она обеспечивает:

- Автоматическую сериализацию через `Generic`.
- Гибкие ручные экземпляры для нестандартных форматов.
- Высокую производительность.

### Установка

`aeson` доступен в Stackage. В `package.yaml`:

```yaml
dependencies:
  - aeson
  - bytestring
```

### Тип `Value`

`aeson` представляет JSON как тип `Value`:

```haskell
data Value
  = Object Object    -- {"key": value}
  | Array  Array     -- [value, ...]
  | String Text      -- "text"
  | Number Scientific -- 42, 3.14
  | Bool   Bool      -- true, false
  | Null             -- null
```

### `ToJSON` и `FromJSON`

Два ключевых класса типов:

```haskell
class ToJSON a where
  toJSON :: a -> Value          -- Haskell → JSON

class FromJSON a where
  parseJSON :: Value -> Parser a  -- JSON → Haskell
```

### `encode` и `decode`

```haskell
encode :: ToJSON a => a -> ByteString
decode :: FromJSON a => ByteString -> Maybe a
```

```haskell
import Data.Aeson (encode, decode)

> encode [1, 2, 3 :: Int]
"[1,2,3]"

> decode "[1,2,3]" :: Maybe [Int]
Just [1,2,3]

> decode "invalid" :: Maybe [Int]
Nothing
```

`encode` возвращает `ByteString` (ленивый). `decode` возвращает `Maybe` — `Nothing` при ошибке парсинга.

Для получения сообщения об ошибке используйте `eitherDecode`:

```haskell
eitherDecode :: FromJSON a => ByteString -> Either String a
```

### Generic-деривация

Самый простой способ — автоматическая деривация через `Generic`:

```haskell
import Data.Aeson (ToJSON, FromJSON)
import GHC.Generics (Generic)

data Contact = Contact
  { name  :: String
  , phone :: String
  , email :: String
  } deriving stock (Show, Eq, Generic)

instance ToJSON Contact
instance FromJSON Contact
```

Пустые экземпляры используют реализации по умолчанию, основанные на `Generic`. Имена полей записи становятся ключами JSON:

```text
> encode (Contact "Иван" "+7-900-123" "ivan@example.com")
{"name":"Иван","phone":"+7-900-123","email":"ivan@example.com"}
```

### Ручные экземпляры

Когда ключи JSON не совпадают с именами полей, пишутся ручные экземпляры:

```haskell
import Data.Aeson

data Movie = Movie
  { movieTitle  :: String
  , movieYear   :: Int
  , movieRating :: Double
  } deriving stock (Show, Eq)

instance ToJSON Movie where
  toJSON Movie{..} = object
    [ "title"  .= movieTitle
    , "year"   .= movieYear
    , "rating" .= movieRating
    ]

instance FromJSON Movie where
  parseJSON = withObject "Movie" $ \o -> Movie
    <$> o .: "title"
    <*> o .: "year"
    <*> o .: "rating"
```

Разберём `FromJSON`:

- `withObject "Movie"` — проверить, что `Value` — это объект; при ошибке сообщить «ожидался Movie».
- `o .: "title"` — извлечь ключ `"title"` из объекта.
- `<$>` и `<*>` — аппликативный стиль (глава 7).

### `object` и `.=`

`object` создаёт JSON-объект из списка пар:

```haskell
object :: [Pair] -> Value
(.=)   :: ToJSON v => Key -> v -> Pair
```

```haskell
> encode (object ["x" .= (1 :: Int), "y" .= (2 :: Int)])
{"x":1,"y":2}
```

### Опциональные поля

`(.:?)` извлекает необязательный ключ (возвращает `Maybe`), а `(.!=)` задаёт значение по умолчанию:

```haskell
data Config = Config
  { configHost    :: String
  , configPort    :: Int
  , configDebug   :: Bool
  , configLogFile :: Maybe String
  } deriving stock (Show, Eq)

instance FromJSON Config where
  parseJSON = withObject "Config" $ \o -> Config
    <$> o .:  "host"
    <*> o .:  "port"
    <*> o .:? "debug"    .!= False     -- False, если ключ отсутствует
    <*> o .:? "log_file"               -- Nothing, если ключ отсутствует
```

```text
> decode "{\"host\":\"localhost\",\"port\":8080}" :: Maybe Config
Just (Config "localhost" 8080 False Nothing)
```

### Работа с JSON-файлами

```haskell
import qualified Data.ByteString.Lazy as BL

saveJSON :: ToJSON a => FilePath -> a -> IO ()
saveJSON path value = BL.writeFile path (encode value)

loadJSON :: FromJSON a => FilePath -> IO (Either String a)
loadJSON path = eitherDecode <$> BL.readFile path
```

Пример:

```haskell
main :: IO ()
main = do
  let contacts = [Contact "Иван" "+7-900-123" "ivan@example.com"]
  saveJSON "contacts.json" contacts
  result <- loadJSON "contacts.json"
  case result of
    Left err -> putStrLn ("Ошибка: " <> err)
    Right cs -> mapM_ (putStrLn . name) (cs :: [Contact])
```

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

1. **(Лёгкое)** Реализуйте `encodeContacts` и `decodeContacts` — кодирование и декодирование списка контактов в JSON.

    ```haskell
    encodeContacts :: [Contact] -> ByteString
    decodeContacts :: ByteString -> Maybe [Contact]
    ```

    ```text
    > decodeContacts (encodeContacts [Contact "Тест" "123" "t@e.com"])
    Just [Contact {name = "Тест", phone = "123", email = "t@e.com"}]
    ```

    *Подсказка:* используйте `encode` и `decode` из `Data.Aeson`. Тип `Contact` уже имеет экземпляры `ToJSON` / `FromJSON`.

2. **(Среднее)** Определите тип `Movie` с полями `movieTitle`, `movieYear`, `movieRating` и напишите для него ручные экземпляры `ToJSON` / `FromJSON`. JSON-ключи должны быть `"title"`, `"year"`, `"rating"` (без префикса `movie`).

    ```haskell
    data Movie = Movie
      { movieTitle  :: String
      , movieYear   :: Int
      , movieRating :: Double
      }

    encodeMovie :: Movie -> ByteString
    decodeMovie :: ByteString -> Maybe Movie
    ```

    *Подсказка:* используйте `object` и `(.=)` для `ToJSON`, `withObject` и `(.:)` для `FromJSON`.

3. **(Среднее)** Реализуйте универсальные функции сохранения и загрузки JSON-файлов.

    ```haskell
    saveJSON :: ToJSON a => FilePath -> a -> IO ()
    loadJSON :: FromJSON a => FilePath -> IO (Either String a)
    ```

    *Подсказка:* используйте `BL.writeFile` / `BL.readFile` из `Data.ByteString.Lazy` и `encode` / `eitherDecode` из `Data.Aeson`.

4. **(Сложное)** Определите тип `Config` и напишите экземпляры `ToJSON` / `FromJSON` с опциональными полями.

    ```haskell
    data Config = Config
      { configHost    :: String
      , configPort    :: Int
      , configDebug   :: Bool        -- по умолчанию False
      , configLogFile :: Maybe String -- Nothing, если отсутствует
      }

    encodeConfig :: Config -> ByteString
    decodeConfig :: ByteString -> Maybe Config
    ```

    JSON-ключи: `"host"`, `"port"`, `"debug"`, `"log_file"`.

    ```text
    > decodeConfig "{\"host\":\"localhost\",\"port\":8080}"
    Just (Config "localhost" 8080 False Nothing)
    ```

    *Подсказка:* используйте `(.:?)` для опциональных ключей и `(.!=)` для значений по умолчанию.

5. **(Лёгкое)** Реализуйте функцию `normalizeText`, которая принимает `Text`, приводит к нижнему регистру и убирает лишние пробелы (множественные пробелы заменяются одним, пробелы в начале и конце удаляются).

    ```haskell
    normalizeText :: Text -> Text
    ```

    ```text
    > normalizeText "  Hello   World  "
    "hello world"
    ```

    *Подсказка:* используйте `T.toLower`, `T.words` и `T.unwords` из `Data.Text`.

## Заключение

В этой главе мы:

- Познакомились с FFI — механизмом вызова C-функций из Haskell.
- Разобрали маршаллинг типов: `CInt`, `CString`, `Ptr`.
- Разобрали типы строк: `String`, `Text` и `ByteString` — их различия, конвертации и `OverloadedStrings`.
- Освоили `aeson` — стандартную библиотеку для работы с JSON.
- Научились использовать Generic-деривацию и писать ручные экземпляры `ToJSON` / `FromJSON`.
- Разобрали опциональные поля и значения по умолчанию.

В следующей главе мы погрузимся в трансформеры монад и создадим текстовую RPG-игру.
