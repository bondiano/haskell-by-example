# Монада эффектов

## Цели главы

В этой главе мы применим знания о монадах из предыдущей главы к монаде `IO` — механизму, через который Haskell взаимодействует с внешним миром. Мы познакомимся с мутабельными ссылками `IORef` и напишем интерактивное CLI-приложение адресной книги.

Проект главы — адресная книга в терминале с CRUD-операциями и undo.

## Чистота и `IO`

Haskell — чистый язык: функции не имеют побочных эффектов. `length :: [a] -> Int` всегда возвращает одно и то же значение для одного и того же аргумента. Она не может прочитать файл, отправить сообщение или вывести текст на экран.

Но программы без побочных эффектов бесполезны. Haskell решает это через тип `IO`:

```haskell
putStrLn :: String -> IO ()
getLine  :: IO String
readFile :: FilePath -> IO String
```

Тип `IO a` означает: «действие, которое при выполнении может взаимодействовать с внешним миром и возвращает значение типа `a`». `IO ()` — действие, которое ничего полезного не возвращает (аналог `void`).

Ключевое различие:

- `length [1, 2, 3]` — вычисление, происходит сразу.
- `putStrLn "hello"` — *описание* действия, которое выполнится только при запуске программы.

## Простые IO-действия

```haskell
main :: IO ()
main = do
  putStrLn "Как вас зовут?"
  name <- getLine
  putStrLn ("Привет, " <> name <> "!")
```

Основные функции:

```haskell
putStrLn :: String -> IO ()      -- вывести строку с переводом строки
putStr   :: String -> IO ()      -- вывести строку без перевода
print    :: Show a => a -> IO () -- вывести show a с переводом строки
getLine  :: IO String            -- прочитать строку с консоли
```

## `do`-нотация в `IO`

В предыдущей главе мы подробно разобрали `do`-нотацию и её десахаризацию в `>>=` / `>>`. Напомним ключевые элементы в контексте `IO`:

- `x <- action` — выполнить IO-действие и связать результат с `x`.
- `let y = expr` — связать чистое выражение с `y` (без `in`).
- `return` / `pure` — обернуть чистое значение в `IO` (не прерывает выполнение!).

```haskell
main :: IO ()
main = do
  putStrLn "Введите число:"
  s <- getLine
  let n = read s :: Int
  putStrLn ("Удвоенное: " <> show (n * 2))
```

`IO` — монада, поэтому все операторы (`>>=`, `>>`, `return`) и функции из `Control.Monad` (`mapM`, `when`, `forM` и др.) работают с `IO` точно так же, как с `Maybe` или списком.

## Работа с файлами

```haskell
readFile  :: FilePath -> IO String
writeFile :: FilePath -> String -> IO ()
```

Пример — копирование файла:

```haskell
copyFile :: FilePath -> FilePath -> IO ()
copyFile src dst = do
  contents <- readFile src
  writeFile dst contents
```

### `show` и `read` для сериализации

Типы с экземплярами `Show` и `Read` можно сериализовать в строку и обратно:

```haskell
data Entry = Entry
  { entryName :: String
  , entryPhone :: String
  } deriving stock (Show, Read)

save :: FilePath -> [Entry] -> IO ()
save path entries = writeFile path (show entries)

load :: FilePath -> IO [Entry]
load path = read <$> readFile path
```

`<$>` (`fmap`) работает с `IO`, потому что `IO` — функтор: `read <$> readFile path` читает файл и применяет `read` к содержимому.

## `IORef` — мутабельные ссылки

`IORef` — изменяемая переменная внутри `IO`:

```haskell
import Data.IORef

newIORef    :: a -> IO (IORef a)            -- создать
readIORef   :: IORef a -> IO a              -- прочитать
writeIORef  :: IORef a -> a -> IO ()        -- записать
modifyIORef :: IORef a -> (a -> a) -> IO () -- изменить
```

Пример — счётчик:

```haskell
counter :: IO ()
counter = do
  ref <- newIORef (0 :: Int)
  modifyIORef ref (+ 1)
  modifyIORef ref (+ 1)
  modifyIORef ref (+ 1)
  value <- readIORef ref
  putStrLn ("Счётчик: " <> show value)
-- Счётчик: 3
```

