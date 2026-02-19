# FFI: вызов C из Haskell

> **Это приложение — дополнительный материал.** Оно не входит в основную линию книги и не требуется для дальнейших глав. Читайте его, если вам нужно взаимодействовать с C-библиотеками из Haskell.

## Зачем FFI

Haskell — высокоуровневый язык с мощной системой типов, сборщиком мусора и ленивыми вычислениями. Но иногда нужен доступ к миру за пределами Haskell:

- **Системные вызовы ОС** — POSIX API, работа с файловыми дескрипторами.
- **Существующие C-библиотеки** — OpenSSL, SQLite, zlib, libcurl.
- **Критически производительный код** — числовые алгоритмы, уже написанные на C.
- **Специализированные библиотеки** — fuzzy search, парсеры бинарных форматов.

FFI (Foreign Function Interface) позволяет **импортировать** C-функции в Haskell и вызывать их как обычные функции. В конце приложения мы обернём C-библиотеку нечёткого поиска для поиска задач в нашем трекере.

```admonish tip title="Знакомый аналог"
FFI в Haskell — аналог `ctypes` / `cffi` в Python, `ffi` (napi) в Node.js, `cgo` в Go. Идея одна: описать сигнатуру C-функции на стороне хост-языка, выполнить маршаллинг типов, вызвать.
```

## `foreign import ccall`

### Базовый синтаксис

Ключевое слово `foreign import` объявляет внешнюю функцию:

```haskell
foreign import ccall "заголовок функция" имя_haskell :: тип
```

- `ccall` — конвенция вызова (C calling convention). Для C-библиотек это почти всегда `ccall`.
- `"заголовок функция"` — имя заголовочного файла и функции (например, `"stdlib.h abs"`).
- `имя_haskell` — имя, под которым функция будет доступна в Haskell.

### Пример: импорт `abs`

```haskell
import Foreign.C.Types (CInt(..))

foreign import ccall "stdlib.h abs" c_abs :: CInt -> CInt
```

Теперь `c_abs` вызывает функцию `abs` из стандартной библиотеки C. `CInt` — Haskell-обёртка над C-типом `int`.

### Обёртка для удобства

FFI-функция оперирует C-типами. Обычно пишут Haskell-обёртку с привычными типами:

```haskell
haskellAbs :: Int -> Int
haskellAbs = fromIntegral . c_abs . fromIntegral
```

`fromIntegral` конвертирует между `Int` и `CInt`. Паттерн `обёртка . ffi_функция . маршаллинг` встречается повсеместно.

```admonish note title="Соглашение об именах"
FFI-функции принято называть с префиксом `c_` — например, `c_abs`, `c_strlen`, `c_free`. Haskell-обёртки — без префикса или с другим именем. Это помогает отличать «сырые» вызовы от безопасных обёрток.
```

## Маршаллинг типов

### Модуль `Foreign.C.Types`

C-типы и их Haskell-аналоги:

| C-тип | Haskell-тип | Модуль |
|-------|-------------|--------|
| `int` | `CInt` | `Foreign.C.Types` |
| `unsigned int` | `CUInt` | `Foreign.C.Types` |
| `long` | `CLong` | `Foreign.C.Types` |
| `double` | `CDouble` | `Foreign.C.Types` |
| `float` | `CFloat` | `Foreign.C.Types` |
| `char` | `CChar` | `Foreign.C.Types` |
| `size_t` | `CSize` | `Foreign.C.Types` |
| `char*` | `CString` | `Foreign.C.String` |
| `void*` | `Ptr a` | `Foreign.Ptr` |
| `void**` | `Ptr (Ptr a)` | `Foreign.Ptr` |

Все типы из `Foreign.C.Types` — `newtype`-обёртки. Они реализуют `Num`, `Eq`, `Ord`, `Storable` и другие классы, поэтому арифметика и сравнения работают напрямую.

### `Ptr a` — указатели

`Ptr a` — типизированный указатель. Тип `a` — фантомный параметр, который помогает не перепутать указатели на разные структуры:

```haskell
import Foreign.Ptr (Ptr, nullPtr, castPtr)

-- nullPtr — нулевой указатель (аналог NULL в C)
nullPtr :: Ptr a

-- castPtr — приведение типа указателя (аналог (void*) cast)
castPtr :: Ptr a -> Ptr b
```

```admonish warning title="Указатели — опасная зона"
Работа с `Ptr` обходит систему типов Haskell. Разыменование невалидного указателя — segfault. Двойное освобождение — UB. FFI-код требует такой же осторожности, как C-код.
```

### `FunPtr` — указатели на функции

Для передачи Haskell-функции в C (callback) используется `FunPtr`:

```haskell
import Foreign.Ptr (FunPtr)

type CompareFunc = CInt -> CInt -> CInt

foreign import ccall "wrapper"
  mkCompareFunc :: CompareFunc -> IO (FunPtr CompareFunc)
```

`"wrapper"` — специальная директива, создающая C-совместимый указатель на Haskell-функцию.

## Строки

### `CString` — строки C

