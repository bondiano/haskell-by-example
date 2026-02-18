module Solutions where

-- | Диагональ прямоугольника по теореме Пифагора.
diagonal :: Double -> Double -> Double
diagonal w h = sqrt (w * w + h * h)

-- | Площадь круга по радиусу.
circleArea :: Double -> Double
circleArea r = pi * r * r

-- | Длина последовательности Коллатца для заданного числа.
-- collatzLength 6 → 6 → 3 → 10 → 5 → 16 → 8 → 4 → 2 → 1 → 8 шагов
collatzLength :: Int -> Int
collatzLength 1 = 0
collatzLength n
  | even n    = 1 + collatzLength (n `div` 2)
  | otherwise = 1 + collatzLength (3 * n + 1)
