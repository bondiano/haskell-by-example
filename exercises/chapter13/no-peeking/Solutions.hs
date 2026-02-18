module Solutions where

import Data.Set (Set)
import Data.Set qualified as Set

import Graphics

-- Упражнение 1: соседи клетки и подсчёт живых

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

-- Упражнение 2: шаг Game of Life

stepLife :: Grid -> Grid
stepLife grid =
  let candidates = Set.union grid allNeighborCells
      allNeighborCells = Set.fromList
        [ n | cell <- Set.toList grid, n <- neighbors cell ]
  in Set.filter (survives grid) candidates

survives :: Grid -> (Int, Int) -> Bool
survives grid cell =
  let n = countAlive grid cell
  in if Set.member cell grid
     then n == 2 || n == 3
     else n == 3

-- Упражнение 3: отскакивающий мяч

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

-- Упражнение 4: кривая Коха

kochPoints :: Int -> Point -> Point -> [Point]
kochPoints 0 start end = [start, end]
kochPoints n start end =
  let p1   = lerp (1 / 3) start end
      p2   = lerp (2 / 3) start end
      peak = rotatePt (pi / 3) p1 p2
  in    init (kochPoints (n - 1) start p1)
     ++ init (kochPoints (n - 1) p1 peak)
     ++ init (kochPoints (n - 1) peak p2)
     ++ kochPoints (n - 1) p2 end
