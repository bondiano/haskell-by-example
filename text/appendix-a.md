# Графика и визуализация (gloss)

> **Это приложение — дополнительный материал.** Оно не входит в основную линию книги и не требуется для дальнейших глав. Читайте его, если вам интересна визуализация данных в Haskell.

## Зачем графика

На протяжении книги мы строили трекер задач: определяли типы, писали логику, тестировали, сохраняли в JSON, подключали базу данных. Но все результаты мы видели только в терминале. Иногда одна картинка стоит тысячи строк лога.

В этом приложении мы познакомимся с библиотекой `gloss` — простым инструментом для 2D-графики в Haskell. В конце построим **дашборд** нашего трекера задач: столбчатую диаграмму задач по статусам и круговую диаграмму по приоритетам.

## Библиотека `gloss`

`gloss` — минималистичная библиотека для 2D-графики, построенная на OpenGL. Она предоставляет четыре режима работы — от статической картинки до интерактивной игры — и требует минимума кода для старта.

### Установка

```yaml
# package.yaml
dependencies:
  - gloss
```

`gloss` требует OpenGL. На macOS она встроена. На Linux: `sudo apt install freeglut3-dev`.

```admonish tip title="Знакомый аналог"
`gloss` в Haskell — аналог `pygame` в Python или `p5.js` в JavaScript. Все три библиотеки дают простой API для быстрого прототипирования 2D-графики, скрывая детали OpenGL/Canvas.
```

### Тип `Picture`

Всё, что рисует `gloss`, представлено типом `Picture`:

```haskell
data Picture
  = Circle Float                   -- круг заданного радиуса
  | ThickCircle Float Float        -- круг с толщиной линии
  | RectangleSolid Float Float     -- закрашенный прямоугольник
  | RectangleWire Float Float      -- контурный прямоугольник
  | Line Path                      -- ломаная линия
  | Polygon Path                   -- закрашенный многоугольник
  | Color Color Picture            -- цвет
  | Translate Float Float Picture  -- сдвиг
  | Rotate Float Picture           -- поворот (градусы)
  | Scale Float Float Picture      -- масштаб
  | Pictures [Picture]             -- композиция нескольких картинок
  | ...
```

`Picture` — алгебраический тип данных, точно как наши `Priority` и `Status` из [главы 2](chapter02.md). Только вместо трёх конструкторов — десятки. Ключевой принцип тот же: **данные описывают, что рисовать**, а рендеринг — отдельная функция.

## Основные фигуры

### `display` — статическая картинка

Простейший режим: нарисовать одну картинку и остановиться.

```haskell
import Graphics.Gloss

main :: IO ()
main = display
  (InWindow "Привет" (400, 400) (100, 100))  -- окно 400x400
  white                                        -- цвет фона
  (Circle 100)                                 -- картинка: круг радиуса 100
```

### Комбинирование фигур

`Pictures` объединяет несколько картинок в одну. `Translate` сдвигает, `Color` окрашивает:

```haskell
colorSquares :: Picture
colorSquares = Pictures
  [ Color red   (Translate (-60)   60  (RectangleSolid 80 80))
  , Color blue  (Translate   60    60  (RectangleSolid 80 80))
  , Color green (Translate (-60) (-60) (RectangleSolid 80 80))
  , Color (makeColorI 255 165 0 255) (Translate 60 (-60) (RectangleSolid 80 80))
  ]
```

Здесь четыре квадрата расположены в углах. `makeColorI` создаёт цвет из RGBA (0–255).

### `color`, `translate`, `pictures` — функции-синонимы

`gloss` экспортирует как конструкторы (`Color`, `Translate`, `Pictures`), так и функции с маленькой буквы (`color`, `translate`, `pictures`). Они идентичны. В этом приложении мы используем конструкторы — они нагляднее.

```admonish note title="Координаты"
В `gloss` начало координат — **центр** окна. Ось X направлена вправо, ось Y — вверх. Это отличается от многих 2D-библиотек, где начало — левый верхний угол.
```

## Анимация

### `animate` — зависимость от времени

```haskell
animate :: Display -> Color -> (Float -> Picture) -> IO ()
```

Функция получает время (в секундах с момента запуска) и возвращает картинку для текущего кадра:

```haskell
main :: IO ()
main = animate (InWindow "Анимация" (400, 400) (100, 100)) white frame

frame :: Float -> Picture
frame t = Translate (150 * cos t) (150 * sin t) (Circle 20)
```

Круг движется по окружности. Функция `frame` — **чистая**: она не хранит состояние, а вычисляет картинку по времени.

### `simulate` — состояние и шаги

```haskell
simulate :: Display -> Color -> Int
          -> model                              -- начальное состояние
          -> (model -> Picture)                 -- рендеринг
          -> (ViewPort -> Float -> model -> model)  -- шаг симуляции
          -> IO ()
```

Мир описывается произвольным типом `model`. На каждом кадре вызывается функция шага, которая получает текущее состояние и дельту времени:

```haskell
data Ball = Ball
  { ballX  :: Float, ballY  :: Float
  , ballVX :: Float, ballVY :: Float
  }

stepBall :: ViewPort -> Float -> Ball -> Ball
stepBall _ dt (Ball x y vx vy) =
  let x' = x + vx * dt
      y' = y + vy * dt
      vx' = if abs x' > 180 then negate vx else vx
      vy' = if abs y' > 180 then negate vy else vy
  in Ball x' y' vx' vy'

renderBall :: Ball -> Picture
renderBall (Ball x y _ _) = Translate x y (Color red (Circle 15))
```

`stepBall` и `renderBall` — чистые функции. Их можно тестировать без `gloss`, точно так же, как мы тестировали `filterTasks` из [главы 3](chapter03.md).

### `play` — интерактивная игра

```haskell
play :: Display -> Color -> Int
     -> world                          -- начальное состояние
     -> (world -> Picture)             -- рендеринг
     -> (Event -> world -> world)      -- обработка событий
     -> (Float -> world -> world)      -- шаг по времени
     -> IO ()
```

К `simulate` добавляется обработка событий клавиатуры и мыши:

```haskell
handleEvent :: Event -> Ball -> Ball
handleEvent (EventKey (SpecialKey KeyUp) Down _ _)    b = b { ballVY = ballVY b + 20 }
handleEvent (EventKey (SpecialKey KeyDown) Down _ _)  b = b { ballVY = ballVY b - 20 }
handleEvent (EventKey (SpecialKey KeyLeft) Down _ _)  b = b { ballVX = ballVX b - 20 }
handleEvent (EventKey (SpecialKey KeyRight) Down _ _) b = b { ballVX = ballVX b + 20 }
handleEvent _ b = b
```

```admonish tip title="Знакомый аналог"
Четыре режима `gloss` — это паттерн **Elm Architecture** (Model-View-Update) в миниатюре:
- `model` = состояние приложения
- `render` = view (модель -> картинка)
- `handleEvent` + `step` = update (событие/время -> новая модель)

В React это аналогично `state` + `render` + `reducer`.
```

## Чистая графика: вычисления без рендеринга

Ключевая идея `gloss`: **логика отделена от рендеринга**. Функции `step` и `render` — чистые. Только `display` / `simulate` / `play` выполняют IO.

Это идеально ложится на архитектуру **Functional Core, Imperative Shell** из [главы 7](chapter07.md):

```haskell
-- Чистое ядро: можно тестировать без gloss
stepBall :: Float -> Ball -> Ball
renderBall :: Ball -> Picture

-- Императивная оболочка: только запуск
main :: IO ()
main = simulate window white 60 initialBall renderBall (\_ -> stepBall)
```

## Проект: дашборд статистики трекера задач

Применим `gloss` к нашему сквозному проекту. Допустим, в трекере есть список задач с полями `taskStatus :: Status` и `taskPriority :: Priority`. Мы хотим визуализировать:

1. **Столбчатую диаграмму** — количество задач по статусам (Todo, InProgress, Done).
2. **Круговую диаграмму** — распределение задач по приоритетам (Low, Medium, High).

### Подготовка данных

Сначала — чистые функции для подсчёта статистики. Они не зависят от `gloss`:

```haskell
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map

-- Подсчёт задач по статусу
countByStatus :: [Task] -> Map Status Int
countByStatus = foldl' (\acc t -> Map.insertWith (+) (taskStatus t) 1 acc) Map.empty

-- Подсчёт задач по приоритету
countByPriority :: [Task] -> Map Priority Int
countByPriority = foldl' (\acc t -> Map.insertWith (+) (taskPriority t) 1 acc) Map.empty
```

