# Продвинутые паттерны

## Цели главы

В этой главе мы разберём три мощных паттерна для построения расширяемых, интерпретируемых DSL:

- **Recursion Schemes** — обобщение `fold`/`unfold` для произвольных рекурсивных структур.
- **Free Monad** — AST для эффектов: «программы как данные».
- **Tagless Final** — полиморфные программы, интерпретируемые «на лету».

Все три — разные взгляды на одну задачу: как описать вычисление, отделив его *структуру* от *интерпретации*.

## Recursion Schemes

### Мотивация

В главе 5 мы использовали `foldr` — свёртку для списков. Но как свернуть *дерево*? *Граф*? Произвольный рекурсивный тип? Recursion schemes — обобщение `fold` и `unfold` на любую рекурсивную структуру.

### Fix и Base Functor

Ключевая идея: отделить рекурсию от структуры. Вместо рекурсивного типа:

```haskell
data Expr = Lit Int | Add Expr Expr | Mul Expr Expr
```

Определяем **base functor** — тот же тип, но параметризованный по рекурсивной позиции:

```haskell
data ExprF r = LitF Int | AddF r r | MulF r r
  deriving Functor
```

`ExprF` — «один слой» выражения. `r` — заглушка для рекурсии. Рекурсию восстанавливает **Fix**:

```haskell
newtype Fix f = Fix { unFix :: f (Fix f) }

type Expr = Fix ExprF
-- Fix ExprF ≅ ExprF (Fix ExprF) ≅ ExprF (ExprF (Fix ExprF)) ≅ ...
```

Теперь рекурсия — в `Fix`, а структура — в `ExprF`. Это позволяет определять обходы *один раз* для любого base functor.

### Catamorphism (cata) — обобщённая свёртка

**Catamorphism** — рекурсивная свёртка: «схлопнуть» структуру снизу вверх, заменяя каждый `Fix` на результат:

```haskell
cata :: Functor f => (f a -> a) -> Fix f -> a
cata alg = alg . fmap (cata alg) . unFix
```

Функция `alg :: f a -> a` называется **алгеброй** — она задаёт, как обработать один слой.

```haskell
eval :: Expr -> Int
eval = cata alg
  where
    alg (LitF n)   = n
    alg (AddF x y) = x + y
    alg (MulF x y) = x * y
```

Сравните с `foldr` для списков: `foldr f z` заменяет `(:)` на `f` и `[]` на `z`. Catamorphism делает то же самое для произвольных рекурсивных типов.

```admonish info title="Знакомый аналог"
**TypeScript:** `Array.prototype.reduce` — catamorphism для массивов.
Recursion schemes — обобщение на *любую* рекурсивную структуру (деревья, графы, AST).
```

### Anamorphism (ana) — обобщённая развёртка

**Anamorphism** — обратная операция: «развернуть» значение в структуру сверху вниз:

```haskell
ana :: Functor f => (a -> f a) -> a -> Fix f
ana coalg = Fix . fmap (ana coalg) . coalg
```

Функция `coalg :: a -> f a` — **коалгебра**: из затравки порождает один слой.

```haskell
-- Последовательность Коллатца как список
data ListF a r = NilF | ConsF a r deriving Functor

collatz :: Int -> Fix (ListF Int)
collatz = ana coalg
  where
    coalg 1 = ConsF 1 NilF  -- остановка (через Fix это обходится иначе)
    coalg n
      | even n    = ConsF n (n `div` 2)
      | otherwise = ConsF n (3 * n + 1)
```

### Hylomorphism (hylo) — ana + cata

**Hylomorphism** — развёртка, за которой сразу следует свёртка. Промежуточная структура *не аллоцируется* благодаря fusion:

```haskell
hylo :: Functor f => (f b -> b) -> (a -> f a) -> a -> b
hylo alg coalg = alg . fmap (hylo alg coalg) . coalg
```

Классический пример — merge sort:

```haskell
-- Развернуть список в дерево разбиений, затем свернуть, сливая:
mergeSort :: Ord a => [a] -> [a]
mergeSort = hylo merge split
```

Промежуточное дерево существует только концептуально — GHC оптимизирует его до прямого рекурсивного вызова.