C-строки (`char*`) — нуль-терминированные массивы байт. В Haskell для работы с ними используются функции из `Foreign.C.String`:

```haskell
import Foreign.C.String (CString, withCString, peekCString, newCString)

-- Haskell String -> CString (временный, автоматически освобождается)
withCString :: String -> (CString -> IO a) -> IO a

-- CString -> Haskell String
peekCString :: CString -> IO String

-- Haskell String -> CString (нужно освобождать вручную через free)
newCString :: String -> IO CString
```

### Пример: обёртка над `strlen`

```haskell
import Foreign.C.String (CString, withCString)
import Foreign.C.Types (CSize(..))

foreign import ccall "string.h strlen" c_strlen :: CString -> CSize

haskellStrlen :: String -> IO Int
haskellStrlen s = withCString s $ \cs ->
  return (fromIntegral (c_strlen cs))
```

`withCString` выполняет три шага:

1. Выделяет память и копирует строку в C-формат (нуль-терминированный).
2. Передаёт указатель в лямбду.
3. Освобождает память после завершения лямбды.

Это паттерн **bracket** — безопасное управление ресурсами, знакомый нам по [главе 8](chapter08.md).

```admonish tip title="Знакомый аналог"
`withCString` — аналог `with` в Python (context manager) или `try-with-resources` в Java. Ресурс (C-строка) гарантированно освобождается, даже если произошло исключение.
```

### Работа с `Text` через FFI

Если ваше приложение использует `Text` (как наш трекер задач), нужен дополнительный шаг:

```haskell
import Data.Text (Text)
import Data.Text qualified as T

withTextAsCString :: Text -> (CString -> IO a) -> IO a
withTextAsCString t f = withCString (T.unpack t) f
```

Для больших строк эффективнее использовать `Data.Text.Foreign`, но для типичных вызовов FFI `T.unpack` + `withCString` достаточно.

## Безопасные и небезопасные вызовы

```haskell
foreign import ccall safe   "compute" c_compute_safe   :: CInt -> IO CInt
foreign import ccall unsafe "compute" c_compute_unsafe :: CInt -> IO CInt
```

- **`safe`** (по умолчанию) — C-функция может выполняться долго или вызывать Haskell-код обратно (callbacks). Рантайм корректно обрабатывает многопоточность и GC.
- **`unsafe`** — быстрее (нет переключения контекста GC), но C-функция **не должна** вызывать Haskell-код и должна завершиться быстро.

```admonish warning title="Правило"
Используйте `unsafe` только для быстрых, чистых C-функций без обратных вызовов. Примеры: `abs`, `strlen`, `sin`. Для всего остального — `safe`.
```

## Проект: fuzzy search для заголовков задач

Допустим, у нас есть C-библиотека для нечёткого поиска строк (fuzzy matching). Мы хотим использовать её для поиска задач в трекере по приблизительному совпадению заголовка.

### Имитация C-библиотеки

В реальном проекте вы бы подключили библиотеку вроде `fzy` или `fts_fuzzy_match`. Для учебных целей мы напишем простую C-функцию и обернём её.

Создадим файл `cbits/fuzzy.c`:

```c
#include <string.h>
#include <ctype.h>

// Простой fuzzy match: проверяет, что все символы needle
// встречаются в haystack в том же порядке (без учёта регистра).
// Возвращает 1 (совпадение) или 0 (нет).
int fuzzy_match(const char* needle, const char* haystack) {
    if (!needle || !haystack) return 0;
    const char* n = needle;
    const char* h = haystack;
    while (*n && *h) {
        if (tolower(*n) == tolower(*h)) {
            n++;
        }
        h++;
    }
    return (*n == '\0') ? 1 : 0;
}

// Fuzzy score: количество совпавших символов, нормализованное
// по длине haystack. Возвращает значение от 0.0 до 1.0.
double fuzzy_score(const char* needle, const char* haystack) {
    if (!needle || !haystack) return 0.0;
    int matched = 0;
    const char* n = needle;
    const char* h = haystack;
    while (*n && *h) {
        if (tolower(*n) == tolower(*h)) {
            matched++;
            n++;
        }
        h++;
    }
    if (*n != '\0') return 0.0;  // не все символы совпали
    int len = strlen(haystack);
    return (len > 0) ? (double)matched / (double)len : 0.0;
}
```

### Подключение к Haskell-проекту

В `package.yaml`:

```yaml
c-sources:
  - cbits/fuzzy.c

include-dirs:
  - cbits
```

### FFI-привязки

```haskell
module FuzzySearch (fuzzyMatch, fuzzyScore, fuzzySearchTasks) where

import Foreign.C.String (CString, withCString)
import Foreign.C.Types (CInt(..), CDouble(..))

foreign import ccall unsafe "fuzzy_match"
  c_fuzzy_match :: CString -> CString -> CInt

foreign import ccall unsafe "fuzzy_score"
  c_fuzzy_score :: CString -> CString -> CDouble
```

Оба вызова — `unsafe`, потому что функции быстрые, чистые и не вызывают Haskell-код.

### Haskell-обёртки

