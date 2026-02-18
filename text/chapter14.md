# Генеративное тестирование

## Цели главы

В этой главе мы познакомимся с **генеративным тестированием** (property-based testing) — подходом, при котором свойства программы проверяются на сотнях случайно сгенерированных входов. Мы изучим библиотеку **QuickCheck**, научимся писать свойства, генераторы и пользовательские экземпляры `Arbitrary`.

## Структура проекта

Откройте директорию `exercises/chapter14`:

```text
chapter14/
├── package.yaml
├── src/
│   └── Data/
│       ├── MergeSort.hs     ← сортировка слиянием
│       ├── BST.hs           ← бинарное дерево поиска
│       └── Person.hs        ← тип Person + кодирование
├── test/
│   ├── Spec.hs              ← тесты (запускают ваши свойства)
│   └── MySolutions.hs       ← ваши решения
└── no-peeking/
    └── Solutions.hs          ← эталонные решения
```

В этой главе модули в `src/` предоставляют функции, которые вы будете **тестировать**, а не реализовывать. Ваша задача — написать свойства и генераторы в `MySolutions.hs`.

## От примеров к свойствам

В предыдущих главах мы писали тесты вида:

```haskell
it "mergeSort [3,1,2] == [1,2,3]" $
  mergeSort [3, 1, 2] `shouldBe` [1, 2, 3]
```

Такой тест проверяет **один конкретный пример**. Но корректность сортировки — это не конечный набор пар «вход → выход», а **свойство**, которое должно выполняться для _любого_ списка:

- Результат упорядочен.
- Длина не изменилась.
- Повторная сортировка не меняет результат.

**Генеративное тестирование** (property-based testing) — это подход, при котором вы формулируете такие свойства, а фреймворк сам генерирует сотни случайных входов и проверяет, что свойство выполняется для каждого из них.

QuickCheck — первая библиотека, реализовавшая этот подход. Она была создана Класом Клаессоном и Джоном Хьюзом в 2000 году именно для Haskell, а затем портирована на десятки языков, включая PureScript, Erlang, Scala и Python.

## Быстрый старт с QuickCheck

Запустите GHCi из директории `exercises/chapter14`:

```text
$ cd exercises/chapter14
$ stack ghci --test
```

Флаг `--test` загружает и тестовые модули, давая доступ к `Test.QuickCheck`.

Попробуем проверить простое свойство — обращение списка дважды возвращает исходный список:

```text
> import Test.QuickCheck
> quickCheck (\xs -> reverse (reverse xs) == (xs :: [Int]))
+++ OK, passed 100 tests.
```

QuickCheck сгенерировал 100 случайных списков `[Int]` и убедился, что свойство выполняется для каждого. Попробуем заведомо ложное свойство:

```text
> quickCheck (\xs -> reverse xs == (xs :: [Int]))
*** Failed! Falsifiable (after 3 tests and 3 shrinks):
[0,1]
```

QuickCheck нашёл контрпример `[0, 1]` — список, который не равен своему обращению. Обратите внимание на **«3 shrinks»** — QuickCheck не просто нашёл ошибку, а **упростил** контрпример до минимального.

## Свойства

Свойство (property) — это функция, которая принимает произвольные аргументы и возвращает результат, проверяемый QuickCheck. Самый простой вариант — функция, возвращающая `Bool`:

```haskell
prop_reverseReverse :: [Int] -> Bool
prop_reverseReverse xs = reverse (reverse xs) == xs
```

По соглашению имена свойств начинаются с `prop_`.

### Тип Property

Для более сложных проверок используется тип `Property`. Он позволяет добавлять условия, классификацию и пользовательские генераторы:

```haskell
prop_headOfSorted :: [Int] -> Property
prop_headOfSorted xs =
  not (null xs) ==>          -- предусловие: список непуст
    head (mergeSort xs) == minimum xs
```

Оператор `(==>)` задаёт **предусловие**: QuickCheck отбрасывает входы, для которых условие не выполняется, и считает только те, для которых выполняется. Используйте его с осторожностью — если предусловие слишком строгое, QuickCheck может не набрать достаточно тестов.

### Классификация: classify и label

Функция `classify` помечает тесты категориями, а `label` задаёт произвольную метку:

```haskell
prop_sortLength :: [Int] -> Property
prop_sortLength xs =
  classify (null xs) "пустой список" $
  classify (length xs > 10) "длинный список" $
    length (mergeSort xs) == length xs
```

При запуске QuickCheck покажет распределение:

```text
+++ OK, passed 100 tests:
  5% пустой список
 22% длинный список
```

Это помогает убедиться, что тесты покрывают разнообразные случаи, а не проверяют одно и то же.

### Покрытие: cover

Функция `cover` идёт дальше — она **требует** определённый минимум покрытия:

```haskell
prop_sortCoverage :: [Int] -> Property
prop_sortCoverage xs =
  cover 10 (length xs > 5) "список длиннее 5" $
    sorted (mergeSort xs)
```

Если менее 10% тестов попадают в категорию «список длиннее 5», QuickCheck сообщит об ошибке покрытия.

## Генераторы: тип Gen

Сердце QuickCheck — монада `Gen`. Она описывает **стратегию генерации** случайных значений. Вот основные комбинаторы:

| Комбинатор | Тип | Описание |
|-----------|-----|----------|
| `choose` | `(a, a) -> Gen a` | Случайное значение из диапазона |
| `elements` | `[a] -> Gen a` | Случайный элемент из списка |
| `oneof` | `[Gen a] -> Gen a` | Случайный выбор из генераторов (равновероятно) |
| `frequency` | `[(Int, Gen a)] -> Gen a` | Выбор с весами |
| `listOf` | `Gen a -> Gen [a]` | Список случайной длины |
| `vectorOf` | `Int -> Gen a -> Gen [a]` | Список фиксированной длины |
| `sized` | `(Int -> Gen a) -> Gen a` | Доступ к параметру размера |

`Gen` — монада, поэтому генераторы комбинируются через `do`-нотацию, `<$>` и `<*>`:

```haskell
-- Генератор пары (имя, возраст)
genNameAge :: Gen (String, Int)
genNameAge = do
  name <- elements ["Алиса", "Боб", "Чарли"]
  age  <- choose (1, 100)
  pure (name, age)
```

Или в аппликативном стиле:

```haskell
genNameAge :: Gen (String, Int)
genNameAge = (,)
  <$> elements ["Алиса", "Боб", "Чарли"]
  <*> choose (1, 100)
```

### Генератор отсортированного списка

Генерировать данные с определённой структурой — частая задача. Например, отсортированный список:

```haskell
genSortedList :: Gen [Int]
genSortedList = sort <$> listOf arbitrary
```

Здесь `arbitrary` — генератор из класса типов `Arbitrary` (о нём ниже), а `sort` из `Data.List` сортирует полученный список.

### forAll: подключение генератора к свойству

Функция `forAll` связывает пользовательский генератор со свойством:

```haskell
forAll :: (Show a, Testable prop) => Gen a -> (a -> prop) -> Property
```

Пример — проверка, что голова отсортированного непустого списка не больше последнего элемента:

```haskell
prop_sortedHeadLast :: Property
prop_sortedHeadLast =
  forAll (listOf1 arbitrary :: Gen [Int]) $ \xs ->
    let s = mergeSort xs
    in head s <= last s
```

`listOf1` генерирует непустые списки, а `forAll` встраивает генератор в свойство. Если свойство нарушится, QuickCheck покажет сгенерированное значение.

## Arbitrary: класс типов для генерации

Класс `Arbitrary` — основной способ определить «стандартный» генератор для типа:

```haskell
class Arbitrary a where
  arbitrary :: Gen a
  shrink    :: a -> [a]
  shrink _ = []    -- по умолчанию: не сжимать
```

Для базовых типов (`Int`, `Bool`, `Char`, `[a]`, `Maybe a`, `(a, b)`, ...) экземпляры `Arbitrary` уже определены. Это позволяет писать свойства вроде:

```haskell
prop_reverseReverse :: [Int] -> Bool
```

QuickCheck автоматически вызывает `arbitrary @[Int]` для генерации аргументов.

### Написание собственного Arbitrary

Для пользовательских типов нужно определить экземпляр вручную. Предположим, у нас есть тип `Color`:

```haskell
data Color = Red | Green | Blue deriving (Show, Eq)

instance Arbitrary Color where
  arbitrary = elements [Red, Green, Blue]
```