### Paramorphism (para) — свёртка с доступом к оригиналу

```haskell
para :: Functor f => (f (Fix f, a) -> a) -> Fix f -> a
```

`para` — как `cata`, но алгебра на каждом шаге получает *и* результат, *и* исходное поддерево. Это нужно для функций, которым надо «заглянуть» в оригинал:

```haskell
-- tails [1,2,3] = [[1,2,3], [2,3], [3], []]
-- para даёт доступ к оригинальному хвосту на каждом шаге
```

```admonish warning title="Кривая обучения"
Recursion schemes требуют привыкания. Начните с `cata` — это просто `foldr` для деревьев.
Остальные схемы — вариации на ту же тему.
```

## Free Monad

### Мотивация

Как описать *программу* как *данные*, чтобы потом интерпретировать по-разному? Например: один и тот же DSL для key-value хранилища, но с двумя интерпретаторами — один для `Map`, другой для логирования.

### Определение

```haskell
data Free f a
  = Pure a                  -- «вычисление завершено, результат — a»
  | Free (f (Free f a))    -- «одна инструкция f, продолжение — Free f a»
```

`Free f` — это `Fix f` с листьями-значениями (`Pure`). Если `f` — `Functor`, то `Free f` — `Monad`:

```haskell
instance Functor f => Monad (Free f) where
  Pure a >>= k = k a
  Free f >>= k = Free (fmap (>>= k) f)
```

### Паттерн: Functor → Smart Constructors → Программа → Интерпретатор

**Шаг 1: Functor** — набор инструкций DSL:

```haskell
data KVStoreF a
  = Put String String a          -- записать ключ-значение, продолжить
  | Get String (Maybe String -> a) -- прочитать ключ, передать результат дальше
  | Delete String a               -- удалить ключ, продолжить
  deriving Functor

type KVStore = Free KVStoreF
```

**Шаг 2: Smart constructors** — удобный API:

```haskell
put :: String -> String -> KVStore ()
put k v = liftF (Put k v ())

get :: String -> KVStore (Maybe String)
get k = liftF (Get k id)

delete :: String -> KVStore ()
delete k = liftF (Delete k ())
```

**Шаг 3: Программа** — описание через do-нотацию:

```haskell
program :: KVStore (Maybe String)
program = do
  put "name" "Alice"
  put "name" "Bob"     -- перезаписывает
  get "name"            -- Just "Bob"
```

`program` — это *данные*: дерево инструкций, не выполненное вычисление.

**Шаг 4: Интерпретатор** — рекурсивный обход дерева:

```haskell
-- Интерпретатор через Map
runWithMap :: KVStore a -> Map String String -> (a, Map String String)
runWithMap (Pure a) store = (a, store)
runWithMap (Free (Put k v next)) store =
  runWithMap next (Map.insert k v store)
runWithMap (Free (Get k next)) store =
  runWithMap (next (Map.lookup k store)) store
runWithMap (Free (Delete k next)) store =
  runWithMap next (Map.delete k store)

-- Интерпретатор с логированием
runWithLogging :: KVStore a -> IO a
runWithLogging (Pure a) = pure a
runWithLogging (Free (Put k v next)) = do
  putStrLn $ "PUT " <> k <> " = " <> v
  runWithLogging next
runWithLogging (Free (Get k next)) = do
  putStrLn $ "GET " <> k
  runWithLogging (next Nothing)  -- упрощённо
runWithLogging (Free (Delete k next)) = do
  putStrLn $ "DELETE " <> k
  runWithLogging next
```

Одна программа — два интерпретатора. Тестирование — без IO.

```admonish info title="Знакомый аналог"
**TypeScript:** `Effect.gen` в [Effect-TS](https://effect.website/) — аналог Free monad.
Та же идея: описать эффекты как данные, интерпретировать отдельно.

**Python:** Нет прямого аналога. Ближайшее — dependency injection через protocols,
но без composability уровня Free.
```

```admonish note title="Связь с Recursion Schemes"
`Free f a` = `Fix f` + листья-значения. `iterM` из библиотеки `free` —
это catamorphism. Free monad — recursion schemes для эффектов.
```