```haskell
-- Проверка нечёткого совпадения
fuzzyMatch :: String -> String -> IO Bool
fuzzyMatch needle haystack =
  withCString needle $ \cn ->
    withCString haystack $ \ch ->
      return (c_fuzzy_match cn ch /= 0)

-- Оценка нечёткого совпадения (0.0 — 1.0)
fuzzyScore :: String -> String -> IO Double
fuzzyScore needle haystack =
  withCString needle $ \cn ->
    withCString haystack $ \ch ->
      return (realToFrac (c_fuzzy_score cn ch))
```

Обратите внимание на вложенные `withCString`. Каждая C-строка живёт только внутри своей лямбды. Вложенность гарантирует, что обе строки существуют одновременно во время вызова C-функции.

### Интеграция с трекером задач

```haskell
import Data.List (sortOn)
import Data.Ord (Down(..))

-- Поиск задач по нечёткому совпадению заголовка
fuzzySearchTasks :: String -> [Task] -> IO [Task]
fuzzySearchTasks query tasks = do
  scored <- mapM scoreTask tasks
  let matched = filter (\(_, s) -> s > 0) scored
      sorted  = sortOn (Down . snd) matched
  return (map fst sorted)
  where
    scoreTask task = do
      s <- fuzzyScore query (taskTitle task)
      return (task, s)
```

Пример использования:

```haskell
main :: IO ()
main = do
  let tasks =
        [ Task "Реализовать парсер JSON" "..." Medium InProgress
        , Task "Написать тесты для API" "..." High Todo
        , Task "Рефакторинг модуля Task" "..." Low Done
        , Task "Документация по API" "..." Medium Todo
        ]
  results <- fuzzySearchTasks "api" tasks
  mapM_ (putStrLn . taskTitle) results
  -- Вывод:
  -- Написать тесты для API
  -- Документация по API
```

Запрос `"api"` нечётко совпадает с заголовками, содержащими подпоследовательность `a`, `p`, `i`. Результаты отсортированы по убыванию оценки.

```admonish note title="Почему IO?"
Функции `fuzzyMatch` и `fuzzyScore` возвращают `IO`, хотя C-функции чистые. Причина: `withCString` выполняет выделение и освобождение памяти — побочный эффект. Можно обернуть в `unsafePerformIO` для чистого интерфейса, но это продвинутая тема, требующая осторожности.
```

## Управление памятью

### Кто отвечает за память?

Это ключевой вопрос при работе с FFI:

| Ситуация | Ответственность |
|----------|----------------|
| `withCString` | Haskell (автоматически) |
| `newCString` | **Вы** (нужен `free`) |
| C-функция возвращает `char*` | Зависит от документации C-библиотеки |
| `malloc` / `alloca` | **Вы** (нужен `free` / автоматически) |

```haskell
import Foreign.Marshal.Alloc (free)
import Foreign.C.String (newCString)

-- Опасно: утечка памяти, если забыть free
leaky :: IO CString
leaky = newCString "утечка!"

-- Безопасно: bracket-паттерн
safe :: IO ()
safe = do
  cs <- newCString "безопасно"
  -- ... использовать cs ...
  free cs
```

```admonish warning title="Золотое правило FFI"
Всегда предпочитайте `withCString` вместо `newCString`. Всегда предпочитайте `alloca` вместо `malloc`. Паттерн `with*` гарантирует освобождение ресурсов — как `bracket` из [главы 8](chapter08.md).
```

## Упражнения

### 1. Обёртка над `toupper` (&#9733;&#9734;&#9734;)

Импортируйте функцию `toupper` из `<ctype.h>` и напишите обёртку `cToUpper :: Char -> Char`, которая переводит символ в верхний регистр через C-функцию.

```haskell
foreign import ccall "ctype.h toupper" c_toupper :: CInt -> CInt

cToUpper :: Char -> Char
```

*Подсказка:* используйте `ord` / `chr` из `Data.Char` для конвертации `Char` <-> `Int`, затем `fromIntegral` для `Int` <-> `CInt`.

### 2. Fuzzy-фильтрация с порогом (&#9733;&#9733;&#9734;)

Напишите функцию `fuzzyFilter`, которая принимает порог совпадения (0.0–1.0), запрос и список строк, и возвращает только те строки, чья оценка выше порога:

```haskell
fuzzyFilter :: Double -> String -> [String] -> IO [String]
```

*Подсказка:* используйте `fuzzyScore` из примера выше и `filterM` из `Control.Monad`.

## Заключение

FFI открывает Haskell доступ ко всей экосистеме C-библиотек. Мы разобрали `foreign import ccall`, маршаллинг типов (`CInt`, `CDouble`, `CString`, `Ptr`), безопасную работу со строками через `withCString`, разницу между `safe` и `unsafe` вызовами. На практике мы обернули C-библиотеку fuzzy search и интегрировали её с трекером задач.

Каждый `foreign import` — потенциальная дыра в системе типов Haskell, поэтому оборачивайте небезопасный код в безопасные Haskell-обёртки и тестируйте границы тщательно.
