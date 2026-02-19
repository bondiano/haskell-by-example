# Монады

## Цели главы

В предыдущей главе мы познакомились с `Applicative` — абстракцией, позволяющей применять функции к значениям в контексте. В этой главе мы пойдём дальше и разберём **монады** — один из ключевых механизмов Haskell.

Мы изучим класс типов `Monad`, разберём `do`-нотацию как синтаксический сахар для оператора `>>=`, рассмотрим конкретные монады (`Maybe`, `Either`, список, `Writer`, `Reader`) и сформулируем законы монад.

## Структура проекта

Откройте директорию `exercises/chapter08`:

```text
chapter08/
├── package.yaml
├── src/
│   └── Data/
│       ├── Phonebook.hs      ← вложенные Map для поиска
│       └── Chess.hs           ← шахматный конь
├── test/
│   ├── Spec.hs               ← тесты
│   └── MySolutions.hs        ← ваши решения
└── no-peeking/
    └── Solutions.hs           ← эталонные решения
```

## От Applicative к Monad

В главе 7 мы видели, как `Applicative` позволяет применять чистые функции к значениям «в контексте»:

```haskell
(+) <$> Just 3 <*> Just 5   -- Just 8
(+) <$> Just 3 <*> Nothing  -- Nothing
```

Но `Applicative` имеет ограничение: **следующее вычисление не может зависеть от результата предыдущего**. Каждый аргумент `<*>` определяется заранее.

Рассмотрим задачу. У нас есть вложенная телефонная книга: по городу находим отдел, по отделу — сотрудника, по сотруднику — телефон.

```haskell
type Departments = Map String (Map String String)

lookupPhone :: String -> String -> Departments -> Maybe String
lookupPhone city name deps =
  case Map.lookup city deps of
    Nothing   -> Nothing
    Just dept -> case Map.lookup name dept of
      Nothing    -> Nothing
      Just phone -> Just phone
```

Каждый следующий `Map.lookup` **зависит от результата предыдущего** — мы не можем передать его через `<*>`. Нам нужна операция, которая:

1. Выполняет первое вычисление.
2. Передаёт его результат в функцию, определяющую следующее вычисление.

Эта операция — **bind** (`>>=`).

## Класс типов Monad

```haskell
class Applicative m => Monad m where
  (>>=)  :: m a -> (a -> m b) -> m b
  (>>)   :: m a -> m b -> m b
  return :: a -> m a

  m >> n  = m >>= \_ -> n       -- по умолчанию
  return  = pure                -- по умолчанию
```

- `>>=` (bind, «связать») — выполняет вычисление `m a`, передаёт результат в функцию `a -> m b`.
- `>>` — выполняет два вычисления последовательно, результат первого игнорируется.
- `return` — то же, что `pure` из `Applicative` (оборачивает значение в контекст).

Иерархия: `Functor` ⊂ `Applicative` ⊂ `Monad`. Каждая монада — аппликатив, каждый аппликатив — функтор.

```text
fmap  :: (a -> b)   -> f a -> f b      -- Functor
(<*>) :: f (a -> b) -> f a -> f b      -- Applicative
(>>=) :: m a -> (a -> m b) -> m b      -- Monad
```

Ключевое отличие `>>=` от `<*>`: функция `a -> m b` **сама выбирает** следующее вычисление на основе полученного значения `a`.

## Maybe как монада

`Maybe` — простейшая монада. Она моделирует вычисления, которые могут не дать результата:

```haskell
instance Monad Maybe where
  Nothing >>= _ = Nothing     -- если провал — дальше не идём
  Just x  >>= f = f x         -- если успех — передаём в f
```

Перепишем `lookupPhone` через `>>=`:

```haskell
lookupPhone :: String -> String -> Departments -> Maybe String
lookupPhone city name deps =
  Map.lookup city deps >>= \dept ->
  Map.lookup name dept
```

Сравните с версией на `case`: три уровня вложенности сократились до одной строки. Оператор `>>=` автоматически «протаскивает» `Nothing` — если любой шаг вернёт `Nothing`, вся цепочка вернёт `Nothing`.

Цепочку можно продолжать:

```haskell
Map.lookup "Москва" deps >>= \dept ->
Map.lookup "Алиса" dept  >>= \phone ->
Just ("Телефон: " ++ phone)
```

## Either как монада

`Either e` работает аналогично `Maybe`, но при провале сохраняет сообщение об ошибке:

```haskell
instance Monad (Either e) where
  Left err >>= _ = Left err    -- ошибка: дальше не идём
  Right x  >>= f = f x         -- успех: продолжаем
```

Пример — валидация с ранним выходом:

```haskell
validateAge :: Int -> Either String Int
validateAge age
  | age < 0   = Left "Возраст не может быть отрицательным"
  | age > 150 = Left "Возраст слишком большой"
  | otherwise = Right age

validateName :: String -> Either String String
validateName name
  | null name = Left "Имя не может быть пустым"
  | otherwise = Right name

validatePerson :: String -> Int -> Either String (String, Int)
validatePerson name age =
  validateName name >>= \n ->
  validateAge age   >>= \a ->
  Right (n, a)
```

Первая ошибка прерывает всю цепочку:

```text
> validatePerson "" 25
Left "Имя не может быть пустым"

> validatePerson "Алиса" (-5)
Left "Возраст не может быть отрицательным"

> validatePerson "Алиса" 25
Right ("Алиса", 25)
```

> **Отличие от `Validation`** (глава 7): `Either` как монада останавливается на *первой* ошибке, а `Validation` с `Applicative` *накапливает* все ошибки. Это принципиальная разница: монадическая цепочка `>>=` не может продолжить вычисление после ошибки, потому что следующий шаг зависит от предыдущего результата.

## Монада списка

Список `[]` — монада, моделирующая **недетерминизм**: каждое вычисление может вернуть несколько (или ноль) результатов, и `>>=` комбинирует все варианты:

```haskell
instance Monad [] where
  xs >>= f = concatMap f xs
```

Пример — все пары из двух списков:

```haskell
pairs :: [a] -> [b] -> [(a, b)]
pairs xs ys = xs >>= \x -> ys >>= \y -> [(x, y)]
```

```text
> pairs [1, 2] ['a', 'b']
[(1,'a'), (1,'b'), (2,'a'), (2,'b')]
```

Каждый элемент `xs` комбинируется с каждым элементом `ys` — как вложенный цикл в императивном коде.

### Связь с генераторами списков

Генераторы списков (list comprehensions) — это синтаксический сахар для монады списка:

```haskell
-- Генератор списков
[(x, y) | x <- [1, 2], y <- ['a', 'b']]

-- Эквивалент через >>=
[1, 2] >>= \x -> ['a', 'b'] >>= \y -> [(x, y)]
```

### guard: фильтрация в монаде списка

Функция `guard` из `Control.Monad` работает как фильтр:

```haskell
guard :: Bool -> [()]
guard True  = [()]
guard False = []
```

Если условие ложно, `guard` возвращает пустой список, обрывая ветвь. Если истинно — продолжает:

```haskell
import Control.Monad (guard)

-- Все пифагоровы тройки до n
pythagorean :: Int -> [(Int, Int, Int)]
pythagorean n =
  [1..n] >>= \a ->
  [a..n] >>= \b ->
  [b..n] >>= \c ->
  guard (a*a + b*b == c*c) >>
  [(a, b, c)]
```

```text
> pythagorean 20
[(3,4,5),(5,12,13),(6,8,10),(8,15,17),(9,12,15)]
```

## do-нотация

Цепочки `>>=` с лямбдами быстро становятся нечитаемыми. Haskell предоставляет **do-нотацию** — синтаксический сахар:

```haskell
-- Через >>=
lookupPhone city name deps =
  Map.lookup city deps >>= \dept ->
  Map.lookup name dept

-- Через do
lookupPhone city name deps = do
  dept  <- Map.lookup city deps
  Map.lookup name dept
```

### Правила десахаризации

`do`-нотация раскрывается в `>>=` и `>>` по простым правилам:

```haskell
-- 1. x <- action  ⟹  action >>= \x ->
-- 2. action        ⟹  action >>
-- 3. let x = expr  ⟹  let x = expr in
-- 4. Последнее выражение — результат всего do-блока
```

Пример пошаговой десахаризации:

```haskell
-- do-нотация              -- десахаризация
do                         -- Map.lookup city deps >>= \dept ->
  dept <- Map.lookup       --   Map.lookup name dept >>= \phone ->
            city deps      --     Just ("Тел: " ++ phone)
  phone <- Map.lookup
             name dept
  Just ("Тел: " ++ phone)
```

### let в do-блоке

`let` в `do`-блоке связывает **чистое** значение (без `<-`):

```haskell
transform :: Maybe Int -> Maybe String
transform mx = do
  x <- mx
  let doubled = x * 2        -- чистое вычисление
  let message = show doubled
  Just ("Результат: " ++ message)
```

### Паттерн-матчинг в `<-`

В `<-` можно использовать паттерн:

```haskell
firstAndSecond :: [(String, Int)] -> Maybe (String, Int)
firstAndSecond pairs = do
  (name, _) <- lookup "first" pairs   -- деструктуризация пары
  (_, age)  <- lookup "second" pairs
  Just (name, age)
```

Если паттерн не совпадает, вызывается `fail` из `MonadFail`. Для `Maybe` это `Nothing`.

## do-нотация работает для любой монады