Для более сложных типов используйте комбинаторы `Gen`:

```haskell
data Rect = Rect
  { rectWidth  :: Double
  , rectHeight :: Double
  } deriving (Show)

instance Arbitrary Rect where
  arbitrary = Rect
    <$> (getPositive <$> arbitrary)  -- только положительные
    <*> (getPositive <$> arbitrary)
```

`Positive` — один из модификаторов QuickCheck (`Test.QuickCheck.Modifiers`), генерирующий только положительные числа.

## Shrinking: минимизация контрпримеров

Когда QuickCheck находит вход, нарушающий свойство, он пытается **упростить** его — найти минимальный контрпример. Этот процесс называется shrinking.

Метод `shrink` класса `Arbitrary` возвращает список «упрощённых» вариантов значения. Например, для списка `[3, 1, 4]` функция `shrink` может вернуть:

```text
> shrink [3, 1, 4]
[[1,4],[3,4],[3,1],[0,1,4],[2,1,4],[3,0,4],[3,1,0],[3,1,2],[3,1,3]]
```

QuickCheck рекурсивно пробует каждый вариант, пока свойство всё ещё нарушается, и выдаёт самый маленький найденный контрпример.

Для собственных типов shrinking определяется через `shrink`:

```haskell
instance Arbitrary Rect where
  arbitrary = Rect
    <$> (getPositive <$> arbitrary)
    <*> (getPositive <$> arbitrary)

  shrink (Rect w h) =
    [Rect w' h | Positive w' <- shrink (Positive w)] ++
    [Rect w h' | Positive h' <- shrink (Positive h)]
```

Если `shrink` не определён, QuickCheck выведет первый найденный контрпример без упрощения.

## Параметр размера

Генераторы в QuickCheck зависят от неявного параметра **размера** (size). По умолчанию QuickCheck постепенно увеличивает размер от 0 до 99 в течение 100 тестов. Это влияет на генерацию:

- `arbitrary @[Int]` генерирует списки длиной до `size`
- `arbitrary @Int` генерирует числа в диапазоне `[-size, size]`

Комбинатор `sized` даёт доступ к текущему размеру:

```haskell
genSmallList :: Gen [Int]
genSmallList = sized $ \n -> do
  k <- choose (0, min n 5)    -- длина не больше 5
  vectorOf k arbitrary
```

А `resize` позволяет переопределить размер:

```haskell
genTinyTree :: Gen (BST Int)
genTinyTree = resize 5 (fromList <$> listOf arbitrary)
```

## Пример: тестирование бинарного дерева поиска

Модуль `Data.BST` предоставляет бинарное дерево поиска с операциями `insert`, `member`, `toAscList`, `fromList` и предикатом `valid`. Проверим несколько свойств:

```haskell
-- Построение дерева из списка всегда даёт валидное дерево:
prop_fromListValid :: [Int] -> Bool
prop_fromListValid xs = valid (fromList xs)

-- toAscList возвращает отсортированный список без дубликатов:
prop_toAscListSorted :: [Int] -> Bool
prop_toAscListSorted xs = sorted (toAscList (fromList xs))

-- Любой элемент из исходного списка находится в дереве:
prop_fromListMember :: [Int] -> Bool
prop_fromListMember xs = all (\x -> member x (fromList xs)) xs
```

Запустим в GHCi:

```text
> quickCheck prop_fromListValid
+++ OK, passed 100 tests.

> quickCheck prop_toAscListSorted
+++ OK, passed 100 tests.
```

Все 100 случайных списков прошли проверку. Но как убедиться, что среди них были и пустые списки, и длинные? Добавим классификацию:

```text
> quickCheck $ \xs -> classify (null xs) "пустой" $ prop_fromListValid xs
+++ OK, passed 100 tests (5% пустой).
```

## Round-trip тестирование

Частый паттерн в property-based тестах — **round-trip**: кодирование и обратное декодирование должны вернуть исходное значение:

```
decode (encode x) ≡ Just x
```

Это универсальное свойство, применимое к JSON-сериализации, парсерам, компрессии и любым парным преобразованиям.

Модуль `Data.Person` предоставляет тип `Person` и функции `encodePerson` / `decodePerson`. Для round-trip теста нужно:

1. Написать генератор `Person`, учитывающий ограничения формата (имя без `';'`).
2. Сформулировать свойство с помощью `forAll`.

```haskell
prop_roundTrip :: Property
prop_roundTrip =
  forAll genPerson $ \p ->
    decodePerson (encodePerson p) == Just p
```

Это мощный паттерн: один round-trip тест заменяет десятки ручных примеров.

## Обзор Hedgehog

**Hedgehog** — альтернативная библиотека для генеративного тестирования в Haskell. Главное отличие — **интегрированный shrinking**: в Hedgehog сжатие встроено в генератор, а не определяется отдельно. Это означает, что если вы написали генератор, сжатие работает автоматически.

```haskell
-- QuickCheck: shrink определяется отдельно
instance Arbitrary MyType where
  arbitrary = ...
  shrink    = ...

-- Hedgehog: shrinking встроен в генератор
genMyType :: Gen MyType
genMyType = do
  x <- Gen.int (Range.linear 0 100)  -- shrinking «бесплатно»
  ...
```

Hedgehog также предоставляет state-machine тестирование для проверки stateful систем. В этой книге мы работаем с QuickCheck, но Hedgehog стоит изучить для продвинутых задач.

## Упражнения

Решения пишите в файле `test/MySolutions.hs`. После каждого упражнения запускайте `stack test`.

1. **(Лёгкое)** Реализуйте три свойства функции `mergeSort` из модуля `Data.MergeSort`:

    - `prop_sortPreservesLength` — сортировка не меняет длину списка.
    - `prop_sortOrdered` — результат сортировки упорядочен (используйте функцию `sorted`).
    - `prop_sortIdempotent` — повторная сортировка не меняет результат.

    Каждое свойство имеет тип `[Int] -> Bool`.

    *Подсказка:* свойство — это обычная функция. Например:

    ```haskell
    prop_sortPreservesLength xs = length (mergeSort xs) == length xs
    ```

2. **(Среднее)** Напишите генератор `genBST :: Gen (BST Int)` для бинарного дерева поиска и два свойства:

    - `prop_genBSTValid` — все сгенерированные деревья удовлетворяют инварианту BST (используйте `valid` из `Data.BST`).
    - `prop_insertMember` — после `insert x` элемент `x` находится в дереве (используйте `member`).

    Оба свойства должны иметь тип `Property` и использовать `forAll` для подключения генератора.

    *Подсказка:* самый простой генератор BST — `fromList <$> listOf arbitrary`. Для `prop_insertMember` вам понадобится вложенный `forAll`:

    ```haskell
    forAll genBST $ \bst ->
      forAll arbitrary $ \x ->
        ...
    ```

3. **(Среднее)** Напишите генератор `genPerson :: Gen Person` и свойство round-trip:

    - `genPerson` — генератор `Person`. Имя должно состоять из допустимых символов (без `';'`). Используйте `listOf` и `elements` для генерации имени, `chooseInt` для возраста.
    - `prop_encodeDecodeRoundTrip` — свойство `decodePerson (encodePerson p) == Just p`.

    Оба используют `forAll` для связи генератора со свойством.

4. **(Продвинутое)** Напишите свойство `prop_mergeOrdered :: Property`, проверяющее, что функция `merge` из `Data.MergeSort` при слиянии двух отсортированных списков даёт отсортированный результат.

    Требования:
    - Используйте `forAll` с генератором отсортированного списка (подсказка: `sort <$> listOf arbitrary`).
    - Добавьте `classify` для отслеживания распределения:
      - `"один список пуст"` — хотя бы один из входных списков пуст.
      - `"большой вход"` — суммарная длина списков больше 20.

## Заключение

В этой главе мы:

- Познакомились с генеративным тестированием и библиотекой QuickCheck.
- Научились формулировать свойства: `Bool`, `Property`, `(==>)`, `classify`, `cover`.
- Изучили монаду `Gen` и комбинаторы для построения генераторов.
- Разобрали класс `Arbitrary` и механизм shrinking.
- Использовали `forAll` для подключения пользовательских генераторов.
- Познакомились с паттерном round-trip тестирования.

Генеративное тестирование — один из самых мощных инструментов в арсенале Haskell-разработчика. Один хорошо сформулированный property-тест может заменить десятки юнит-тестов, находя граничные случаи, о которых вы даже не задумывались.