```admonish note title="Знакомые функции"
`foldl'` и `Map.insertWith` мы разбирали в [главе 4](chapter04.md) и [главе 6](chapter06.md). Здесь они используются для группировки и подсчёта — классическая операция `GROUP BY ... COUNT(*)` из SQL.
```

### Столбчатая диаграмма (bar chart)

```haskell
barChart :: [(String, Int, Color)] -> Picture
barChart entries = Pictures $ zipWith drawBar [0..] entries
  where
    barWidth  = 60
    barGap    = 20
    maxHeight = 200

    maxVal = maximum (map (\(_, v, _) -> v) entries)
    scale' v = fromIntegral v / fromIntegral (max 1 maxVal) * maxHeight

    drawBar i (label, value, c) =
      let h  = scale' value
          x  = fromIntegral i * (barWidth + barGap)
          bar   = Color c (Translate x (h / 2) (RectangleSolid barWidth h))
          txt   = Translate x (-20) (Scale 0.1 0.1 (Text label))
          count = Translate x (h + 10) (Scale 0.1 0.1 (Text (show value)))
      in Pictures [bar, txt, count]
```

Каждый столбец — `RectangleSolid`, сдвинутый на нужную позицию. Высота пропорциональна значению. Подписи — `Text` с масштабированием (`Scale 0.1 0.1`), потому что `gloss` рисует текст крупным шрифтом по умолчанию.

### Круговая диаграмма (pie chart)

```haskell
pieChart :: [(String, Int, Color)] -> Float -> Picture
pieChart entries radius = Pictures $ snd $ foldl' drawSlice (0, []) entries
  where
    total = fromIntegral (sum (map (\(_, v, _) -> v) entries))

    drawSlice (startAngle, pics) (label, value, c) =
      let fraction  = fromIntegral value / max 1 total
          sweepDeg  = fraction * 360
          endAngle  = startAngle + sweepDeg
          midAngle  = (startAngle + endAngle) / 2
          slice     = Color c (arcSolid startAngle endAngle radius)
          -- Подпись чуть дальше от центра
          labelDist = radius + 30
          lx = labelDist * cos (midAngle * pi / 180)
          ly = labelDist * sin (midAngle * pi / 180)
          txt = Translate lx ly (Scale 0.08 0.08 (Text label))
      in (endAngle, pics ++ [slice, txt])

-- Вспомогательная функция: сектор через Polygon
arcSolid :: Float -> Float -> Float -> Picture
arcSolid startDeg endDeg r =
  let steps = max 1 (round (abs (endDeg - startDeg) / 5))
      angles = [ (startDeg + fromIntegral i * (endDeg - startDeg) / fromIntegral steps) * pi / 180
               | i <- [0..steps] ]
      points = (0, 0) : [(r * cos a, r * sin a) | a <- angles]
  in Polygon points
