# Линзы и оптики

## Цели главы

В этой главе мы познакомимся с *линзами* — элегантным инструментом для работы с вложенными структурами данных. Мы освоим библиотеку `lens`, разберём линзы, призмы и traversals, а также реализуем собственные линзы через кодировку ван Лаарховена.

## Проблема: обновление вложенных записей

Представим вложенные записи:

```haskell
data Address = Address { _city :: String, _street :: String, _zipCode :: String }
data Person  = Person  { _personName :: String, _personAge :: Int, _personAddress :: Address }
```

Чтобы изменить город у персоны, нужно написать:

```haskell
setCity :: String -> Person -> Person
setCity newCity person = person
  { _personAddress = (_personAddress person)
    { _city = newCity }
  }
```

Один уровень вложенности — и уже неуклюже. С каждым уровнем — экспоненциальный рост шаблонного кода:

```haskell
-- Три уровня вложенности:
company { _hq = (_hq company) { _address = (_address (_hq company)) { _city = "Москва" } } }
```

Линзы решают эту проблему.

## Что такое линза

*Линза* фокусирует взгляд на части структуры. Три базовые операции:

```haskell
view :: Lens' s a -> s -> a          -- прочитать поле
set  :: Lens' s a -> a -> s -> s     -- установить значение
over :: Lens' s a -> (a -> a) -> s -> s  -- модифицировать функцией
```

`Lens' s a` — тип линзы, фокусирующей структуру `s` на поле типа `a`.

## Библиотека `lens`

### Генерация линз: `makeLenses`

Библиотека `lens` автоматически генерирует линзы по именам полей. Соглашение: поля начинаются с `_`, а линзы получают имя без подчёркивания:

```haskell
import Control.Lens.TH (makeLenses)

data Address = Address
  { _city   :: String
  , _street :: String
  , _zipCode :: String
  } deriving stock (Show, Eq)

makeLenses ''Address
-- Генерирует:
--   city    :: Lens' Address String
--   street  :: Lens' Address String
--   zipCode :: Lens' Address String
```

`makeLenses` использует Template Haskell (`''Address` — имя типа на этапе компиляции).

### Использование: `view`, `set`, `over`

```text
> let addr = Address "Москва" "Тверская" "101000"

> view city addr
"Москва"

> set city "Казань" addr
Address {_city = "Казань", _street = "Тверская", _zipCode = "101000"}

> over city (map toUpper) addr
Address {_city = "МОСКВА", _street = "Тверская", _zipCode = "101000"}
```

### Операторы

Для более компактного кода `lens` предоставляет операторы:

```haskell
(^.)  -- view:  addr ^. city           ≡ view city addr
(.~)  -- set:   addr & city .~ "Казань" ≡ set city "Казань" addr
(%~)  -- over:  addr & city %~ map toUpper ≡ over city (map toUpper) addr
(&)   -- применение: x & f ≡ f x  (из Data.Function)
```

```text
> addr ^. city
"Москва"

> addr & city .~ "Казань"
Address {_city = "Казань", ...}

> addr & city %~ map toUpper
Address {_city = "МОСКВА", ...}
```

## Композиция линз

Ключевое свойство: линзы компонуются через стандартную композицию функций `(.)`:

```haskell
personAddress :: Lens' Person Address
city          :: Lens' Address String

personAddress . city :: Lens' Person String
```

Теперь обновление города — одна строка:

```text
> let person = Person "Иван" 30 (Address "Москва" "Тверская" "101000")

> person ^. personAddress . city
"Москва"

> person & personAddress . city .~ "Казань"
Person {_personName = "Иван", _personAge = 30,
        _personAddress = Address {_city = "Казань", ...}}
```

Сравните с ручным обновлением в начале главы — разница разительная.

## Призмы (Prisms) — линзы для сумм

Линзы работают с произведениями (записями). Для сумм (`Either`, `Maybe`, пользовательские АТД) есть **призмы**:

```haskell
_Just    :: Prism' (Maybe a) a
_Nothing :: Prism' (Maybe a) ()
_Left    :: Prism' (Either a b) a
_Right   :: Prism' (Either a b) b
```

`preview` пытается извлечь значение (возвращает `Maybe`):

```text
> preview _Just (Just 42)
Just 42

> preview _Just Nothing
Nothing

> preview _Right (Right 5 :: Either String Int)
Just 5

> preview _Left (Right 5 :: Either String Int)
Nothing
```

Призмы также компонуются с линзами и traversals.

## Traversals — обход коллекций

**Traversal** — обобщение линзы на *несколько* фокусов. `traversed` фокусирует каждый элемент `Traversable`-контейнера:

```text
> [1, 2, 3] & traversed %~ (* 10)
[10,20,30]

> [1, 2, 3] ^.. traversed
[1,2,3]
```

Оператор `(^..)` (он же `toListOf`) собирает все значения в список.

### Составные traversals

Traversals компонуются с линзами, создавая мощные запросы:

```haskell
data Employee   = Employee   { _employeeName :: String, _employeeSalary :: Double }
data Department = Department { _departmentName :: String, _departmentEmployees :: [Employee] }
data Company    = Company    { _companyName :: String, _companyDepartments :: [Department] }
```

Повысить зарплату *всех* сотрудников *всех* отделов на 10000:

```haskell
raiseSalary :: Double -> Company -> Company
raiseSalary amount = over
  (companyDepartments . traversed . departmentEmployees . traversed . employeeSalary)
  (+ amount)
```

Одна строка вместо двух вложенных `map`:

```haskell
-- Без линз:
raiseSalary amount c = c
  { _companyDepartments = map (\d -> d
    { _departmentEmployees = map (\e -> e
      { _employeeSalary = _employeeSalary e + amount })
      (_departmentEmployees d) })
    (_companyDepartments c) }
```

### Извлечение с traversals и призмами

Можно комбинировать `traversed` с призмами:

```haskell
rightValues :: [Either String Int] -> [Int]
rightValues = toListOf (traversed . _Right)
```

```text
> rightValues [Left "ошибка", Right 1, Left "ещё", Right 2]
[1,2]
```

## Когда использовать линзы

| Ситуация | Рекомендация |
|----------|-------------|
| Маленький проект, плоские записи | Обычные функции обновления |
| Глубоко вложенные структуры | Линзы |
| JSON, конфигурации, AST | Линзы + призмы |
| Массовые обновления коллекций | Traversals |

Альтернативы:
- `OverloadedRecordDot` (GHC 9.2+) — удобный доступ к полям (`person.address.city`), но только чтение.
- `microlens` — легковесная альтернатива `lens` без Template Haskell и призм.

## Как линзы работают: кодировка ван Лаарховена

Линза — это обычная функция:

```haskell
type Lens' s a = forall f. Functor f => (a -> f a) -> s -> f s
```

Это выглядит загадочно, но работает благодаря выбору `f`:

- `f = Identity` → получаем `over` (модификация):

    ```haskell
    myOver :: Lens' s a -> (a -> a) -> s -> s
    myOver l f s = runIdentity (l (Identity . f) s)
    ```

- `f = Const a` → получаем `view` (чтение):

    ```haskell
    myView :: Lens' s a -> s -> a
    myView l s = getConst (l Const s)
    ```

Композиция через `(.)` работает, потому что линза — это просто функция! `(l1 . l2)` — стандартная композиция функций.

Вручную линза для первого элемента пары:

```haskell
fstL :: Lens' (a, b) a
fstL f (a, b) = (\a' -> (a', b)) <$> f a
```

Логика: применить `f` к фокусу `a`, получить `f a'`, затем собрать обратно в пару через `<$>`.

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

Модуль `Data.Company` предоставляет типы `Company`, `Department`, `Employee` с линзами (`companyDepartments`, `departmentEmployees`, `employeeSalary` и др.) и `exampleCompany`.

Типы `Address` и `Person` с вызовами `makeLenses` уже определены в `MySolutions.hs`.

1. **(Лёгкое)** Реализуйте функции через `view`, `set`, `over` и композицию линз:

    ```haskell
    getCity   :: Person -> String          -- view через personAddress . city
    setCity   :: String -> Person -> Person -- set через personAddress . city
    upperName :: Person -> Person          -- over personName (map toUpper)
    ```

2. **(Среднее)** Реализуйте функцию, повышающую зарплату всех сотрудников компании:

    ```haskell
    raiseSalary :: Double -> Company -> Company
    ```

    *Подсказка:* используйте `over` с путём `companyDepartments . traversed . departmentEmployees . traversed . employeeSalary`.

3. **(Среднее)** Используя `toListOf`, `traversed` и `_Right`, извлеките все `Right`-значения:

    ```haskell
    rightValues :: [Either String Int] -> [Int]
    ```

4. **(Продвинутое)** Реализуйте собственную кодировку линз ван Лаарховена:

    ```haskell
    type MyLens s a = forall f. Functor f => (a -> f a) -> s -> f s

    myView :: MyLens s a -> s -> a        -- через Const
    myOver :: MyLens s a -> (a -> a) -> s -> s  -- через Identity
    mySet  :: MyLens s a -> a -> s -> s   -- через myOver

    fstL :: MyLens (a, b) a   -- линза для первого элемента пары
    sndL :: MyLens (a, b) b   -- линза для второго элемента пары
    ```

    Проверьте, что `sndL . fstL` корректно фокусирует вложенное поле.

## Заключение

В этой главе мы:

- Увидели проблему обновления вложенных записей и мотивацию для линз.
- Освоили библиотеку `lens`: `makeLenses`, `view`, `set`, `over` и операторы.
- Разобрали композицию линз через стандартную `(.)`.
- Познакомились с призмами для сумм и traversals для коллекций.
- Реализовали собственные линзы через кодировку ван Лаарховена.

В следующей главе мы создадим полноценное веб-приложение с базой данных.