`IORef` — это не переменная в привычном смысле. Это *ссылка*, и каждое чтение/запись — IO-действие. Чистый код не может использовать `IORef`.

### Когда использовать `IORef`

- Мутабельное состояние в IO-программах (счётчики, кэши).
- Хранение истории операций (undo).
- Разделяемое состояние между частями программы.

Для сложных случаев предпочтительны `StateT` (глава 12) или `STM` (глава 10).

## Проект: адресная книга

Модуль `AddressBook` определяет:

```haskell
data Entry = Entry
  { entryName  :: String
  , entryPhone :: String
  , entryEmail :: String
  } deriving stock (Show, Eq, Read)

type AddressBook = [Entry]
```

Предоставленные функции:

```haskell
showEntry   :: Entry -> String              -- форматирование записи
findByName  :: String -> AddressBook -> [Entry]  -- поиск по точному имени
insertEntry :: Entry -> AddressBook -> AddressBook  -- добавление записи
exampleBook :: AddressBook                  -- три записи для тестов
```

### Пример CLI

```haskell
import AddressBook
import Data.IORef

main :: IO ()
main = do
  ref <- newIORef exampleBook
  loop ref

loop :: IORef AddressBook -> IO ()
loop ref = do
  putStrLn "\nКоманды: list, find <имя>, add, quit"
  putStr "> "
  cmd <- getLine
  case words cmd of
    ["list"] -> do
      book <- readIORef ref
      mapM_ (putStrLn . showEntry) book
      loop ref
    ("find" : ws) -> do
      let name = unwords ws
      book <- readIORef ref
      let results = findByName name book
      if null results
        then putStrLn "Не найдено."
        else mapM_ (putStrLn . showEntry) results
      loop ref
    ["quit"] -> putStrLn "До свидания!"
    _ -> do
      putStrLn "Неизвестная команда."
      loop ref
```

Этот пример показывает паттерн: `IORef` хранит состояние, `loop` рекурсивно обрабатывает команды.

### `mapM_`

`mapM_` выполняет IO-действие для каждого элемента списка:

```haskell
mapM_ :: (a -> IO b) -> [a] -> IO ()
```

```text
> mapM_ putStrLn ["один", "два", "три"]
один
два
три
```

`mapM` (без подчёркивания) делает то же, но собирает результаты:

```haskell
mapM :: (a -> IO b) -> [a] -> IO [b]
```

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

1. **(Лёгкое)** Реализуйте функцию `deleteEntry`, которая удаляет все записи с данным именем из адресной книги.

    ```haskell
    deleteEntry :: String -> AddressBook -> AddressBook
    ```

    ```text
    > length (deleteEntry "Иван Петров" exampleBook)
    2
    ```

    *Подсказка:* используйте `filter` с условием на `entryName`.

2. **(Среднее)** Реализуйте сохранение и загрузку адресной книги из файла.

    ```haskell
    saveAddressBook :: FilePath -> AddressBook -> IO ()
    loadAddressBook :: FilePath -> IO AddressBook
    ```

    *Подсказка:* используйте `show` / `read` для сериализации и `writeFile` / `readFile` для ввода-вывода.

3. **(Среднее)** Реализуйте нечёткий поиск: регистронезависимый поиск по подстроке в имени.

    ```haskell
    fuzzySearch :: String -> AddressBook -> [Entry]
    ```

    ```text
    > map entryName (fuzzySearch "мария" exampleBook)
    ["Мария Сидорова"]
    ```

    *Подсказка:* используйте `Data.Char.toLower` и `Data.List.isInfixOf`.

4. **(Сложное)** Реализуйте undo через `IORef`. `IORef` хранит стек состояний `[AddressBook]` (голова — самое новое). `recordState` добавляет состояние, `undoLastChange` убирает текущее и возвращает предыдущее.

    ```haskell
    recordState    :: IORef [AddressBook] -> AddressBook -> IO ()
    undoLastChange :: IORef [AddressBook] -> IO (Maybe AddressBook)
    ```

    ```text
    > ref <- newIORef []
    > recordState ref [Entry "A" "1" "a"]
    > recordState ref [Entry "A" "1" "a", Entry "B" "2" "b"]
    > undoLastChange ref
    Just [Entry ...]    -- предыдущее состояние
    ```

    *Подсказка:* `recordState` — это `modifyIORef ref (book :)`. `undoLastChange` — разбор списка: если есть хотя бы два элемента, убрать голову и вернуть новую.