```

### Сборка дашборда

```haskell
dashboard :: [Task] -> Picture
dashboard tasks =
  let statusData = Map.toList (countByStatus tasks)
      statusBars =
        [ (showStatus s, n, statusColor s) | (s, n) <- statusData ]

      prioData = Map.toList (countByPriority tasks)
      prioSlices =
        [ (showPriority p, n, prioColor p) | (p, n) <- prioData ]

      leftPanel  = Translate (-200) 0 (barChart statusBars)
      rightPanel = Translate 200 0 (pieChart prioSlices 100)
      title'     = Translate (-150) 250 (Scale 0.15 0.15 (Text "Дашборд трекера задач"))
  in Pictures [title', leftPanel, rightPanel]

statusColor :: Status -> Color
statusColor Todo       = greyN 0.6
statusColor InProgress = makeColorI 52 152 219 255   -- синий
statusColor Done       = makeColorI 46 204 113 255   -- зелёный

prioColor :: Priority -> Color
prioColor Low    = makeColorI 149 165 166 255  -- серый
prioColor Medium = makeColorI 241 196 15 255   -- жёлтый
prioColor High   = makeColorI 231 76 60 255    -- красный

showStatus :: Status -> String
showStatus Todo       = "Todo"
showStatus InProgress = "In Progress"
showStatus Done       = "Done"

showPriority :: Priority -> String
showPriority Low    = "Low"
showPriority Medium = "Medium"
showPriority High   = "High"
```

Запуск:

```haskell
main :: IO ()
main = display
  (InWindow "Task Tracker Dashboard" (800, 600) (100, 100))
  white
  (dashboard sampleTasks)
```

```admonish warning title="Тестирование без gloss"
Функции `countByStatus`, `countByPriority`, `barChart`, `pieChart` — чистые. Их можно тестировать через `hspec` без запуска окна. Тестируйте данные (подсчёт статистики), а не пиксели.
```

## Бонус: Game of Life

В качестве бонуса — реализация клеточного автомата Конвея. Она демонстрирует `simulate` в действии.

### Представление

Используем `Set (Int, Int)` — множество координат живых клеток:

```haskell
import Data.Set (Set)
import Data.Set qualified as Set

type Grid = Set (Int, Int)
```

### Правила

1. **Живая** клетка с 2 или 3 соседями **выживает**.
2. **Мёртвая** клетка с ровно 3 соседями **оживает**.
3. Все остальные **умирают**.

```haskell
neighbors :: (Int, Int) -> [(Int, Int)]
neighbors (x, y) =
  [ (x + dx, y + dy)
  | dx <- [-1, 0, 1], dy <- [-1, 0, 1]
  , (dx, dy) /= (0, 0)
  ]

countAlive :: Grid -> (Int, Int) -> Int
countAlive grid cell = length (filter (`Set.member` grid) (neighbors cell))

stepLife :: Grid -> Grid
stepLife grid =
  let candidates = Set.union grid neighborCells
      neighborCells = Set.fromList
        [ n | cell <- Set.toList grid, n <- neighbors cell ]
  in Set.filter (alive grid) candidates

alive :: Grid -> (Int, Int) -> Bool
alive grid cell =
  let n = countAlive grid cell
  in if Set.member cell grid
     then n == 2 || n == 3
     else n == 3
```

### Визуализация

```haskell
cellSize :: Float
cellSize = 10

renderGrid :: Grid -> Picture
renderGrid grid = Pictures
  [ Translate (fromIntegral x * cellSize) (fromIntegral y * cellSize)
      (RectangleSolid cellSize cellSize)
  | (x, y) <- Set.toList grid
  ]

-- Классическая фигура «глайдер»
glider :: Grid
glider = Set.fromList [(1, 0), (2, 1), (0, 2), (1, 2), (2, 2)]

main :: IO ()
main = simulate
  (InWindow "Game of Life" (600, 600) (100, 100))
  white 5
  glider
  renderGrid
  (\_ _ g -> stepLife g)
```

Каждые 200 мс (5 fps) вычисляется следующее поколение. `stepLife` — чистая функция, `renderGrid` — чистая функция, `simulate` оборачивает их в IO.

## Упражнения

### 1. Горизонтальная столбчатая диаграмма (&#9733;&#9734;&#9734;)

Модифицируйте `barChart` так, чтобы столбцы были горизонтальными (растут слева направо), а подписи — слева от столбца.

```haskell
barChartHorizontal :: [(String, Int, Color)] -> Picture
```

*Подсказка:* поменяйте местами оси — ширина столбца определяется значением, а вертикальная позиция — индексом.

### 2. Анимированный дашборд (&#9733;&#9733;&#9734;)

Используйте `animate`, чтобы столбцы диаграммы «вырастали» от нуля до целевой высоты за первые 2 секунды. Функция принимает время `t` и список данных:

```haskell
animatedBarChart :: Float -> [(String, Int, Color)] -> Picture
```

*Подсказка:* умножьте высоту каждого столбца на `min 1 (t / 2)`. При `t >= 2` диаграмма перестаёт меняться.

## Заключение

Мы познакомились с `gloss` и её четырьмя режимами (`display`, `animate`, `simulate`, `play`), разобрали тип `Picture` как композицию фигур через алгебраические типы данных. На примере дашборда трекера задач увидели, как строить столбчатые и круговые диаграммы. Game of Life продемонстрировала `simulate` с чистой логикой. Главный вывод: разделение логики и рендеринга позволяет тестировать графический код без запуска окна.

Графика — не основная сила Haskell, но `gloss` показывает, как функциональный подход упрощает даже визуализацию: данные отдельно, отображение отдельно, состояние — чистая функция.
