# Куда дальше

## Что мы построили

На протяжении двадцати глав мы прошли путь от `"Hello, World!"` в GHCi до типобезопасного веб-приложения с парсерами, GADTs и линзами. Всё это время нас сопровождал один сквозной проект — **трекер задач**, который рос вместе с нашими знаниями.

Вот как эволюционировал наш трекер:

| Глава | Что добавили | Концепция |
|-------|-------------|-----------|
| 2 | Типы `Task`, `Priority`, `Status` | Базовые типы и функции |
| 3 | `TaskFilter`, `applyFilter` | ADT и паттерн-матчинг |
| 4 | Обработка списков задач, `TaskStats` | Рекурсия, свёртки |
| 5 | `Describable`, `compareTasks` | Классы типов |
| 6 | `Map TaskId Task`, `Set Tag` | Эффективные структуры данных |
| 7 | CLI-интерфейс: ввод/вывод, файлы | IO-монада |
| 8 | Валидация, `Either`-цепочки | Обработка ошибок |
| 9 | Строгие поля в `TaskStats` | Ленивость и производительность |
| 10 | Тесты для фильтрации и сортировки | hspec, QuickCheck |
| 11 | `fmap`/`traverse` по задачам | Functor, Applicative |
| 12 | Цепочки IO-операций | Монады, do-нотация |
| 13 | `ReaderT` для конфигурации | Трансформеры, mtl |
| 14 | Сериализация задач в JSON | aeson, Generic |
| 15 | Модульная структура проекта | Организация кода |
| 16 | Параллельная обработка задач | async, STM |
| 17 | REST API + PostgreSQL | Servant, persistent |
| 18 | Язык запросов `status:done tag:work` | Парсеры, megaparsec |
| 19 | Типобезопасный конструктор запросов | GADTs, Type Families |
| 20 | Конфигурация через линзы | lens, оптики |

Из простого набора типов и функций вырос проект, затрагивающий почти все основные концепции Haskell. И это только начало — экосистема Haskell невероятно глубока.

## Обзор продвинутых тем

Ниже — краткий обзор направлений, которые мы не рассмотрели (или рассмотрели лишь поверхностно). Каждое из них заслуживает отдельной книги, но знать о них полезно уже сейчас.

### Servant: типобезопасные API

В [главе 17](chapter17.md) мы использовали Servant для REST API. Но Servant — это гораздо больше, чем HTTP-сервер. Servant описывает API как *тип*, из которого автоматически генерируются:

- Серверная обработка запросов
- Клиентские функции для вызова API
- Документация (Swagger/OpenAPI)
- Моки для тестирования

```haskell
type TaskAPI =
       "tasks" :> Get '[JSON] [Task]
  :<|> "tasks" :> ReqBody '[JSON] Task :> Post '[JSON] TaskId
  :<|> "tasks" :> Capture "id" TaskId :> Get '[JSON] Task
```

Из одного типа `TaskAPI` Servant генерирует и сервер, и клиент. Если вы измените API — код клиента и сервера перестанет компилироваться, пока вы не обновите оба. Это «контракт на уровне типов».

