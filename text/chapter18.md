# DSL и парсеры

В предыдущих главах мы построили полноценный трекер задач: типы, IO, сериализация, конкурентность, веб-сервер с базой данных. Теперь дадим пользователям трекера **собственный язык запросов** — чтобы фильтровать задачи не кнопками, а текстовыми выражениями. Для этого разберём, что такое **DSL** (Domain-Specific Language) и чем встроенные DSL отличаются от внешних, познакомимся с библиотекой **megaparsec**, освоим парсинг примитивов и комбинаторы, построим **AST** для языка запросов и реализуем полный парсер с исполнителем для выражений вида `status:done priority:high tag:work`.

К концу главы вы сможете спроектировать и реализовать парсер для небольшого предметно-ориентированного языка.

## Подготовка проекта

Код этой главы находится в `exercises/chapter18`. Соберите проект:

```text
$ cd exercises/chapter18
$ stack build
```

В `package.yaml` потребуется зависимость `megaparsec`:

```yaml
dependencies:
  - base >= 4.7 && < 5
  - megaparsec
  - text
```

## Что такое DSL

### Язык для конкретной предметной области

**DSL** (Domain-Specific Language) — язык, спроектированный для решения задач в конкретной области. В отличие от языков общего назначения (Haskell, Python, Java), DSL не претендует на универсальность — он *делает одно дело, но делает его хорошо*.

Примеры DSL, которые вы уже знаете:

| DSL | Область |
|-----|---------|
| SQL | Запросы к базам данных |
| HTML | Разметка документов |
| CSS | Стилизация |
| Regex | Поиск по шаблону |
| Makefile | Сборка проектов |
| Markdown | Форматирование текста |

### Встроенные vs внешние DSL

**Внешний DSL** (external DSL) — отдельный язык со своим синтаксисом и парсером. SQL, HTML, регулярные выражения — внешние DSL. Их нужно *парсить* — превращать текст в структуру данных.

**Встроенный DSL** (embedded DSL, EDSL) — библиотека на языке-хосте, которая выглядит как отдельный язык благодаря синтаксическим возможностям хоста. Haskell хорош для EDSL благодаря:

- Перегрузке операторов (`<>`, `>>=`, `<|>`)
- Классам типов (`IsString`, `Num`, `IsList`)
- `do`-нотации
- Ленивости

```haskell
-- Пример EDSL: hspec выглядит как отдельный язык тестирования
spec :: Spec
spec = describe "фильтрация задач" $ do
  it "фильтрует по статусу" $ do
    filterTasks (ByStatus Done) tasks `shouldBe` [doneTask]
  it "фильтрует по приоритету" $ do
    filterTasks (ByPriority High) tasks `shouldBe` [urgentTask]
```

```admonish tip title="Знакомый аналог"
**TypeScript:** builder-паттерн (`query().where('status', 'done').orderBy('priority')`) — встроенный DSL через цепочки методов.
**Python:** SQLAlchemy ORM (`session.query(Task).filter(Task.status == 'done')`) — EDSL для SQL.
**Ruby:** язык Rake, RSpec — классические EDSL, возможные благодаря гибкому синтаксису Ruby.
В Haskell EDSL получаются элегантными из-за системы типов и `do`-нотации.
```

В этой главе мы построим **внешний DSL** — язык запросов, который пользователь будет вводить как текст, а мы будем его парсить в структурированное представление.

## megaparsec: современные парсеры для Haskell

### Зачем megaparsec

В Haskell есть несколько библиотек для парсинга:

| Библиотека | Особенности |
|-----------|-------------|
| `parsec` | Классическая, но устаревшая |
| `megaparsec` | Современная, лучшие сообщения об ошибках |
| `attoparsec` | Быстрая, но менее информативные ошибки |
| `happy` + `alex` | Генераторы парсеров (как yacc/lex) |

Мы используем **megaparsec** — он даёт лучший баланс между удобством, производительностью и качеством ошибок.

### Тип `Parsec`

Центральный тип megaparsec:

```haskell
type Parser = Parsec Void Text
```

Здесь:

- `Parsec` — тип парсера из megaparsec.
- `Void` — тип пользовательских ошибок (мы не используем кастомные ошибки, поэтому `Void`).
- `Text` — тип входного потока (парсим текст).

Парсер — это *функция*, которая принимает текст и возвращает либо результат парсинга, либо ошибку с позицией.

```haskell
import Data.Void (Void)
import Data.Text (Text)
import Text.Megaparsec
import Text.Megaparsec.Char
import Text.Megaparsec.Char.Lexer qualified as L

type Parser = Parsec Void Text
```

### Запуск парсера

```haskell
-- parse :: Parser a -> String -> Text -> Either (ParseErrorBundle Text Void) a
-- Первый аргумент — парсер
-- Второй — имя файла (для сообщений об ошибках)
-- Третий — входной текст

parse (string "hello") "" "hello world"
-- Right "hello"

parse (string "hello") "" "bye"
-- Left (ParseErrorBundle ...)
```

Для удобства есть `parseMaybe`, который возвращает `Maybe`:

```haskell
parseMaybe (string "hello") "hello world"
-- Just "hello"

parseMaybe (string "hello") "bye"
-- Nothing
```

## Парсинг примитивов

### `char` и `string` — конкретные символы

```haskell
-- Парсит ровно один указанный символ
charParser :: Parser Char
charParser = char 'a'

-- Парсит конкретную строку
helloParser :: Parser Text
helloParser = string "hello"
```

```text
> parseMaybe charParser "abc"
Just 'a'

> parseMaybe charParser "xyz"
Nothing

> parseMaybe helloParser "hello world"
Just "hello"
```

### `satisfy` — парсинг по предикату

```haskell
-- Парсит один символ, удовлетворяющий условию
vowel :: Parser Char
vowel = satisfy (`elem` ("aeiou" :: String))

digit :: Parser Char
digit = satisfy (\c -> c >= '0' && c <= '9')
```

```text
> parseMaybe vowel "apple"
Just 'a'

> parseMaybe vowel "banana"
Nothing    -- 'b' не гласная
```

### `digitChar`, `letterChar`, `alphaNumChar`

megaparsec предоставляет готовые парсеры для распространённых категорий символов:

```haskell
digitChar    :: Parser Char   -- цифры: '0'..'9'
letterChar   :: Parser Char   -- буквы (Unicode)
alphaNumChar :: Parser Char   -- буквы и цифры
spaceChar    :: Parser Char   -- пробельные символы
upperChar    :: Parser Char   -- заглавные буквы
lowerChar    :: Parser Char   -- строчные буквы
```

Каждый из этих парсеров потребляет ровно один символ подходящей категории. `letterChar`, `upperChar` и `lowerChar` используют Unicode-классификацию символов — они распознают кириллицу, китайские иероглифы и другие алфавиты, а не только ASCII.

### `many` и `some` — повторение

```haskell
-- many: 0 или более раз (как * в регулярках)
-- some: 1 или более раз (как + в регулярках)

digits :: Parser String
digits = some digitChar

word :: Parser String
word = some letterChar
```

```text
> parseMaybe digits "12345abc"
Just "12345"

> parseMaybe digits "abc"
Nothing    -- some требует хотя бы одно совпадение

> parseMaybe (many digitChar) "abc"
Just ""    -- many допускает 0 совпадений
```

```admonish note title="many vs some"
`many` никогда не падает — в худшем случае возвращает пустой список. `some` требует хотя бы одно совпадение. Это важно при составлении комбинаторов: если подпарсер может не совпасть, используйте `many`; если обязателен хотя бы один элемент — `some`.
```

### `takeWhileP` и `takeWhile1P` — эффективный парсинг текста

Для парсинга `Text` (а не `String`) удобнее использовать:

```haskell
-- Забирает символы, пока предикат истинен (0 или более)
identifier :: Parser Text
identifier = takeWhile1P (Just "identifier char") (\c -> c /= ':' && c /= ' ')
```

`takeWhile1P` работает как `some` + `satisfy`, но возвращает `Text` напрямую, без промежуточного `String`.

## Комбинаторы

Сила парсер-комбинаторов в том, что маленькие парсеры *комбинируются* в большие. Парсер — не монолит, а композиция.

