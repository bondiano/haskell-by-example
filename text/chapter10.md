# Тестирование: hspec и QuickCheck

К этому моменту у нас есть полноценный CLI-трекер задач: типы данных, чистые функции, IO-операции, обработка ошибок, `Map`, `Text`. Но откуда мы знаем, что код работает правильно? Пора писать тесты. Эта глава посвящена двум фреймворкам: **hspec** для тестов на примерах (unit-тестирование) и **QuickCheck** для тестов на свойствах (property-based testing). Мы разберём генераторы, класс `Arbitrary`, автоматическую минимизацию контрпримеров (shrinking) и интеграцию обоих подходов.

## Подготовка проекта

Код этой главы находится в `exercises/chapter10`. Соберите проект:

```text
$ cd exercises/chapter10
$ stack build
```

В `package.yaml` зависимости от `hspec` и `QuickCheck` уже добавлены:

```yaml
tests:
  chapter10-test:
    dependencies:
      - hspec
      - QuickCheck
      - hspec-discover
```

## Зачем тестировать

Чистые функции — идеальные кандидаты для тестирования. У них нет побочных эффектов: одни и те же аргументы всегда дают один и тот же результат. Тесты — просто сравнение «вызвал функцию — проверил результат».

Но даже для чистых функций легко допустить ошибку: пропустить граничный случай (пустой список, отрицательный индекс), перепутать порядок аргументов, забыть обработать `Nothing`. Тесты ловят такие ошибки автоматически.

Два подхода дополняют друг друга:

- **Тесты на примерах** (hspec): конкретные входные данные, конкретные результаты. Хорошо документируют ожидаемое поведение.
- **Тесты на свойствах** (QuickCheck): *общие* закономерности, сотни случайных примеров. Находят краевые случаи, о которых вы не подумали.

## hspec: тесты на примерах

В [главе 1](chapter01.md) мы уже запускали тесты через `stack test`. Теперь разберём hspec подробнее.

### Структура теста

```haskell
import Test.Hspec

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "showPriority" $ do
    it "returns Низкий for Low" $
      showPriority Low `shouldBe` "Низкий"

    it "returns Высокий for High" $
      showPriority High `shouldBe` "Высокий"
```

- `describe` — группирует тесты по теме (обычно имя функции).
- `it` — описывает конкретное ожидание на естественном языке.
- `shouldBe` — утверждение: «результат должен быть равен ...».

Ключевое слово `do` здесь — просто синтаксис для последовательной записи, без погружения в теорию.

```admonish tip title="Знакомый аналог"
**JavaScript:** hspec ~ Jest/Mocha (`describe`, `it`, `expect(...).toBe(...)`).
**Python:** hspec ~ pytest (функции с assert) или unittest (`TestCase`, `assertEqual`).
Синтаксис hspec намеренно близок к RSpec/Jest.
```

### Основные утверждения

```haskell
-- Равенство
result `shouldBe` expected

-- Предикат
task `shouldSatisfy` isUrgent

-- IO-действие: проверка возвращаемого значения
readFile "test.txt" `shouldReturn` "содержимое"

-- IO-действие: ожидание исключения
evaluate (head []) `shouldThrow` anyException
```

`shouldReturn` выполняет IO-действие и сравнивает результат с ожидаемым значением. `shouldThrow` проверяет, что действие выбрасывает исключение.

### Вложенные describe и pending

```haskell
spec :: Spec
spec = do
  describe "TaskStore" $ do
    describe "addTask" $ do
      it "adds a task to empty store" $
        let store = addTask (TaskId 1) sampleTask emptyStore
        in Map.size (unTaskStore store) `shouldBe` 1

      it "preserves existing tasks" $
        let store = addTask (TaskId 1) task1
                  $ addTask (TaskId 2) task2 emptyStore
        in Map.size (unTaskStore store) `shouldBe` 2

    describe "removeTask" $ do
      it "removes existing task" $ pending
      it "does nothing for missing id" $
        pendingWith "нужен генератор TaskId"
```

Тест с `pending` не падает — он отображается как «ожидающий» в отчёте. Удобно для планирования.

### beforeAll, afterAll и --match

Для тестов, которым нужна подготовка, используйте `beforeAll` и `afterAll`:

```haskell
spec :: Spec
spec = beforeAll setup $ afterAll cleanup $ do
  it "reads saved tasks" $ \filePath -> do
    contents <- readFile filePath
    contents `shouldSatisfy` (not . null)
  where
    setup = do
      let path = "/tmp/test-tasks.txt"
      writeFile path "sample data"
      pure path
    cleanup = removeFile
```

Чтобы запускать только нужные тесты:

```text
$ stack test --test-arguments="--match addTask"
```

