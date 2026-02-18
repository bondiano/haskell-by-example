# Графика

## Цели главы

В этой главе мы познакомимся с 2D-графикой в Haskell через библиотеку `gloss`. Мы разберём четыре режима работы — от статического изображения до интерактивной игры — и реализуем классические задачи: Game of Life, отскакивающий мяч и фрактал Коха.

Упражнения этой главы — чистые функции, которые вычисляют графические данные. Их можно визуализировать через `gloss`, но тестировать — без неё.

## Библиотека `gloss`

`gloss` — простая библиотека для 2D-графики, построенная на OpenGL. Её главное достоинство — минимальный API для быстрого прототипирования.

### Установка

```yaml
# package.yaml (или .cabal)
dependencies:
  - gloss
```

`gloss` требует OpenGL. На macOS — встроена. На Linux: `sudo apt install freeglut3-dev`.

### Тип `Picture`

Всё, что рисуется, представлено типом `Picture`:

```haskell
data Picture
  = Circle Float               -- круг
  | ThickCircle Float Float    -- круг с толщиной линии
  | RectangleSolid Float Float -- закрашенный прямоугольник
  | RectangleWire Float Float  -- контурный прямоугольник
  | Line Path                  -- ломаная линия
  | Polygon Path               -- закрашенный многоугольник
  | Color Color Picture        -- цвет
  | Translate Float Float Picture  -- сдвиг
  | Rotate Float Picture           -- поворот (градусы)
  | Scale Float Float Picture      -- масштаб
  | Pictures [Picture]             -- композиция
  | ...
```

### Режим 1: `display` — статическая картинка

```haskell
import Graphics.Gloss

main :: IO ()
main = display
  (InWindow "Привет" (400, 400) (100, 100))  -- окно
  white                                        -- фон
  (Circle 100)                                 -- картинка
```

Пример посложнее — цветной квадрат:

```haskell
picture :: Picture
picture = Pictures
  [ Color red   (Translate (-50)   50  (RectangleSolid 80 80))
  , Color blue  (Translate   50    50  (RectangleSolid 80 80))
  , Color green (Translate (-50) (-50) (RectangleSolid 80 80))
  , Color (makeColorI 255 165 0 255) (Translate 50 (-50) (RectangleSolid 80 80))
  ]
```

### Режим 2: `animate` — анимация

```haskell
animate :: Display -> Color -> (Float -> Picture) -> IO ()
```

Функция получает время (в секундах) и возвращает картинку:

```haskell
main :: IO ()
main = animate (InWindow "Анимация" (400, 400) (100, 100)) white frame

frame :: Float -> Picture
frame t = Translate (100 * cos t) (100 * sin t) (Circle 20)
```

Круг движется по окружности.

### Режим 3: `simulate` — симуляция

```haskell
simulate :: Display -> Color -> Int
          -> model                          -- начальное состояние
          -> (model -> Picture)             -- рендеринг
          -> (ViewPort -> Float -> model -> model)  -- шаг симуляции
          -> IO ()
```

Мир описывается типом `model`, который обновляется на каждом кадре:

```haskell
data World = World { wx :: Float, wy :: Float, wvx :: Float, wvy :: Float }

step :: ViewPort -> Float -> World -> World
step _ dt (World x y vx vy) = World (x + vx * dt) (y + vy * dt) vx vy

render :: World -> Picture
render (World x y _ _) = Translate x y (Circle 10)

main :: IO ()
main = simulate
  (InWindow "Симуляция" (400, 400) (100, 100))
  white 60
  (World 0 0 50 30)
  render step
```

### Режим 4: `play` — интерактивная игра

```haskell
play :: Display -> Color -> Int
     -> world                                -- начальное состояние
     -> (world -> Picture)                   -- рендеринг
     -> (Event -> world -> world)            -- обработка событий
     -> (Float -> world -> world)            -- шаг по времени
     -> IO ()
```

Добавляется обработка клавиатуры и мыши:

```haskell
handleEvent :: Event -> World -> World
handleEvent (EventKey (SpecialKey KeyUp) Down _ _)    w = w { wvy = wvy w + 10 }
handleEvent (EventKey (SpecialKey KeyDown) Down _ _)  w = w { wvy = wvy w - 10 }
handleEvent (EventKey (SpecialKey KeyLeft) Down _ _)  w = w { wvx = wvx w - 10 }
handleEvent (EventKey (SpecialKey KeyRight) Down _ _) w = w { wvx = wvx w + 10 }
handleEvent _ w = w
```

## Чистая графика: вычисления без рендеринга

Ключевая идея: **логика отделена от рендеринга**. Функция `step` — чистая. Функция `render` — чистая. Только `display` / `simulate` / `play` выполняют IO.

Это позволяет тестировать логику без графической библиотеки:

```haskell
-- Тест отскакивающего мяча
it "мяч отражается от стены" $ do
  let state = BallState (95, 50) (10, 0)
  stepBall 100 100 1 state `shouldBe` BallState (95, 50) (-10, 0)
```

## Game of Life

Игра жизни Конвея — клеточный автомат с простыми правилами:

1. **Живая** клетка с 2 или 3 соседями **выживает**.
2. **Мёртвая** клетка с ровно 3 соседями **оживает**.
3. Все остальные **умирают**.

### Представление

Используем `Set (Int, Int)` — множество координат живых клеток. Это эффективно для разреженных сеток:

```haskell
import Data.Set (Set)
import Data.Set qualified as Set

type Grid = Set (Int, Int)
```

