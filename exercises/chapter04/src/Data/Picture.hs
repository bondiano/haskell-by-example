module Data.Picture where

-- | Точка на плоскости.
data Point = Point Double Double
  deriving (Show, Eq)

-- | Начало координат.
origin :: Point
origin = Point 0.0 0.0

-- | Геометрическая фигура.
data Shape
  = Circle Point Double           -- ^ центр, радиус
  | Rectangle Point Double Double -- ^ левый нижний угол, ширина, высота
  | Line Point Point              -- ^ начало, конец
  | Text Point String             -- ^ позиция, текст
  deriving (Show, Eq)

-- | Коллекция фигур.
type Picture = [Shape]

showPoint :: Point -> String
showPoint (Point x y) = "(" <> show x <> ", " <> show y <> ")"

showShape :: Shape -> String
showShape (Circle c r)      = "Circle [center: " <> showPoint c <> ", radius: " <> show r <> "]"
showShape (Rectangle p w h) = "Rectangle [" <> showPoint p <> ", " <> show w <> " × " <> show h <> "]"
showShape (Line start end)  = "Line [" <> showPoint start <> " → " <> showPoint end <> "]"
showShape (Text p s)        = "Text [" <> showPoint p <> ": " <> show s <> "]"

showPicture :: Picture -> String
showPicture = unlines . map showShape

-- | Ограничивающий прямоугольник.
data Bounds = Bounds
  { minX :: Double
  , minY :: Double
  , maxX :: Double
  , maxY :: Double
  } deriving (Show, Eq)

emptyBounds :: Bounds
emptyBounds = Bounds
  { minX = inf, minY = inf
  , maxX = -inf, maxY = -inf
  }
  where inf = 1 / 0

unionBounds :: Bounds -> Bounds -> Bounds
unionBounds b1 b2 = Bounds
  { minX = min (minX b1) (minX b2)
  , minY = min (minY b1) (minY b2)
  , maxX = max (maxX b1) (maxX b2)
  , maxY = max (maxY b1) (maxY b2)
  }

shapeBounds :: Shape -> Bounds
shapeBounds (Circle (Point cx cy) r) = Bounds
  { minX = cx - r, minY = cy - r
  , maxX = cx + r, maxY = cy + r
  }
shapeBounds (Rectangle (Point x y) w h) = Bounds
  { minX = x, minY = y
  , maxX = x + w, maxY = y + h
  }
shapeBounds (Line (Point x1 y1) (Point x2 y2)) = Bounds
  { minX = min x1 x2, minY = min y1 y2
  , maxX = max x1 x2, maxY = max y1 y2
  }
shapeBounds (Text (Point x y) _) = Bounds
  { minX = x, minY = y
  , maxX = x, maxY = y
  }

-- | Ограничивающий прямоугольник для всей картинки.
bounds :: Picture -> Bounds
bounds = foldl combine emptyBounds
  where
    combine acc shape = unionBounds acc (shapeBounds shape)