Ресурсы: [servant.dev](https://docs.servant.dev/en/stable/), [туториал](https://docs.servant.dev/en/stable/tutorial/index.html).

### Потоковая обработка: conduit, pipes, streaming

Когда данных слишком много для загрузки в память (логи, потоки событий, большие файлы), нужна *потоковая обработка*. В Haskell есть несколько библиотек:

- **conduit** — наиболее популярная, используется в Yesod и Stack.
- **pipes** — элегантная, с хорошей теоретической основой.
- **streaming** — минималистичная, близкая к обычным спискам.

Все три позволяют обрабатывать данные по частям (chunk) с постоянным потреблением памяти, сохраняя композируемость.

```haskell
-- conduit: прочитать файл построчно и посчитать строки
import Conduit

lineCount :: FilePath -> IO Int
lineCount path = runConduitRes
  $ sourceFile path
  .| decodeUtf8C
  .| linesUnboundedC
  .| lengthC
```

Ресурсы: [conduit tutorial](https://github.com/snoyberg/conduit#readme), [pipes tutorial](https://hackage.haskell.org/package/pipes/docs/Pipes-Tutorial.html).

### Системы эффектов: polysemy, effectful

В [главе 13](chapter13.md) мы использовали трансформеры и mtl для комбинирования эффектов. Это работает, но имеет ограничения: `n` эффектов требуют `O(n^2)` инстансов, порядок трансформеров важен, производительность может страдать.

**Системы эффектов** — современная альтернатива:

- **effectful** — быстрая, основана на `IO` и `IORef`. Рекомендуется для новых проектов.
- **polysemy** — элегантная, основана на free monads. Медленнее, но выразительнее.

```haskell
-- effectful: объявление эффекта
data TaskStore :: Effect where
  GetTask :: TaskId -> TaskStore m (Maybe Task)
  SaveTask :: Task -> TaskStore m TaskId
  DeleteTask :: TaskId -> TaskStore m ()
```

Системы эффектов позволяют декларативно описывать, какие «способности» нужны функции, и подменять их реализации (для тестов, для разных окружений).

Ресурсы: [effectful](https://github.com/haskell-effectful/effectful), [polysemy](https://github.com/polysemy-research/polysemy).

### Рекурсивные схемы

Рекурсивные схемы (recursion schemes) — обобщение паттернов рекурсии. Вместо написания рекурсии вручную, вы выражаете её через стандартные комбинаторы:

- **catamorphism** (`cata`) — свёртка структуры (обобщение `foldr`)
- **anamorphism** (`ana`) — развёртка (обобщение `unfoldr`)
- **hylomorphism** (`hylo`) — развёртка, затем свёртка (без промежуточной структуры)
- **paramorphism** (`para`) — свёртка с доступом к оригинальной структуре

```haskell
-- Факториал как hylomorphism (не строя промежуточный список):
factorial :: Int -> Int
factorial = hylo (\case Nil -> 1; Cons n acc -> n * acc)
                 (\case 0 -> Nil; n -> Cons n (n - 1))
```

Ключевая идея — тип `Fix f` (фиксированная точка функтора), который позволяет отделить *форму* рекурсии от *данных*. Тема глубокая, но она делает рекурсивный код модульным и переиспользуемым.

Ресурсы: [recursion-schemes](https://hackage.haskell.org/package/recursion-schemes), статья [«An Introduction to Recursion Schemes»](https://blog.sumtypeofway.com/posts/introduction-to-recursion-schemes.html).

### Free Monads и Tagless Final

Два подхода к построению интерпретируемых DSL:

**Free Monad** — конструируем AST программы как данные, затем интерпретируем:

```haskell
data TaskDSL next
  = CreateTask Text Priority (TaskId -> next)
  | GetTask TaskId (Maybe Task -> next)
  | CompleteTask TaskId next
  deriving (Functor)

type TaskProgram = Free TaskDSL
```

**Tagless Final** — описываем программу через класс типов, реализации — инстансы:

```haskell
class Monad m => TaskDSL m where
  createTask   :: Text -> Priority -> m TaskId
  getTask      :: TaskId -> m (Maybe Task)
  completeTask :: TaskId -> m ()
```

Оба подхода позволяют тестировать бизнес-логику без реальных баз данных и IO — подставляя «мок»-интерпретатор.

Ресурсы: [«Free Monads for Less»](https://ekmett.github.io/reader/2012/free-monads-for-less/index.html) (Kmett), [«Introduction to Tagless Final»](https://serokell.io/blog/tagless-final).

### Теория категорий: Contravariant, Profunctor и другие

В [главе 11](chapter11.md) мы изучили `Functor` — возможность применить функцию «внутри» контейнера. Теория категорий даёт богатую иерархию абстракций:

- **Contravariant** — «обратный функтор»: `contramap :: (a -> b) -> f b -> f a`. Описывает *потребителей* (например, сериализаторы, предикаты).
- **Profunctor** — «функтор двух аргументов»: контравариантный по первому, ковариантный по второму. Линзы из [главы 20](chapter20.md) внутри используют профункторы.
- **Bifunctor** — `bimap :: (a -> c) -> (b -> d) -> f a b -> f c d`. Работает с `Either`, кортежами и другими двупараметрическими типами.
- **Arrow** — обобщение функций. Стрелки позволяют строить вычисления с несколькими входами и выходами.

Эти абстракции не нужны для повседневного кода, но понимание их обогащает дизайн библиотек и помогает читать документацию продвинутых пакетов.

Ресурсы: [«Category Theory for Programmers»](https://bartoszmilewski.com/2014/10/28/category-theory-for-programmers-the-preface/) (Бартош Милевский) — лучшее введение, доступна бесплатно онлайн.

### Nix для воспроизводимых сборок

Stack и Cabal управляют зависимостями Haskell, но **Nix** идёт дальше: он гарантирует воспроизводимость *всего* окружения, включая системные библиотеки, компилятор и инструменты.

Многие production-проекты на Haskell используют Nix:

- **Воспроизводимость**: одинаковая сборка на всех машинах.
- **Системные зависимости**: PostgreSQL, OpenSSL, zlib — всё управляется Nix.
- **CI/CD**: кэширование через Cachix, мгновенные пересборки.

```nix
# flake.nix для Haskell-проекта
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShell = pkgs.haskellPackages.shellFor {
          packages = p: [ p.my-project ];
          buildInputs = [ pkgs.cabal-install pkgs.haskell-language-server ];
        };
      });
}
```

Ресурсы: [nix.dev](https://nix.dev/), [haskell4nix](https://github.com/input-output-hk/haskell.nix).

## Рекомендуемые ресурсы

### Книги

| Книга | Для кого | Комментарий |
|-------|----------|-------------|
| **Haskell Programming from First Principles** (Allen, Moronuki) | Начинающие | Самый полный учебник. 1200+ страниц с упражнениями. Если хотите глубоко понять основы — начните здесь. |
| **Real World Haskell** (O'Sullivan, Stewart, Goerzen) | Практики | Много практических примеров (HTTP, базы данных, парсинг). Частично устарела, но архитектурные идеи актуальны. Доступна [бесплатно онлайн](http://book.realworldhaskell.org/). |
| **Thinking with Types** (Sandy Maguire) | Продвинутые | Type-level программирование: GADTs, Type Families, зависимые типы. Продолжение тем из [главы 19](chapter19.md). |
| **Algorithm Design with Haskell** (Bird, Gibbons) | Алгоритмы | Функциональный подход к алгоритмам: рекурсивные схемы, жадные алгоритмы, динамическое программирование через ленивость. |
| **Parallel and Concurrent Programming in Haskell** (Marlow) | Конкурентность | Глубокое погружение в параллелизм и конкурентность. Автор — один из создателей GHC. Доступна [бесплатно онлайн](https://simonmar.github.io/pages/pcph.html). |

### Онлайн-ресурсы

- **[haskell.mooc.fi](https://haskell.mooc.fi/)** — бесплатный курс от Университета Хельсинки. Два модуля: основы и продвинутые темы. Отличные упражнения с автоматической проверкой.

- **[MetaLamp Haskell](https://education.metalamp.ru/education/haskell/task-1)** — курс на русском языке с практическими заданиями. Хорошее дополнение к этой книге.

- **[Haskell Wiki](https://wiki.haskell.org/)** — энциклопедия Haskell. Статьи о паттернах, библиотеках, типичных проблемах. Качество неравномерное, но лучшие статьи великолепны.

- **[What I Wish I Knew When Learning Haskell](https://dev.stephendiehl.com/hask/)** — Стивен Диль (Stephen Diehl). Обширный справочник по продвинутым темам: от системы типов до компиляции. Неформальный, с примерами кода.

- **[Monday Morning Haskell](https://mmhaskell.com/)** — блог с практическими туториалами. Темы: веб-разработка, базы данных, машинное обучение на Haskell.

- **[Haskell School of Music](http://euterpea.com/haskell-school-of-music/)** — книга о создании музыки на Haskell. Необычный и вдохновляющий способ изучать функциональное программирование.

### Сообщество

- **[Haskell Discourse](https://discourse.haskell.org/)** — официальный форум. Вопросы, обсуждения RFC, анонсы библиотек. Дружелюбное сообщество, не стесняйтесь задавать вопросы.

- **[Reddit r/haskell](https://www.reddit.com/r/haskell/)** — активный сабреддит. Новости, обсуждения, еженедельные дайджесты.

- **[Haskell on StackOverflow](https://stackoverflow.com/questions/tagged/haskell)** — тысячи вопросов и ответов. Многие ответы написаны авторами GHC и ключевых библиотек.

- **Telegram** — русскоязычные чаты: `@haskellru` (общий), `@haskell_learn` (для изучающих). Можно задать вопрос и получить ответ за минуты.

- **[Haskell Foundation](https://haskell.foundation/)** — организация, продвигающая Haskell. Программы менторства, мероприятия, поддержка инфраструктуры.

## Заключительное слово

Haskell — необычный язык. Он требует перестройки мышления: вместо мутабельных переменных — иммутабельные значения, вместо циклов — рекурсия и свёртки, вместо интерфейсов — классы типов, вместо наследования — композиция.

Эта перестройка непроста, но она того стоит. Идеи, которые вы освоили в этой книге — чистые функции, алгебраические типы данных, параметрический полиморфизм, монады — переносятся в *любой* язык программирования. TypeScript, Python, Rust, Kotlin, Scala — все они заимствуют концепции из функционального программирования. Зная Haskell, вы будете писать лучший код на любом языке.

Несколько советов на прощание:

1. **Пишите код.** Никакое чтение не заменит практики. Возьмите реальный проект — CLI-утилиту, Telegram-бота, парсер конфигурации — и реализуйте его на Haskell.

2. **Читайте чужой код.** Библиотеки вроде `aeson`, `servant`, `lens` — образцы хорошего дизайна на Haskell. Исходный код на Hackage открыт.

3. **Не бойтесь не понимать.** Монады, функторы, GADTs — всё это становится понятным с практикой. Если что-то кажется магией — вернитесь через месяц, и оно прояснится.

4. **Участвуйте в сообществе.** Задавайте вопросы, отвечайте на чужие, контрибьютьте в open source. Сообщество Haskell — одно из самых дружелюбных в IT.

5. **Получайте удовольствие.** Haskell — это язык, в котором программирование *красиво*. Элегантный тип, компактная функция, программа, которая «просто работает» после компиляции — всё это источники удовольствия.

```admonish note title="Благодарности"
Эта книга вдохновлена «PureScript by Example» Фила Фримена (Phil Freeman) и «Haskell Programming from First Principles» Кристофера Аллена и Джули Моронуки. Спасибо сообществу Haskell за инструменты, библиотеки и бесконечное терпение в ответах на вопросы новичков.
```
