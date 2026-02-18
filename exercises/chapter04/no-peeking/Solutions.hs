module Solutions where

import Data.Picture

-- | Площадь фигуры. Площадь линии и текста равна нулю.
area :: Shape -> Double
area (Circle _ r)      = pi * r * r
area (Rectangle _ w h) = w * h
area (Line _ _)        = 0
area (Text _ _)        = 0

-- | Масштабирование фигуры: все координаты и размеры умножаются на коэффициент.
scale :: Double -> Shape -> Shape
scale k (Circle (Point cx cy) r)      = Circle (Point (cx * k) (cy * k)) (r * k)
scale k (Rectangle (Point x y) w h)   = Rectangle (Point (x * k) (y * k)) (w * k) (h * k)
scale k (Line (Point x1 y1) (Point x2 y2)) = Line (Point (x1 * k) (y1 * k)) (Point (x2 * k) (y2 * k))
scale k (Text (Point x y) s)          = Text (Point (x * k) (y * k)) s

-- | Извлечение текста из фигуры.
shapeText :: Shape -> Maybe String
shapeText (Text _ s) = Just s
shapeText _          = Nothing
