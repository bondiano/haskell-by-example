module Main where

import Test.Hspec
import Data.Picture
import MySolutions (area, scale, shapeText)

main :: IO ()
main = hspec $ do
  describe "showShape" $ do
    it "отображает круг" $
      showShape (Circle origin 5.0)
        `shouldBe` "Circle [center: (0.0, 0.0), radius: 5.0]"

    it "отображает линию" $
      showShape (Line (Point 1 2) (Point 3 4))
        `shouldBe` "Line [(1.0, 2.0) \8594 (3.0, 4.0)]"

  describe "shapeBounds" $ do
    it "вычисляет границы круга" $
      shapeBounds (Circle (Point 5 5) 3)
        `shouldBe` Bounds { minX = 2, minY = 2, maxX = 8, maxY = 8 }

    it "вычисляет границы прямоугольника" $
      shapeBounds (Rectangle (Point 1 1) 4 3)
        `shouldBe` Bounds { minX = 1, minY = 1, maxX = 5, maxY = 4 }

  describe "bounds" $ do
    it "вычисляет границы картинки" $ do
      let pic = [Circle origin 1, Rectangle (Point 2 2) 3 3]
      bounds pic `shouldBe` Bounds { minX = -1, minY = -1, maxX = 5, maxY = 5 }

  describe "area" $ do
    it "площадь круга с радиусом 10" $
      area (Circle origin 10) `shouldSatisfy` (\a -> abs (a - 100 * pi) < 1e-9)

    it "площадь прямоугольника 3×4" $
      area (Rectangle origin 3 4) `shouldBe` 12.0

    it "площадь линии равна 0" $
      area (Line origin (Point 5 5)) `shouldBe` 0.0

    it "площадь текста равна 0" $
      area (Text origin "hello") `shouldBe` 0.0

  describe "scale" $ do
    it "масштабирует круг" $
      scale 2 (Circle (Point 1 1) 5) `shouldBe` Circle (Point 2 2) 10

    it "масштабирует прямоугольник" $
      scale 3 (Rectangle (Point 1 2) 4 5) `shouldBe` Rectangle (Point 3 6) 12 15

    it "масштабирует линию" $
      scale 2 (Line (Point 1 1) (Point 3 4))
        `shouldBe` Line (Point 2 2) (Point 6 8)

    it "текст не масштабируется (только позиция)" $
      scale 2 (Text (Point 3 4) "hi") `shouldBe` Text (Point 6 8) "hi"

  describe "shapeText" $ do
    it "извлекает текст из Text" $
      shapeText (Text origin "hello") `shouldBe` Just "hello"

    it "возвращает Nothing для Circle" $
      shapeText (Circle origin 5) `shouldBe` Nothing

    it "возвращает Nothing для Rectangle" $
      shapeText (Rectangle origin 3 4) `shouldBe` Nothing