### Последовательность: `Applicative` и `Monad`

Парсеры — это `Applicative` и `Monad`, поэтому их можно комбинировать через `<*>`, `*>`, `<*`, `>>=` и `do`-нотацию:

```haskell
-- Парсим "ключ:значение"
keyValue :: Parser (Text, Text)
keyValue = do
  key <- takeWhile1P (Just "key") (/= ':')
  _ <- char ':'
  value <- takeWhile1P (Just "value") (/= ' ')
  pure (key, value)
```

```text
> parseMaybe keyValue "status:done"
Just ("status","done")
```

Через `Applicative`-стиль:

```haskell
keyValue' :: Parser (Text, Text)
keyValue' = (,)
  <$> takeWhile1P (Just "key") (/= ':')
  <*  char ':'
  <*> takeWhile1P (Just "value") (/= ' ')
```

`<*` означает «выполни правый парсер, но верни результат левого». `*>` — наоборот.

### `choice` и `<|>` — альтернативы

```haskell
-- <|> пробует первый парсер, при неудаче — второй
boolParser :: Parser Bool
boolParser = (True <$ string "true") <|> (False <$ string "false")
```

```text
> parseMaybe boolParser "true"
Just True

> parseMaybe boolParser "false"
Just False
```

`choice` — обобщение `<|>` на список:

```haskell
-- choice пробует парсеры по очереди
priorityParser :: Parser Priority
priorityParser = choice
  [ High   <$ string "high"
  , Medium <$ string "medium"
  , Low    <$ string "low"
  ]
```

### `try` — откат при неудаче

По умолчанию megaparsec не откатывается, если парсер потребил часть ввода. `try` обеспечивает полный откат:

```haskell
-- Без try: если "status" совпало, но после двоеточия нет "done",
-- парсер не попробует альтернативу
-- С try: парсер откатится к началу

statusDone :: Parser Status
statusDone = try (Done <$ string "done")
         <|> try (InProgress <$ string "in-progress")
         <|> (Todo <$ string "todo")
```

```admonish warning title="Когда нужен try"
`try` нужен, когда альтернативы начинаются с одинаковых символов. Без `try` парсер, потребивший часть ввода, не даст шанса альтернативе. Но не злоупотребляйте `try` — он ухудшает сообщения об ошибках и может замедлить парсинг.
```

### `optional` — необязательный элемент

```haskell
-- optional :: Parser a -> Parser (Maybe a)
-- Пробует парсер; если не получилось — возвращает Nothing

quotedOrPlain :: Parser Text
quotedOrPlain = do
  q <- optional (char '"')
  content <- case q of
    Just _  -> takeWhileP Nothing (/= '"') <* char '"'
    Nothing -> takeWhile1P Nothing (/= ' ')
  pure content
```

### `between` — парсинг между разделителями

```haskell
-- between open close p = open *> p <* close
parens :: Parser a -> Parser a
parens = between (char '(') (char ')')

quoted :: Parser Text
quoted = between (char '"') (char '"') (takeWhileP Nothing (/= '"'))
```

```text
> parseMaybe (parens digits) "(123)"
Just "123"

> parseMaybe quoted "\"hello world\""
Just "hello world"
```

### `sepBy` и `sepBy1` — списки с разделителем

```haskell
-- sepBy: 0 или более элементов, разделённых разделителем
-- sepBy1: 1 или более

tags :: Parser [Text]
tags = takeWhile1P Nothing (/= ',') `sepBy` char ','
```

```text
> parseMaybe tags "work,home,urgent"
Just ["work","home","urgent"]

> parseMaybe tags ""
Just []
```

`sepBy` возвращает пустой список для пустого ввода — это не ошибка, а намеренное поведение для необязательных списков. Если нужен хотя бы один элемент, используйте `sepBy1`, которая провалится при пустом вводе.

## Строим AST

### Что такое AST

**AST** (Abstract Syntax Tree) — структурированное представление разобранного текста. Вместо работы с сырыми строками мы переводим текст в типы данных, с которыми удобно работать.

Для нашего языка запросов определим AST:

```haskell
-- Значение фильтра: текст или список тегов
data FilterValue
  = TextValue Text           -- простое значение: "done", "high"
  | ListValue [Text]         -- список: "work,home"
  | QuotedValue Text         -- значение в кавычках: "\"long text\""
  deriving (Show, Eq)

-- Один критерий фильтрации
data FilterExpr
  = StatusFilter FilterValue       -- status:done
  | PriorityFilter FilterValue     -- priority:high
  | TagFilter FilterValue          -- tag:work
  | TitleFilter FilterValue        -- title:"купить молоко"
  | AssigneeFilter FilterValue     -- assignee:alice
  | NotFilter FilterExpr           -- -status:done (отрицание)
  deriving (Show, Eq)

-- Запрос — список критериев (AND-семантика)
newtype Query = Query [FilterExpr]
  deriving (Show, Eq)
```

```admonish tip title="Знакомый аналог"
**TypeScript:**
```typescript
type FilterExpr =
  | { kind: 'status'; value: FilterValue }
  | { kind: 'priority'; value: FilterValue }
  | { kind: 'not'; expr: FilterExpr }
```

AST — это discriminated union (ADT) в TypeScript, enum в Rust. Парсер переводит текст в такую структуру.

### Зачем нужен AST

Без AST мы бы работали со строками напрямую:

```haskell
-- Плохо: строковый разбор
filterByQuery :: String -> [Task] -> [Task]
filterByQuery query tasks =
  if "status:done" `isInfixOf` query then filter isDone tasks
  else if "priority:high" `isInfixOf` query then filter isHigh tasks
  else tasks
-- Хрупко, не расширяемо, не обрабатывает комбинации
```

С AST:

```haskell
-- Хорошо: работаем со структурированными данными
applyQuery :: Query -> [Task] -> [Task]
applyQuery (Query filters) tasks =
  foldl' (\ts f -> filter (matchFilter f) ts) tasks filters
```

AST даёт:

- **Типобезопасность**: невалидный запрос не пройдёт парсер.
- **Расширяемость**: новый фильтр — новый конструктор + ветка в `matchFilter`.
- **Тестируемость**: парсер и исполнитель тестируются отдельно.

## Проект: язык запросов для трекера задач

### Синтаксис языка

Наш язык запросов поддерживает:

```text
status:done                    -- фильтр по статусу
priority:high                  -- фильтр по приоритету
tag:work                       -- фильтр по тегу
title:"купить молоко"          -- фильтр по заголовку (с кавычками)
-status:done                   -- отрицание: задачи НЕ done
status:done priority:high      -- AND: оба условия одновременно
tag:work,home                  -- тег work ИЛИ home
```

### Парсер значений

Начнём с парсинга значений фильтра:

```haskell
-- Значение в кавычках: "текст с пробелами"
pQuotedValue :: Parser FilterValue
pQuotedValue = QuotedValue <$> between (char '"') (char '"') (takeWhileP Nothing (/= '"'))

-- Список значений через запятую: work,home,urgent
pListValue :: Parser FilterValue
pListValue = do
  vals <- takeWhile1P Nothing (\c -> c /= ',' && c /= ' ') `sepBy1` char ','
  pure $ case vals of
    [single] -> TextValue single   -- один элемент — просто TextValue
    multiple -> ListValue multiple  -- несколько — ListValue

-- Значение: сначала пробуем кавычки, затем список
pValue :: Parser FilterValue
pValue = pQuotedValue <|> pListValue
```

`pValue` сначала пробует кавычки (`pQuotedValue`), а если они отсутствуют — переходит к `pListValue`. В `pListValue` особый случай: если элемент один, возвращается `TextValue`, а не `ListValue [single]` — это упрощает сопоставление с образцом в исполнителе запросов.

### Парсер фильтров

```haskell
-- Парсер одного критерия фильтрации
pFilterExpr :: Parser FilterExpr
pFilterExpr = pNegated <|> pPositive
  where
    pNegated = do
      _ <- char '-'
      NotFilter <$> pPositive

    pPositive = choice
      [ StatusFilter   <$> (string "status:"   *> pValue)
      , PriorityFilter <$> (string "priority:" *> pValue)
      , TagFilter      <$> (string "tag:"      *> pValue)
      , TitleFilter    <$> (string "title:"    *> pValue)
      , AssigneeFilter <$> (string "assignee:" *> pValue)
      ]
