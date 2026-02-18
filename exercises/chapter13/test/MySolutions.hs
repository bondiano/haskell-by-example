module MySolutions where

import Data.Set (Set)
import Data.Set qualified as Set

import Graphics

-- Упражнение 1: соседи клетки и подсчёт живых
--
-- neighbors возвращает 8 соседей клетки (по горизонтали, вертикали и диагонали).
-- countAlive считает количество живых соседей клетки в сетке.

neighbors :: (Int, Int) -> [(Int, Int)]
neighbors = undefined

countAlive :: Grid -> (Int, Int) -> Int
countAlive = undefined

-- Упражнение 2: шаг Game of Life
--
-- Правила Конвея:
-- 1. Живая клетка с 2 или 3 живыми соседями выживает.
-- 2. Мёртвая клетка с ровно 3 живыми соседями оживает.
-- 3. Все остальные клетки умирают или остаются мёртвыми.
--
-- Подсказка: кандидаты на оживление — все соседи живых клеток.
-- Используйте neighbors и countAlive из упражнения 1.

stepLife :: Grid -> Grid
stepLife = undefined

-- Упражнение 3: отскакивающий мяч
--
-- Мяч движется в прямоугольной области от (0,0) до (width, height).
-- На каждом шаге: новая позиция = позиция + скорость * dt.
-- Если мяч выходит за границу — он отражается, скорость по этой оси
-- меняет знак.
--
-- Параметры: width, height, dt (шаг времени).

stepBall :: Double -> Double -> Double -> BallState -> BallState
stepBall = undefined

-- Упражнение 4: кривая Коха
--
-- Рекурсивно порождает точки кривой Коха между start и end на глубине n.
-- Глубина 0: [start, end] (2 точки).
-- Глубина 1: [start, p1, peak, p2, end] (5 точек), где
--   p1 = lerp (1/3) start end
--   p2 = lerp (2/3) start end
--   peak = rotatePt (pi/3) p1 p2
-- Глубина n: рекурсия на 4 подсегментах (start→p1, p1→peak, peak→p2, p2→end).
--
-- Количество точек: 4^n + 1.
-- Подсказка: используйте init для удаления последней точки перед конкатенацией,
-- чтобы не дублировать точки на стыках.

kochPoints :: Int -> Point -> Point -> [Point]
kochPoints = undefined