`do`-нотация **не привязана к `IO`**. Она работает для любого типа с экземпляром `Monad`:

```haskell
-- Maybe
safeDivide :: Double -> Double -> Maybe Double
safeDivide _ 0 = Nothing
safeDivide x y = Just (x / y)

calculate :: Maybe Double
calculate = do
  a <- safeDivide 10 3
  b <- safeDivide 20 a
  safeDivide b 2
```

```haskell
-- Список
chessMoves :: [(Int, Int)]
chessMoves = do
  x <- [1..3]
  y <- [1..3]
  guard (x /= y)
  return (x, y)
```

```haskell
-- Either
parseConfig :: String -> Either String Int
parseConfig s = do
  stripped <- if null s then Left "пустая строка" else Right s
  case reads stripped of
    [(n, "")] -> Right n
    _         -> Left ("не число: " ++ stripped)
```

## Writer: монада с логированием

Монада `Writer` позволяет накапливать «попутный» вывод наряду с основным результатом. Это полезно для логирования, аудита, сбора метрик.

```haskell
import Control.Monad.Writer

-- Writer w a — вычисление с результатом a и накопленным выводом w
-- w должен быть моноидом (чтобы его можно было объединять)
```

Основные функции:

```haskell
tell      :: w -> Writer w ()           -- записать в лог
runWriter :: Writer w a -> (a, w)       -- запустить и получить (результат, лог)
```

Пример — вычисление с аудит-логом:

```haskell
type Log = [String]

gcd' :: Int -> Int -> Writer Log Int
gcd' a 0 = do
  tell ["Готово: " ++ show a]
  return a
gcd' a b = do
  tell [show a ++ " mod " ++ show b ++ " = " ++ show (a `mod` b)]
  gcd' b (a `mod` b)
```

```text
> runWriter (gcd' 12 8)
(4, ["12 mod 8 = 4", "8 mod 4 = 0", "Готово: 4"])
```

`Writer` накапливает лог автоматически: каждый `tell` дописывает к общему логу через `(<>)` моноида.

## Reader: монада с окружением

Монада `Reader` передаёт **неизменяемое окружение** через цепочку вычислений — без необходимости передавать его явно в каждую функцию.

```haskell
import Control.Monad.Reader

-- Reader r a — вычисление, читающее окружение типа r и возвращающее a
```

Основные функции:

```haskell
ask       :: Reader r r               -- получить всё окружение
asks      :: (r -> a) -> Reader r a   -- получить часть окружения
local     :: (r -> r) -> Reader r a -> Reader r a  -- изменить окружение локально
runReader :: Reader r a -> r -> a     -- запустить с окружением
```

Пример — форматирование с конфигурацией:

```haskell
data Config = Config
  { cfgIndent    :: Int
  , cfgUpperCase :: Bool
  } deriving (Show)

formatName :: String -> Reader Config String
formatName name = do
  cfg <- ask
  let formatted = if cfgUpperCase cfg
        then map toUpper name
        else name
  let indent = replicate (cfgIndent cfg) ' '
  return (indent ++ formatted)
```

```text
> runReader (formatName "алиса") (Config 4 True)
"    АЛИСА"

> runReader (formatName "алиса") (Config 0 False)
"алиса"
```

`Reader` избавляет от «прокидывания» конфигурации через все функции. В главе 12 мы увидим `ReaderT` — трансформер, который комбинирует `Reader` с другими монадами.

## Законы монад

Как и `Functor` и `Applicative`, `Monad` подчиняется трём законам. Они гарантируют предсказуемое поведение `>>=`:

### Левая единица

```haskell
return a >>= f  ≡  f a
```

Оборачивание значения в `return` и немедленная передача в `f` — то же самое, что просто вызвать `f`.

```text
> return 5 >>= \x -> Just (x + 1)
Just 6
> (\x -> Just (x + 1)) 5
Just 6
```

### Правая единица

```haskell
m >>= return  ≡  m
```

Передача результата в `return` не меняет вычисление.

```text
> Just 5 >>= return
Just 5
```

### Ассоциативность

```haskell
(m >>= f) >>= g  ≡  m >>= (\x -> f x >>= g)
```

Порядок группировки цепочки `>>=` не влияет на результат. Это позволяет свободно рефакторить do-блоки: извлекать подвыражения в отдельные функции и встраивать их обратно.

## Полезные функции из Control.Monad

Модуль `Control.Monad` содержит функции, упрощающие работу с монадами:

```haskell
mapM  :: Monad m => (a -> m b) -> [a] -> m [b]   -- map + sequence
mapM_ :: Monad m => (a -> m b) -> [a] -> m ()     -- то же, без результата
forM  :: Monad m => [a] -> (a -> m b) -> m [b]    -- mapM с перевёрнутыми аргументами
forM_ :: Monad m => [a] -> (a -> m b) -> m ()
```

