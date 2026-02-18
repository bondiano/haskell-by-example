module Graphics
  ( -- * Типы
    Point
  , Grid
  , BallState(..)
    -- * Геометрия
  , lerp
  , rotatePt
  , distance
    -- * Game of Life — примеры
  , gridFromList
  , gridToList
  , blinker
  , block
  , glider
  ) where

import Data.Set (Set)
import Data.Set qualified as Set

-- | Точка на плоскости.
type Point = (Double, Double)

-- | Сетка Game of Life — множество живых клеток.
type Grid = Set (Int, Int)

-- | Состояние отскакивающего мяча.
data BallState = BallState
  { ballPos :: !Point    -- ^ позиция (x, y)
  , ballVel :: !Point    -- ^ скорость (vx, vy)
  } deriving stock (Show, Eq)

-- | Линейная интерполяция: @lerp t a b@ — точка на @t@ пути от @a@ к @b@.
--
-- >>> lerp 0.5 (0, 0) (10, 0)
-- (5.0, 0.0)
lerp :: Double -> Point -> Point -> Point
lerp t (x1, y1) (x2, y2) = (x1 + t * (x2 - x1), y1 + t * (y2 - y1))

-- | Повернуть точку вокруг центра на заданный угол (в радианах).
--
-- >>> rotatePt (pi/2) (0, 0) (1, 0)
-- (6.123233995736766e-17, 1.0)   -- ≈ (0, 1)
rotatePt :: Double -> Point -> Point -> Point
rotatePt angle (cx, cy) (px, py) =
  let dx  = px - cx
      dy  = py - cy
      cos' = cos angle
      sin' = sin angle
  in (cx + dx * cos' - dy * sin', cy + dx * sin' + dy * cos')

-- | Расстояние между двумя точками.
--
-- >>> distance (0, 0) (3, 4)
-- 5.0
distance :: Point -> Point -> Double
distance (x1, y1) (x2, y2) = sqrt ((x2 - x1) ^ (2 :: Int) + (y2 - y1) ^ (2 :: Int))

-- | Создать сетку из списка координат.
gridFromList :: [(Int, Int)] -> Grid
gridFromList = Set.fromList

-- | Список живых клеток.
gridToList :: Grid -> [(Int, Int)]
gridToList = Set.toList

-- | Блинкер (период 2): вертикальная линия из 3 клеток.
--
-- @
-- .X.
-- .X.
-- .X.
-- @
blinker :: Grid
blinker = gridFromList [(0, -1), (0, 0), (0, 1)]

-- | Блок (still life): квадрат 2×2.
--
-- @
-- XX
-- XX
-- @
block :: Grid
block = gridFromList [(0, 0), (1, 0), (0, 1), (1, 1)]

-- | Глайдер: движется по диагонали.
--
-- @
-- .X.
-- ..X
-- XXX
-- @
glider :: Grid
glider = gridFromList [(1, 0), (2, 1), (0, 2), (1, 2), (2, 2)]
