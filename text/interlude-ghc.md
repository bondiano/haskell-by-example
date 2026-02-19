# Интерлюдия: компилятор GHC

Прежде чем перейти к продвинутым темам, полезно понять, что происходит «под капотом». GHC (Glasgow Haskell Compiler) — один из самых сложных компиляторов в мире. Эта интерлюдия — обзорная карта, а не глубокое погружение.

## Compilation pipeline

Путь от исходного кода до машинного:

```text
Haskell Source
    │
    ▼
  Parse          → синтаксическое дерево (HsSyn)
    │
    ▼
  Rename         → разрешение имён, области видимости
    │
    ▼
  Type Check     → вывод типов (Hindley-Milner + расширения)
    │
    ▼
  Desugar        → убрать синтаксический сахар
    │
    ▼
  Core           → типизированный lambda calculus (System FC)
    │               ↕ оптимизации (inlining, fusion, rules)
    ▼
  STG            → Spineless Tagless G-machine
    │
    ▼
  Cmm            → C-подобный промежуточный язык
    │
    ▼
  Machine Code   → через LLVM или собственный backend
```

Каждый этап — это трансформация из одного промежуточного представления в другое. Все ваши `do`-блоки, `where`-клозы, pattern matching, list comprehensions — «растворяются» на этапе Desugar, превращаясь в Core.

## Core: типизированный лямбда-исчисление

**Core** — сердце GHC. Это крошечный язык (~10 конструкций), основанный на **System FC** (System F with Coercions):

```text
data Expr
  = Var   Id              -- переменная
  | Lit   Literal         -- литерал
  | App   Expr Expr       -- применение
  | Lam   Id Expr         -- абстракция
  | Let   Bind Expr       -- let-binding
  | Case  Expr Id [Alt]   -- case-выражение
  | Cast  Expr Coercion   -- приведение типов (для newtypes и GADT)
  | Type  Type            -- тип (стирается в рантайме)
```

Весь Haskell с его синтаксическим богатством сводится к этим конструкциям. Связь с лямбда-исчислением из главы 15 — прямая: Core — это типизированное лямбда-исчисление с `case` и `let`.

```admonish note title="Core Lint"
GHC после каждого прохода оптимизации прогоняет **Lint** — type checker для Core.
Если оптимизация ломает типизацию, Lint это обнаружит. Это «type checker для компилятора».
```

Вы можете посмотреть Core вашего кода:

```text
$ stack ghc -- -ddump-simpl -dsuppress-all MyModule.hs
```

## Оптимизации: inlining и rewrite rules

GHC применяет десятки оптимизаций на уровне Core. Ключевые:

### Inlining

GHC подставляет тело маленьких функций вместо вызова. Это открывает возможности для дальнейших оптимизаций (constant folding, case-of-case и т.д.):

```haskell
{-# INLINE map #-}
```

Прагма `INLINE` — подсказка GHC: «эту функцию стоит подставлять на месте вызова».

### Rewrite rules и fusion

```haskell
{-# RULES "map/map" forall f g xs. map f (map g xs) = map (f . g) xs #-}
```

Rewrite rules позволяют библиотекам определять алгебраические тождества. GHC применяет их автоматически. Самый известный пример — **foldr/build fusion**:

```haskell
-- Без fusion: создаётся промежуточный список
sum (map (+1) [1..1000000])

-- С fusion: GHC «склеивает» map и sum в один проход
-- Промежуточный список не аллоцируется!
```

```admonish tip title="INLINE для библиотечного кода"
Если ваша библиотека экспортирует маленькие функции, добавьте `INLINE` —
GHC сможет оптимизировать их на стороне клиентского кода (cross-module inlining).
```

## Runtime System (RTS)

GHC компилирует в нативный код, но программа работает внутри **Runtime System** — среды исполнения, предоставляющей:

### Green threads

Потоки в Haskell — **лёгкие** (green threads). Они мультиплексируются на несколько OS-потоков средой выполнения:

- Создание потока: ~1 КБ стека (vs ~1 МБ для OS thread).
- Миллионы одновременных потоков — нормальная ситуация.
- Кооперативная планировка с preemption на safe points.

```admonish note title="Историческая справка"
Go goroutines используют ту же идею (green threads + M:N scheduling), но Haskell
делал это с 1990-х. Erlang — ещё раньше, с 1986 года.
```

### Сборщик мусора

GHC использует **generational, copying GC** с параллельной сборкой:

- **Nursery** (generation 0): маленькая область, собирается часто и быстро.
- **Старое поколение** (generation 1+): объекты, пережившие несколько сборок.
- **Block-structured heap**: память выделяется блоками по 4 КБ.

Для программ с большим количеством долгоживущих данных можно настроить GC:

```text
$ ./myprogram +RTS -N4 -A64m -H512m
--                 │    │      │
--                 │    │      └── начальный размер heap
--                 │    └── размер nursery (больше = реже minor GC)
--                 └── 4 OS-потока
```

## Дальнейшее чтение

- [The Architecture of Open Source Applications: GHC](https://aosabook.org/en/v2/ghc.html) — обзор архитектуры.
- [GHC Commentary (Wiki)](https://gitlab.haskell.org/ghc/ghc/-/wikis/commentary) — детальная документация для разработчиков.
- Simon Marlow, *Parallel and Concurrent Programming in Haskell* (O'Reilly) — RTS и конкурентность.
