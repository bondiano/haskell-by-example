# Заключение

## Что вы изучили

За 18 глав мы прошли путь от первых шагов до создания веб-приложения с базой данных. Вот краткая карта пройденного:

**Основы языка** (главы 1–5): типы данных, функции, записи, сопоставление с образцом, рекурсия, свёртки, ленивость.

**Абстракции** (главы 6–8): классы типов, `Functor`, `Applicative`, `Monad`, `do`-нотация, законы монад.

**Эффекты и конкурентность** (главы 9–10): `IO`, `IORef`, `async`, `MVar`, `STM`.

**Практические инструменты** (главы 11–15): FFI, `Text`/`ByteString`, `aeson`, трансформеры монад, `mtl`, `gloss`, QuickCheck, megaparsec.

**Продвинутые темы** (главы 16–18): GADTs, семейства типов, линзы, persistent, Scotty.

Это фундамент, достаточный для написания реальных приложений. Но экосистема Haskell гораздо шире — вот направления для дальнейшего роста.

## Куда двигаться дальше

### Типобезопасные веб-API: Servant

В главе 18 мы использовали Scotty — простой фреймворк, где маршруты описываются строками. [Servant](https://docs.servant.dev/) кодирует API на уровне типов:

```haskell
type API = "todos" :> Get '[JSON] [Todo]
      :<|> "todos" :> ReqBody '[JSON] TodoDTO :> Post '[JSON] TodoId
```

Компилятор проверяет, что сервер, клиент и документация соответствуют спецификации. Servant требует понимания type-level программирования (глава 16), но даёт мощные гарантии.

### Потоковая обработка данных

В книге мы работали с данными целиком: прочитали файл — обработали — записали. Для больших объёмов (логи, сетевые потоки, видео) нужна потоковая обработка. Основные библиотеки:

- [conduit](https://github.com/snoyberg/conduit) — самая популярная, используется в Yesod и Stack.
- [streaming](https://hackage.haskell.org/package/streaming) — минималистичная, хорошо компонуется с `Prelude`-функциями.
- [pipes](https://hackage.haskell.org/package/pipes) — элегантная, с сильными теоретическими основаниями.

### Профилирование и оптимизация

В главе 5 мы обсуждали ленивость и space leaks. Для диагностики в реальных проектах Haskell предоставляет инструменты:

- **`+RTS -s`** — статистика по памяти и сборке мусора.
- **`+RTS -p`** — профиль по времени и аллокациям (требует сборку с `-prof`).
- **`+RTS -h`** — heap profile (графики потребления памяти).
- **[eventlog2html](https://hackage.haskell.org/package/eventlog2html)** — визуализация профилей.

Книга Саймона Марлоу [«Parallel and Concurrent Programming in Haskell»](https://simonmar.github.io/pages/pcph.html) подробно разбирает профилирование и параллелизм.

### Альтернативные системы эффектов

В главе 12 мы использовали `mtl` — классический подход к комбинированию эффектов. Существуют более современные альтернативы:

- [effectful](https://github.com/haskell-effectful/effectful) — высокопроизводительная библиотека эффектов, совместимая с `mtl`.
- [polysemy](https://hackage.haskell.org/package/polysemy) — алгебраические эффекты через free-монады.
- [bluefin](https://hackage.haskell.org/package/bluefin) — линейные эффекты, новый подход.

### Расширения GHC

В книге мы использовали несколько расширений (`GADTs`, `DataKinds`, `TypeFamilies`). Вот расширения, которые стоит включать в большинстве проектов:

- `ScopedTypeVariables` — переменные типа видны во всей сигнатуре.
- `TypeApplications` — явная передача типовых аргументов: `read @Int "42"`.
- `ImportQualifiedPost` — `import Data.Map qualified as Map` (вместо `import qualified`).
- `DerivingStrategies` — явные стратегии деривации (мы уже использовали).
- `OverloadedStrings` — строковые литералы для `Text`, `ByteString` и др.
- `StrictData` — строгие поля по умолчанию (предотвращает space leaks в записях).

Полный обзор расширений: [GHC User's Guide — Language extensions](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts.html).

### Сборка и деплой

- **[Nix](https://nixos.org/)** — воспроизводимая сборка. Многие Haskell-проекты используют Nix вместо (или вместе со) Stack.
- **Docker** — для деплоя. Статическая линковка через Alpine Linux даёт компактные образы.
- **[Cabal](https://cabal.readthedocs.io/)** — альтернатива Stack, встроенная в GHCup. Современный Cabal (3.x) поддерживает воспроизводимые сборки через `cabal.project.freeze`.

### Рекомендуемые книги и ресурсы

- **[Parallel and Concurrent Programming in Haskell](https://simonmar.github.io/pages/pcph.html)** (Simon Marlow) — глубокое погружение в параллелизм и конкурентность.
- **[Haskell in Depth](https://www.manning.com/books/haskell-in-depth)** (Vitaly Bragilevsky) — промышленный Haskell.
- **[Thinking with Types](https://thinkingwithtypes.com/)** (Sandy Maguire) — type-level программирование.
- **[Production Haskell](https://leanpub.com/production-haskell)** (Matt Parsons) — практические паттерны для production-кода.
- **[Monday Morning Haskell](https://mmhaskell.com/)** — блог с практическими руководствами.
- **[Haskell Weekly](https://haskellweekly.news/)** — еженедельная рассылка новостей экосистемы.

## Напутствие

Haskell учит думать о программировании по-другому. Типы как язык проектирования, чистота как инструмент рассуждения, композиция как основа архитектуры — эти идеи ценны независимо от того, на каком языке вы пишете в повседневной работе.

Не останавливайтесь на прочитанном. Пишите код, читайте чужой код на [Hackage](https://hackage.haskell.org/), участвуйте в обсуждениях на [Haskell Discourse](https://discourse.haskell.org/). Haskell — язык с одним из самых дружелюбных и увлечённых сообществ в мире программирования.

Удачи!