```

`choice` пробует варианты по порядку и останавливается на первом успешном. Поскольку ни один из ключей (`status:`, `priority:`, `tag:` и т.д.) не является префиксом другого, `try` здесь не нужен — потребив ключ и убедившись в несовпадении, альтернатив уже нет.

### Парсер запроса

```haskell
-- Пропуск пробелов
sc :: Parser ()
sc = L.space space1 empty empty

-- Лексема — парсер, который пропускает пробелы после совпадения
lexeme :: Parser a -> Parser a
lexeme = L.lexeme sc

-- Полный запрос: список фильтров, разделённых пробелами
pQuery :: Parser Query
pQuery = do
  sc                                  -- пропустить ведущие пробелы
  filters <- many (lexeme pFilterExpr)  -- фильтры с пробелами между ними
  eof                                  -- убедиться, что весь ввод разобран
  pure (Query filters)
```

Вызов `eof` в конце — важная деталь: без него парсер мог бы «успешно» разобрать только часть ввода, проигнорировав остаток. `eof` гарантирует, что весь текст был корректно разобран, и превращает лишние символы в ошибку.

### Запуск парсера

```haskell
parseQuery :: Text -> Either String Query
parseQuery input =
  case parse pQuery "query" input of
    Left err  -> Left (errorBundlePretty err)
    Right res -> Right res
```

```text
> parseQuery "status:done priority:high"
Right (Query [StatusFilter (TextValue "done"), PriorityFilter (TextValue "high")])

> parseQuery "tag:work,home -status:done"
Right (Query [TagFilter (ListValue ["work","home"]), NotFilter (StatusFilter (TextValue "done"))])

> parseQuery "title:\"купить молоко\""
Right (Query [TitleFilter (QuotedValue "купить молоко")])

> parseQuery "invalid query"
Left "1:1:\n  |\n1 | invalid query\n  | ^\nunexpected 'i'\n..."
```

`errorBundlePretty` форматирует ошибку megaparsec в читаемый текст: строка, позиция, неожиданный символ и список ожидаемых вариантов. Это и есть то «лучшее качество ошибок», за которое выбирают megaparsec.

### Исполнение запроса

Теперь свяжем AST с логикой трекера:

```haskell
import Data.Text qualified as T

matchFilter :: FilterExpr -> Task -> Bool
matchFilter (StatusFilter val) task =
  matchValue val (T.toLower . T.pack . show $ taskStatus task)
matchFilter (PriorityFilter val) task =
  matchValue val (T.toLower . T.pack . show $ taskPriority task)
matchFilter (TagFilter val) task =
  any (matchValue val) (taskTags task)
matchFilter (TitleFilter val) task =
  matchTextContains val (taskTitle task)
matchFilter (AssigneeFilter val) task =
  matchValue val (taskAssignee task)
matchFilter (NotFilter expr) task =
  not (matchFilter expr task)

-- Проверка совпадения значения
matchValue :: FilterValue -> Text -> Bool
matchValue (TextValue v) t    = T.toLower v == T.toLower t
matchValue (QuotedValue v) t  = T.toLower v == T.toLower t
matchValue (ListValue vs) t   = any (\v -> T.toLower v == T.toLower t) vs

-- Проверка вхождения подстроки
matchTextContains :: FilterValue -> Text -> Bool
matchTextContains (TextValue v) t    = T.toLower v `T.isInfixOf` T.toLower t
matchTextContains (QuotedValue v) t  = T.toLower v `T.isInfixOf` T.toLower t
matchTextContains (ListValue vs) t   = any (\v -> T.toLower v `T.isInfixOf` T.toLower t) vs

-- Применение полного запроса (AND-семантика)
applyQuery :: Query -> [Task] -> [Task]
applyQuery (Query filters) tasks =
  foldl' (\ts f -> filter (matchFilter f) ts) tasks filters