## Functional Core, Imperative Shell

Оглянемся на нашу адресную книгу. Заметьте: чистые функции (`findByName`, `insertEntry`, `deleteEntry`) отделены от IO-кода (`loop`, `main`). Это не случайность — это архитектурный паттерн, который Haskell *гарантирует* на уровне типов.

### Паттерн

Gary Bernhardt назвал это **«Functional Core, Imperative Shell»** (FCIS):

- **Functional Core** — чистые функции, содержащие *всю* бизнес-логику. Нет IO, нет побочных эффектов. Легко тестировать, легко рассуждать.
- **Imperative Shell** — тонкий слой IO на границах: ввод-вывод, сеть, файлы. Минимум логики.

```text
┌────────────────────────────────────────┐
│          Imperative Shell (IO)         │
│  main, loop, readFile, putStrLn, IORef │
│                                        │
│    ┌──────────────────────────────┐    │
│    │     Functional Core (pure)   │    │
│    │  findByName, insertEntry,    │    │
│    │  deleteEntry, showEntry,     │    │
│    │  parseCommand, validateEntry │    │
│    └──────────────────────────────┘    │
│                                        │
└────────────────────────────────────────┘
```

### Почему Haskell особенный

В TypeScript или Python FCIS — это *соглашение*. Ничто не мешает вызвать `fetch()` или `print()` из «чистой» функции. Дисциплина — на совести разработчика.

В Haskell это *гарантия типовой системы*. Чистая функция `findByName :: String -> AddressBook -> [Entry]` *физически не может* обратиться к сети или файлу — у неё нет `IO` в типе. Компилятор не пропустит.

```admonish info title="Знакомый аналог"
**TypeScript:** Паттерн FCIS реализуем, но не enforced. `function findByName(name: string, book: Entry[]): Entry[]` *может* вызвать `fetch()` — компилятор не заметит.

**Python:** Аналогично — convention-only. `def find_by_name(name, book)` может делать что угодно.

В Haskell нарушение — *ошибка компиляции*.
```

### Three Layer Cake

Matt Parsons развил идею FCIS в паттерн **«Three Layer Cake»** для production-приложений:

1. **Бизнес-логика** — чистые функции и типы.
2. **Эффекты** — абстрактные интерфейсы (type classes или effect systems).
3. **Интерпретация** — конкретная реализация (IO, тесты, mock'и).

Мы вернёмся к этому в главе 12 (стеки монад-трансформеров) и главе 18 (веб-приложение).

### Практический совет

Хорошее правило: **максимально разделяйте принятие решений и выполнение действий**.

```haskell
-- ПЛОХО: логика смешана с IO
processCommand :: IORef AddressBook -> String -> IO ()
processCommand ref input = case words input of
  ["find", name] -> do
    book <- readIORef ref
    let results = filter (\e -> entryName e == name) book  -- логика внутри IO!
    mapM_ (putStrLn . showEntry) results

-- ХОРОШО: логика вынесена в чистую функцию
findByName :: String -> AddressBook -> [Entry]
findByName name = filter (\e -> entryName e == name)

processCommand :: IORef AddressBook -> String -> IO ()
processCommand ref input = case words input of
  ["find", name] -> do
    book <- readIORef ref
    mapM_ (putStrLn . showEntry) (findByName name book)
```

Чистые функции можно тестировать без IO, документировать через типы и переиспользовать.

## Заключение

В этой главе мы:

- Познакомились с монадой `IO` — механизмом побочных эффектов в Haskell.
- Применили `do`-нотацию (из предыдущей главы) к IO-действиям.
- Научились работать с файлами через `readFile` / `writeFile`.
- Освоили `IORef` — мутабельные ссылки в `IO`.
- Разобрали паттерн «Functional Core, Imperative Shell» — архитектурный принцип, который Haskell гарантирует через типы.
- Применили всё это к CLI-приложению адресной книги.

В следующей главе мы познакомимся с конкурентностью в Haskell: `async`, `MVar`, `STM` и параллельное выполнение.