### Подсчёт соседей

```haskell
neighbors :: (Int, Int) -> [(Int, Int)]
neighbors (x, y) =
  [ (x + dx, y + dy)
  | dx <- [-1, 0, 1]
  , dy <- [-1, 0, 1]
  , (dx, dy) /= (0, 0)
  ]

countAlive :: Grid -> (Int, Int) -> Int
countAlive grid cell =
  length (filter (`Set.member` grid) (neighbors cell))
```

### Шаг симуляции

Кандидаты на жизнь — все живые клетки и их соседи:

```haskell
stepLife :: Grid -> Grid
stepLife grid =
  let candidates = Set.union grid allNeighborCells
      allNeighborCells = Set.fromList
        [ n | cell <- Set.toList grid, n <- neighbors cell ]
  in Set.filter (alive grid) candidates

alive :: Grid -> (Int, Int) -> Bool
alive grid cell =
  let n = countAlive grid cell
  in if Set.member cell grid
     then n == 2 || n == 3   -- выживание
     else n == 3             -- рождение
```

### Визуализация через `gloss`

```haskell
import Graphics.Gloss

cellSize :: Float
cellSize = 10

renderGrid :: Grid -> Picture
renderGrid grid = Pictures
  [ Translate (fromIntegral x * cellSize) (fromIntegral y * cellSize)
      (RectangleSolid cellSize cellSize)
  | (x, y) <- Set.toList grid
  ]
```

## Отскакивающий мяч

Мяч движется в прямоугольной области и отражается от стен:

```haskell
data BallState = BallState
  { ballPos :: (Double, Double)
  , ballVel :: (Double, Double)
  }

stepBall :: Double -> Double -> Double -> BallState -> BallState
stepBall width height dt (BallState (x, y) (vx, vy)) =
  let x'  = x + vx * dt
      y'  = y + vy * dt
      (x'', vx') = bounce 0 width  x' vx
      (y'', vy') = bounce 0 height y' vy
  in BallState (x'', y'') (vx', vy')

bounce :: Double -> Double -> Double -> Double -> (Double, Double)
bounce lo hi pos vel
  | pos < lo  = (lo + (lo - pos), negate vel)
  | pos > hi  = (hi - (pos - hi), negate vel)
  | otherwise = (pos, vel)
```

## Фракталы: кривая Коха

Кривая Коха — классический фрактал. Начинаем с отрезка и рекурсивно заменяем каждый сегмент четырьмя:

1. Разделить отрезок на три части: `p1 = lerp (1/3)`, `p2 = lerp (2/3)`.
2. Построить вершину равностороннего треугольника: `peak = rotatePt (π/3) p1 p2`.
3. Заменить отрезок на путь: start → p1 → peak → p2 → end.
4. Рекурсивно применить к каждому из 4 подсегментов.

```haskell
kochPoints :: Int -> Point -> Point -> [Point]
kochPoints 0 start end = [start, end]
kochPoints n start end =
  let p1   = lerp (1/3) start end
      p2   = lerp (2/3) start end
      peak = rotatePt (pi/3) p1 p2
  in    init (kochPoints (n-1) start p1)
     ++ init (kochPoints (n-1) p1 peak)
     ++ init (kochPoints (n-1) peak p2)
     ++ kochPoints (n-1) p2 end
```

На глубине `n` получаем `4^n + 1` точек. Снежинка Коха — три кривые на сторонах равностороннего треугольника.

## Упражнения

Решения пишите в `test/MySolutions.hs`. Проверяйте: `stack test`.

Модуль `Graphics` предоставляет типы `Point`, `Grid`, `BallState` и вспомогательные функции `lerp`, `rotatePt`, `distance`, а также примеры: `blinker`, `block`, `glider`.

1. **(Лёгкое)** Реализуйте `neighbors` и `countAlive` для Game of Life.

    ```haskell
    neighbors  :: (Int, Int) -> [(Int, Int)]
    countAlive :: Grid -> (Int, Int) -> Int
    ```

    `neighbors` — 8 соседних клеток (без самой клетки). `countAlive` — сколько из соседей живы.

2. **(Среднее)** Реализуйте `stepLife` — один шаг Game of Life.

    ```haskell
    stepLife :: Grid -> Grid
    ```

    *Подсказка:* кандидаты — объединение живых клеток и всех их соседей. Отфильтруйте по правилам Конвея.

3. **(Среднее)** Реализуйте `stepBall` — шаг симуляции отскакивающего мяча.

    ```haskell
    stepBall :: Double -> Double -> Double -> BallState -> BallState
    ```

    Мяч движется в прямоугольнике `(0,0)–(width, height)`. При выходе за границу — отражение и смена знака скорости.

4. **(Сложное)** Реализуйте `kochPoints` — генерацию точек кривой Коха.

    ```haskell
    kochPoints :: Int -> Point -> Point -> [Point]
    ```

    Используйте `lerp` для деления отрезка на трети и `rotatePt (pi/3)` для построения вершины. Рекурсия по 4 подсегментам; `init` убирает дублирующуюся точку на стыке.

## Заключение

В этой главе мы:

- Познакомились с `gloss`: `display`, `animate`, `simulate`, `play`.
- Разделили логику и рендеринг — логика чистая и тестируемая.
- Реализовали Game of Life через `Set`-множество.
- Создали физику отскакивающего мяча с отражением.
- Построили фрактал Коха рекурсивной генерацией точек.

В следующей главе мы займёмся генеративным тестированием с QuickCheck.
