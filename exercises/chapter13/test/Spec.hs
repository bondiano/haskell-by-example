module Main where

import Test.Hspec
import Data.Set qualified as Set

import Graphics
import MySolutions

main :: IO ()
main = hspec $ do
  describe "lerp / rotatePt (предоставлено)" $ do
    it "lerp 0.5 — середина отрезка" $
      lerp 0.5 (0, 0) (10, 0) `shouldBe` (5.0, 0.0)

    it "distance 3-4-5" $
      distance (0, 0) (3, 4) `shouldBe` 5.0

  describe "neighbors / countAlive (упражнение 1)" $ do
    it "у клетки 8 соседей" $
      length (neighbors (0, 0)) `shouldBe` 8

    it "соседи не включают саму клетку" $
      (0, 0) `notElem` neighbors (0, 0) `shouldBe` True

    it "соседи (1,1) содержат (0,0)" $
      (0, 0) `elem` neighbors (1, 1) `shouldBe` True

    it "countAlive для центра блока" $
      countAlive block (0, 0) `shouldBe` 3

    it "countAlive для изолированной клетки" $
      countAlive (gridFromList [(5, 5)]) (5, 5) `shouldBe` 0

    it "countAlive для мёртвой клетки рядом с блинкером" $
      countAlive blinker (1, 0) `shouldBe` 3

  describe "stepLife (упражнение 2)" $ do
    it "блок стабилен" $
      stepLife block `shouldBe` block

    it "блинкер осциллирует (период 2)" $ do
      let step1 = stepLife blinker
      step1 `shouldBe` gridFromList [(-1, 0), (0, 0), (1, 0)]
      stepLife step1 `shouldBe` blinker

    it "пустая сетка остаётся пустой" $
      stepLife Set.empty `shouldBe` Set.empty

    it "одиночная клетка умирает" $
      stepLife (gridFromList [(0, 0)]) `shouldBe` Set.empty

    it "глайдер сдвигается за 4 шага" $ do
      let step4 = iterate stepLife glider !! 4
      step4 `shouldBe` gridFromList [(2, 1), (3, 2), (1, 3), (2, 3), (3, 3)]

  describe "stepBall (упражнение 3)" $ do
    it "мяч движется по скорости" $ do
      let state = BallState (50, 50) (10, 5)
      stepBall 100 100 1 state `shouldBe` BallState (60, 55) (10, 5)

    it "отражение от правой стены" $ do
      let state = BallState (95, 50) (10, 0)
      stepBall 100 100 1 state `shouldBe` BallState (95, 50) (-10, 0)

    it "отражение от нижней стены" $ do
      let state = BallState (50, 5) (0, -10)
      stepBall 100 100 1 state `shouldBe` BallState (50, 5) (0, 10)

    it "отражение от левой стены" $ do
      let state = BallState (3, 50) (-5, 0)
      stepBall 100 100 1 state `shouldBe` BallState (2, 50) (5, 0)

    it "без движения при dt=0" $ do
      let state = BallState (50, 50) (100, 100)
      stepBall 100 100 0 state `shouldBe` state

  describe "kochPoints (упражнение 4)" $ do
    it "глубина 0 — 2 точки" $
      length (kochPoints 0 (0, 0) (9, 0)) `shouldBe` 2

    it "глубина 1 — 5 точек" $
      length (kochPoints 1 (0, 0) (9, 0)) `shouldBe` 5

    it "глубина 2 — 17 точек" $
      length (kochPoints 2 (0, 0) (9, 0)) `shouldBe` 17

    it "глубина 3 — 65 точек (4^3 + 1)" $
      length (kochPoints 3 (0, 0) (9, 0)) `shouldBe` 65

    it "первая точка = start" $
      head (kochPoints 3 (0, 0) (9, 0)) `shouldBe` (0, 0)

    it "последняя точка = end" $
      last (kochPoints 3 (0, 0) (9, 0)) `shouldBe` (9, 0)

    it "на глубине 1 пик выше оси x" $ do
      let pts = kochPoints 1 (0, 0) (9, 0)
      let (_, peakY) = pts !! 2
      peakY `shouldSatisfy` (> 0)