```haskell
when   :: Monad m => Bool -> m () -> m ()   -- выполнить действие по условию
unless :: Monad m => Bool -> m () -> m ()   -- выполнить, если условие ложно
```

```haskell
join :: Monad m => m (m a) -> m a           -- «сплющить» вложенный контекст
-- join (Just (Just 5))  =  Just 5
-- join (Just Nothing)   =  Nothing
-- join [[1,2], [3,4]]   =  [1,2,3,4]
```

```haskell
(>=>) :: Monad m => (a -> m b) -> (b -> m c) -> (a -> m c)  -- композиция Клейсли
```

Композиция Клейсли `(>=>)` — аналог `(.)` для монадических функций. Она позволяет строить конвейеры:

```haskell
-- Обычная композиция функций:
-- (.)   :: (b -> c) -> (a -> b) -> (a -> c)

-- Композиция Клейсли:
-- (>=>) :: (a -> m b) -> (b -> m c) -> (a -> m c)

lookupCity   :: String -> Maybe String  -- найти город по стране
lookupDept   :: String -> Maybe String  -- найти отдел по городу
lookupPhone  :: String -> Maybe String  -- найти телефон по отделу

-- Конвейер:
findPhone :: String -> Maybe String
findPhone = lookupCity >=> lookupDept >=> lookupPhone
```

## Упражнения

Решения пишите в файле `test/MySolutions.hs`. После каждого упражнения запускайте `stack test`.

1. **(Лёгкое)** Модуль `Data.Phonebook` предоставляет вложенную телефонную книгу:

    ```haskell
    type Phonebook = Map String (Map String String)
    exampleBook :: Phonebook
    ```

    Реализуйте функцию `safeLookup`, которая ищет телефон по городу и имени.
    Используйте `>>=` (не `case`/`do`).

    ```haskell
    safeLookup :: String -> String -> Phonebook -> Maybe String
    ```

    ```text
    > safeLookup "Москва" "Алиса" exampleBook
    Just "+7-495-111-1111"
    > safeLookup "Москва" "Неизвестный" exampleBook
    Nothing
    ```

2. **(Среднее)** Реализуйте `safeIndex` и `safeHead`:

    ```haskell
    safeIndex :: [a] -> Int -> Maybe a
    safeHead  :: [a] -> Maybe a
    ```

    Затем используйте `>>=` (или `do`) для `thirdElement`:

    ```haskell
    thirdElement :: [[a]] -> Maybe a
    ```

    Функция возвращает третий элемент первого подсписка. Вернёт `Nothing`, если список пуст, первый подсписок пуст или содержит менее трёх элементов.

3. **(Среднее)** Модуль `Data.Chess` определяет позицию шахматного коня и функцию всех возможных ходов:

    ```haskell
    type KnightPos = (Int, Int)
    moveKnight :: KnightPos -> [KnightPos]
    ```

    Реализуйте `canReachIn`, которая проверяет, может ли конь добраться из одной позиции в другую за ровно `n` ходов:

    ```haskell
    canReachIn :: Int -> KnightPos -> KnightPos -> Bool
    ```

    *Подсказка:* используйте `>>=` с `moveKnight` для генерации всех позиций после `n` ходов, затем проверьте `elem`.

    ```text
    > canReachIn 3 (6,2) (6,1)
    True
    > canReachIn 3 (6,2) (7,3)
    False
    ```

4. **(Продвинутое)** Реализуйте `collatzLog` — вычисление длины последовательности Коллатца с логированием каждого шага через `Writer`:

    ```haskell
    collatzLog :: Int -> Writer [String] Int
    ```

    Правила: если число чётное — делим на 2, нечётное — умножаем на 3 и прибавляем 1. Останавливаемся при 1. Каждый шаг записывается в лог через `tell`. Возвращается количество шагов.

    ```text
    > runWriter (collatzLog 6)
    (8, ["6 → 3","3 → 10","10 → 5","5 → 16","16 → 8","8 → 4","4 → 2","2 → 1"])
    ```

## Заключение

В этой главе мы:

- Познакомились с классом типов `Monad` и оператором `>>=` (bind).
- Разобрали, почему `Applicative` недостаточно для зависимых вычислений.
- Изучили конкретные монады: `Maybe`, `Either`, список, `Writer`, `Reader`.
- Освоили `do`-нотацию и её связь с `>>=` через десахаризацию.
- Увидели `guard` для фильтрации в монаде списка.
- Познакомились с законами монад и полезными функциями из `Control.Monad`.

`Endo` из `Data.Monoid` — моноид эндоморфизмов (`a -> a`), полезный для config builders и middleware-цепочек. Подробнее — в главе 19.

В следующей главе мы применим монады на практике: разберём монаду `IO` для взаимодействия с внешним миром.