```

`matchFilter` и `matchValue` не знают о парсере — они работают только с AST. Сравнение регистронезависимо: `T.toLower` применяется к обеим сторонам. `applyQuery` использует `foldl'` — каждый фильтр последовательно сужает список задач, реализуя AND-семантику.

### Собираем всё вместе

```haskell
-- Полный пайплайн: текст запроса → отфильтрованные задачи
runQuery :: Text -> [Task] -> Either String [Task]
runQuery queryText tasks = do
  query <- parseQuery queryText
  pure (applyQuery query tasks)
```

```text
> let tasks = [Task "Купить молоко" "" Low Todo ["дом"], Task "Релиз" "" High Done ["работа"]]
> runQuery "status:todo" tasks
Right [Task "Купить молоко" ...]

> runQuery "-priority:low" tasks
Right [Task "Релиз" ...]
```

```admonish note title="Разделение ответственности"
Обратите внимание на архитектуру: парсер (`pQuery`) ничего не знает о задачах, а исполнитель (`applyQuery`) ничего не знает о синтаксисе. Между ними — AST, чистый интерфейс. Это классический паттерн: **синтаксис** отделён от **семантики**.
```

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

### Проект

1. Реализуйте парсер `pFilterExpr`, который разбирает один критерий фильтрации (`status:done`, `priority:high`, `tag:work`) и возвращает `FilterExpr`.

    ```haskell
    pFilterExpr :: Parser FilterExpr
    ```

    *Подсказка:* используйте `choice` и `string "status:" *> pValue`.

2. Реализуйте парсер `pQuery`, который разбирает полный запрос (несколько фильтров, разделённых пробелами) и возвращает `Query`.

    ```haskell
    pQuery :: Parser Query
    ```

3. Реализуйте функцию `matchFilter`, которая проверяет, соответствует ли задача одному фильтру.

    ```haskell
    matchFilter :: FilterExpr -> Task -> Bool
    ```

### Практика

4. Добавьте поддержку оператора `or:` — объединение нескольких фильтров через OR:

    ```text
    or:(status:done status:in-progress)
    ```

    *Подсказка:* добавьте конструктор `OrFilter [FilterExpr]` в `FilterExpr` и парсер с `between (string "or:(") (char ')')`.

5. Добавьте поддержку сортировки в язык запросов:

    ```text
    status:done sort:priority
    ```

    *Подсказка:* определите отдельный тип `SortExpr` и расширьте `Query`.

6. Реализуйте функцию `prettyQuery`, которая красиво печатает `Query` обратно в текст:

    ```haskell
    prettyQuery :: Query -> Text
    -- prettyQuery (Query [StatusFilter (TextValue "done"), PriorityFilter (TextValue "high")])
    -- == "status:done priority:high"
    ```

    Это свойство (parse . pretty = id) называется **roundtrip** и полезно для тестирования.

## Заключение

Парсер-комбинаторы — одна из областей, где Haskell блистает. Монадический интерфейс позволяет строить парсеры как конструктор из кубиков, а система типов гарантирует корректность AST. В этой главе мы прошли весь путь: от примитивов (`char`, `string`, `satisfy`) через комбинаторы (`choice`, `<|>`, `try`, `between`, `sepBy`) до полноценного парсера и исполнителя для языка запросов трекера задач. Ключевой архитектурный приём — разделение на три слоя: синтаксис (парсер), представление (AST) и семантика (исполнитель).

В [следующей главе](chapter19.md) мы перейдём к GADTs и семействам типов — продвинутым возможностям системы типов, которые позволяют выражать ещё более точные инварианты.

```admonish tip title="Для углубления"
- **megaparsec** — [официальная документация](https://hackage.haskell.org/package/megaparsec) и [туториал](https://markkarpov.com/tutorial/megaparsec.html) от автора библиотеки Марка Карпова. Лучший ресурс для изучения.
- **Write You a Haskell** — [раздел о парсинге](http://dev.stephendiehl.com/fun/002_parsing.html): построение парсера для языка программирования.
- **Haskell MOOC** — [haskell.mooc.fi](https://haskell.mooc.fi/), лекция 18: парсинг.
```