## QuickCheck: тесты на свойствах

QuickCheck предлагает другой подход: вместо перечисления примеров вы описываете **свойство**, которое должно выполняться *для любых* входных данных. Фреймворк сам генерирует сотни случайных примеров и проверяет свойство на каждом.

```admonish note title="Историческая справка"
QuickCheck был создан в 2000 году Класом Клаэссоном и Джоном Хьюзом специально для Haskell. С тех пор идею переняли десятки языков: fast-check (JavaScript), Hypothesis (Python), proptest (Rust), ScalaCheck и другие. Все — потомки оригинального QuickCheck.
```

### От примеров к свойствам

Рассмотрим функцию `reverse`. Тесты на примерах проверяют конкретные случаи:

```haskell
it "reverses [1,2,3]" $
  reverse [1,2,3] `shouldBe` [3,2,1]
```

А вот **свойства** `reverse` — общие закономерности:

```haskell
-- Двойной reverse возвращает исходный список
prop_reverseReverse :: [Int] -> Bool
prop_reverseReverse xs = reverse (reverse xs) == xs

-- reverse сохраняет длину
prop_reverseLength :: [Int] -> Bool
prop_reverseLength xs = length (reverse xs) == length xs
```

Каждое свойство — обычная функция, принимающая произвольные данные и возвращающая `Bool`. Имя по конвенции начинается с `prop_`.

### Запуск QuickCheck

```haskell
import Test.QuickCheck

main :: IO ()
main = do
  quickCheck prop_reverseReverse
  quickCheck prop_reverseLength
```

```text
+++ OK, passed 100 tests.
+++ OK, passed 100 tests.
```

Если свойство нарушается, QuickCheck покажет контрпример:

```haskell
prop_wrong :: [Int] -> Bool
prop_wrong xs = reverse xs == xs
```

```text
*** Failed! Falsifiable (after 4 tests and 3 shrinks):
[0,1]
```

QuickCheck нашёл минимальный контрпример `[0,1]` — список, для которого `reverse xs /= xs`.

### Условные свойства: (==>)

Иногда свойство выполняется не для всех данных. Оператор `(==>)` задаёт предусловие:

```haskell
prop_headReverse :: [Int] -> Property
prop_headReverse xs =
  not (null xs) ==> head (reverse xs) == last xs
```

Если предусловие не выполняется, QuickCheck пропускает тест. Если слишком много тестов отброшено, QuickCheck предупредит.

```admonish tip title="Знакомый аналог"
**JavaScript:** QuickCheck ~ fast-check (`fc.property`, `fc.assert`).
**Python:** QuickCheck ~ Hypothesis (`@given`, `assume`).
**Rust:** QuickCheck ~ proptest (`proptest!` макрос).
Все вдохновлены оригинальным Haskell QuickCheck.
```

## Генераторы и Arbitrary

Откуда QuickCheck берёт случайные данные? За это отвечает класс типов `Arbitrary` и тип `Gen`.

```haskell
class Arbitrary a where
  arbitrary :: Gen a
  shrink :: a -> [a]
```

`Gen a` — генератор случайных значений типа `a`. Для стандартных типов (`Int`, `Bool`, `[a]`, `String`) экземпляры `Arbitrary` уже определены.

### Базовые генераторы

```haskell
-- Случайное число в диапазоне
chooseInt :: (Int, Int) -> Gen Int

-- Случайный элемент из списка
elements :: [a] -> Gen a

-- Один из нескольких генераторов
oneof :: [Gen a] -> Gen a

-- Список случайной длины
listOf :: Gen a -> Gen [a]

-- Список заданной длины
vectorOf :: Int -> Gen a -> Gen [a]
```

### Пользовательские экземпляры Arbitrary

Для наших типов экземпляры нужно написать самостоятельно:

```haskell
instance Arbitrary Priority where
  arbitrary = elements [Low, Medium, High]

instance Arbitrary Status where
  arbitrary = elements [Todo, InProgress, Done]
```

Для `Task` скомбинируем генераторы с помощью `<$>` и `<*>`:

```haskell
instance Arbitrary Task where
  arbitrary = Task
    <$> genTitle       -- taskTitle
    <*> genDescription -- taskDescription
    <*> arbitrary      -- taskPriority
    <*> arbitrary      -- taskStatus
    where
      genTitle = elements
        [ "Купить молоко", "Написать тесты", "Рефакторинг"
        , "Исправить баг", "Обновить зависимости" ]
      genDescription = elements ["", "Подробности позже", "Срочно"]
```

Читайте `<$>` как «применить функцию к результату генератора», а `<*>` как «и ещё один аргумент из генератора». Подробнее об этих операторах — в [главе 11](chapter11.md).

Для `TaskId`:

```haskell
instance Arbitrary TaskId where
  arbitrary = TaskId <$> chooseInt (1, 1000)
```

## Shrinking — минимизация контрпримеров

Когда QuickCheck находит данные, нарушающие свойство, он пытается **уменьшить** контрпример до минимального, сохраняя нарушение. Для списка `[5, -3, 12, 0, -7]` QuickCheck попробует удалить элементы, уменьшить их значения, и так далее — пока не получит минимальный пример вроде `[0, 1]`.

### Определение shrink для своих типов

```haskell
instance Arbitrary Priority where
  arbitrary = elements [Low, Medium, High]
  shrink High   = [Medium, Low]
  shrink Medium = [Low]
  shrink Low    = []

instance Arbitrary Task where
  arbitrary = Task
    <$> elements ["Задача A", "Задача B", "Задача C"]
    <*> pure ""
    <*> arbitrary
    <*> arbitrary
  shrink Task{..} =
    [ Task t d p s
    | (t, d, p, s) <- shrink (taskTitle, taskDescription, taskPriority, taskStatus)
    ]
```

Для `Task` мы делегируем shrinking кортежу полей — QuickCheck автоматически попробует уменьшить каждое поле.

## hspec + QuickCheck вместе

Лучший подход — объединить оба стиля в одном файле тестов. hspec поддерживает QuickCheck через функцию `prop`:

```haskell
import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck

spec :: Spec
spec = do
  describe "reverse" $ do
    -- Тесты на примерах
    it "reverses [1,2,3] to [3,2,1]" $
      reverse [1,2,3 :: Int] `shouldBe` [3,2,1]

    -- Тесты на свойствах
    prop "double reverse is identity" $
      \(xs :: [Int]) -> reverse (reverse xs) == xs

    prop "preserves length" $
      \(xs :: [Int]) -> length (reverse xs) == length xs
```

Функция `prop` из `Test.Hspec.QuickCheck` — сокращение для `it "..." $ property (...)`. Оператор `===` (тройное равно) — аналог `==`, но при ошибке показывает оба значения:

```haskell
it "double reverse is identity" $ property $
  \(xs :: [Int]) -> reverse (reverse xs) === xs
```

````admonish warning title="Проверяйте распределение тестовых данных"
QuickCheck может генерировать *нерепрезентативные* данные. Используйте `classify` и `cover`, чтобы убедиться, что тесты покрывают интересные случаи:

```haskell
prop_filterSubset :: TaskFilter -> [Task] -> Property
prop_filterSubset f tasks =
  classify (null tasks) "empty list" $
  classify (length tasks > 10) "long list" $
  property $ all (`elem` tasks) (filterTasks f tasks)
```

```text
+++ OK, passed 100 tests:
12% empty list
 8% long list
80% other
```

`cover` строже: он *требует* определённый процент каждого класса. Если процент не достигнут, тест считается непройденным.
````

## Тестируем трекер задач

Соберём всё вместе — полноценный набор тестов для трекера, сочетающий примеры и свойства:

```haskell
module Main where

import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck
import qualified Data.Map.Strict as Map

import TaskTracker.Types
import TaskTracker.Store
import TaskTracker.Filter

main :: IO ()
main = hspec spec

sampleTask :: Task
sampleTask = Task "Тестовая задача" "" Medium Todo

emptyStore :: TaskStore
emptyStore = TaskStore Map.empty

spec :: Spec
spec = do
  describe "TaskStore" $ do
    describe "addTask" $ do
      it "adds a task to empty store" $
        let store = addTask (TaskId 1) sampleTask emptyStore
        in Map.size (unTaskStore store) `shouldBe` 1

      it "preserves existing tasks" $
        let store = addTask (TaskId 1) sampleTask
                  $ addTask (TaskId 2) sampleTask emptyStore
        in Map.size (unTaskStore store) `shouldBe` 2

      prop "size increases by 1 for new key" $
        \(tid :: TaskId) (task :: Task) ->
          let store' = addTask tid task emptyStore
          in Map.size (unTaskStore store') === 1

    describe "removeTask" $ do
      it "removes existing task" $
        let store = addTask (TaskId 1) sampleTask emptyStore
            store' = removeTask (TaskId 1) store
        in Map.size (unTaskStore store') `shouldBe` 0

      it "does nothing for missing id" $
        let store = addTask (TaskId 1) sampleTask emptyStore
            store' = removeTask (TaskId 99) store
        in Map.size (unTaskStore store') `shouldBe` 1

  describe "filterTasks" $ do
    it "ByStatus Done returns only done tasks" $
      let tasks = [sampleTask, sampleTask { taskStatus = Done }]
      in length (filterTasks (ByStatus Done) tasks) `shouldBe` 1

    prop "AllTasks returns all tasks" $
      \(tasks :: [Task]) ->
        filterTasks AllTasks tasks === tasks

    prop "result is always a subset of input" $
      \(f :: TaskFilter) (tasks :: [Task]) ->
        all (`elem` tasks) (filterTasks f tasks)

  describe "computeStats" $ do
    prop "totalTasks equals list length" $
      \(tasks :: [Task]) ->
        totalTasks (computeStats tasks) === length tasks

    prop "counts are non-negative" $
      \(tasks :: [Task]) ->
        let stats = computeStats tasks
        in conjoin
          [ todoCount stats >= 0
          , doneCount stats >= 0
          , highPriority stats >= 0
          ]
```