## Tagless Final

### Мотивация

Free monad строит AST, потом интерпретирует. А что если интерпретировать *на лету*, без промежуточного представления? Tagless final — подход, где программы *полиморфны по интерпретатору*.

### Определение через type classes

```haskell
class ExprSym repr where
  lit :: Int -> repr
  add :: repr -> repr -> repr
  neg :: repr -> repr
```

Type class — *алгебра* DSL. Instance — *интерпретатор*:

```haskell
-- Интерпретатор: вычисление
newtype Eval = Eval { runEval :: Int }

instance ExprSym Eval where
  lit n   = Eval n
  add x y = Eval (runEval x + runEval y)
  neg x   = Eval (negate (runEval x))

-- Интерпретатор: pretty-print
newtype Pretty = Pretty { runPretty :: String }

instance ExprSym Pretty where
  lit n   = Pretty (show n)
  add x y = Pretty ("(" <> runPretty x <> " + " <> runPretty y <> ")")
  neg x   = Pretty ("(- " <> runPretty x <> ")")
```

### Программы полиморфны по интерпретатору

```haskell
example :: ExprSym repr => repr
example = add (lit 2) (neg (lit 3))
```

```text
> runEval example
-1

> runPretty example
"(2 + (- 3))"
```

Один и тот же `example` интерпретируется по-разному в зависимости от контекста.

### Расширяемость

Добавим умножение — **без изменения** существующего кода:

```haskell
class ExprSym repr => MulSym repr where
  mul :: repr -> repr -> repr

instance MulSym Eval where
  mul x y = Eval (runEval x * runEval y)

instance MulSym Pretty where
  mul x y = Pretty ("(" <> runPretty x <> " * " <> runPretty y <> ")")

example2 :: (ExprSym repr, MulSym repr) => repr
example2 = add (mul (lit 2) (lit 3)) (neg (lit 4))
```

Это решение Expression Problem (глава 15): новые операции (Mul) *и* новые интерпретаторы (Optimize) добавляются без изменения существующего кода.

```admonish tip title="Free → Tagless Final в production"
Начните с Free monad (понятнее: AST можно инспектировать и оптимизировать).
Переходите к Tagless Final (производительнее: GHC инлайнит всё, zero overhead).

В production Haskell Tagless Final — доминирующий подход. Его развитие —
effect systems (`polysemy`, `effectful`), которые добавляют удобство Free monad
к производительности Tagless Final.
```

## Сравнение

| Критерий | Free Monad | Tagless Final | Recursion Schemes |
|----------|-----------|---------------|-------------------|
| Лучше для | Инспекция/оптимизация AST | Production DSL | Работа с рекурсивными данными |
| Представление | ADT (данные) | Type classes (функции) | Fix-point функтора |
| Расширяемость | Новые интерпретаторы | Оба направления | Новые алгебры |
| Performance | AST overhead | Zero-cost (GHC inlines) | Fusion через hylo |
| Инспекция | Pattern match на AST | Нет (нет данных) | По слоям |
| Отладка | Проще (AST видим) | Сложнее | По слоям |
| Ecosystem | `free`, `polysemy` | Собственные type classes | `recursion-schemes` |

### Ключевые связи

- `Free f a` = `Fix f` + листья-значения.
- `iterM` из Free — это catamorphism.
- Tagless Final — «recursion schemes для DSL».
- Эволюция в production: Free → Tagless Final → Effect systems.

## Дальнейшее чтение

- Patrick Thomson, [An Introduction to Recursion Schemes](https://blog.sumtypeofway.com/posts/introduction-to-recursion-schemes.html) — лучший педагогический ресурс.
- Gabriel Gonzalez, [Why Free Monads Matter](https://www.haskellforall.com/2012/06/you-could-have-invented-free-monads.html) — классическое введение.
- Oleg Kiselyov, [Typed Tagless Final Interpreters](https://okmij.org/ftp/tagless-final/course/lecture.pdf) — фундаментальный источник.
- [Serokell: Introduction to Tagless Final](https://serokell.io/blog/introduction-tagless-final) — практический tutorial.