Тесты на примерах проверяют конкретные сценарии (пустое хранилище, удаление несуществующего ключа). Свойства проверяют общие инварианты (размер растёт, результат фильтрации — подмножество входа). `conjoin` из QuickCheck объединяет несколько проверок в одно свойство.

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

### Проект ★☆☆

1. Напишите hspec-тесты для функции `addTask`: проверьте, что после добавления задачи она находится по своему `TaskId`, и что размер хранилища увеличивается на 1.

    ```haskell
    addTaskSpec :: Spec
    ```

2. Напишите hspec-тесты для функции `filterTasks`: проверьте фильтрацию по `ByStatus`, `ByPriority` и `AllTasks` на конкретных примерах (минимум 3 теста).

    ```haskell
    filterTasksSpec :: Spec
    ```

### Проект ★★☆

3. Напишите QuickCheck-свойства для трекера задач:
    - `addTask` с новым ключом увеличивает размер хранилища на 1.
    - `removeTask` после `addTask` с тем же ключом возвращает исходное хранилище.
    - `filterTasks` с `AllTasks` всегда возвращает исходный список.

    ```haskell
    trackerProperties :: Spec
    ```

    *Подсказка:* для первого свойства используйте `(==>)`, чтобы ключ не существовал в хранилище.

### Практика ★☆☆

4. Напишите hspec-тесты для функции `reverse`: проверьте на пустом списке, одноэлементном и многоэлементном списке.

    ```haskell
    reverseSpec :: Spec
    ```

5. Напишите hspec-тесты для `Data.Map.lookup`: проверьте поиск существующего ключа, несуществующего ключа и поиск в пустом `Map`.

    ```haskell
    lookupSpec :: Spec
    ```

### Практика ★★☆

6. Напишите экземпляр `Arbitrary` для типа `TaskFilter` и QuickCheck-свойство: результат `filterTasks f tasks` всегда подсписок `tasks`.

    ```haskell
    instance Arbitrary TaskFilter where
      arbitrary = undefined -- ваша реализация

    prop_filterSubset :: TaskFilter -> [Task] -> Bool
    ```

    *Подсказка:* используйте `oneof` для генерации разных конструкторов `TaskFilter`.

7. Напишите QuickCheck-свойства для сортировки: `sort xs` отсортирован, и `sort . sort == sort` (идемпотентность).

    ```haskell
    prop_sortOrdered :: [Int] -> Bool
    prop_sortIdempotent :: [Int] -> Bool
    ```

    *Подсказка:* напишите `isSorted :: Ord a => [a] -> Bool` через `zip xs (drop 1 xs)`.

## Заключение

Эта глава завершает **Часть II** книги. Путь от базовых типов до IO, обработки ошибок, ленивости и тестирования пройден. Теперь в арсенале есть всё для написания надёжных программ: hspec для проверки конкретных сценариев (`describe`, `it`, `shouldBe`, `shouldReturn`, `shouldThrow`), QuickCheck для проверки общих инвариантов (`quickCheck`, `property`, `==>`), генераторы (`Gen`, `choose`, `elements`, `oneof`), пользовательские экземпляры `Arbitrary`, автоматический shrinking и интеграция обоих подходов через `prop`.

В [Части III](chapter11.md) мы перейдём к абстракциям: `Functor`, `Applicative` и монады. Эти концепции формализуют паттерны, которые мы уже встречали (например, `<$>` и `<*>` из генераторов QuickCheck — это именно `Functor` и `Applicative`). Тесты, которые мы научились писать, помогут проверять код на каждом шаге.

```admonish tip title="Для углубления"
- **Haskell MOOC** — [haskell.mooc.fi](https://haskell.mooc.fi/), лекция 16: property-based testing и QuickCheck.
- **QuickCheck manual** — [hackage.haskell.org/package/QuickCheck](https://hackage.haskell.org/package/QuickCheck) — документация и примеры.
- **hspec user's guide** — [hspec.github.io](https://hspec.github.io/) — полное руководство по hspec.
```
