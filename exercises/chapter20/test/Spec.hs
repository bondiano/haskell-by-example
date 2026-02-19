module Main where

import Control.Lens
import Data.Text (Text)
import Data.Text qualified as T
import Test.Hspec

import MySolutions (
  allTags,
  completeHighPriority,
  getPoolMax,
  incrementMaybe,
  poolMaxSizeL,
  productionConfig,
  setPoolMax,
  uppercaseError,
 )
import TaskTracker

main :: IO ()
main = hspec $ do
  -- Тестовые данные
  let task1 = Task "Купить молоко" Low Todo ["дом", "покупки"]
      task2 = Task "Написать отчёт" High InProgress ["работа"]
      task3 = Task "Полить цветы" Medium Done ["дом"]
      task4 = Task "Подготовить презентацию" High Todo ["работа", "важное"]
      tasks = [task1, task2, task3, task4]

  describe "Упражнение 1: getPoolMax и setPoolMax" $ do
    it "getPoolMax defaultConfig == 5" $
      getPoolMax defaultConfig `shouldBe` 5

    it "setPoolMax 20 — меняет poolMaxSize" $
      getPoolMax (setPoolMax 20 defaultConfig) `shouldBe` 20

    it "setPoolMax не меняет другие поля" $ do
      let cfg = setPoolMax 20 defaultConfig
      cfg ^. configPort `shouldBe` 8080
      cfg ^. configDb . dbHost `shouldBe` "localhost"
      cfg ^. configDb . dbPool . poolTimeout `shouldBe` 30

    it "setPoolMax 0" $
      getPoolMax (setPoolMax 0 defaultConfig) `shouldBe` 0

    it "setPoolMax 100" $
      getPoolMax (setPoolMax 100 defaultConfig) `shouldBe` 100

  describe "Упражнение 2: productionConfig" $ do
    it "poolMaxSize == 20" $
      productionConfig defaultConfig ^. configDb . dbPool . poolMaxSize
        `shouldBe` 20

    it "configPort == 443" $
      productionConfig defaultConfig ^. configPort
        `shouldBe` 443

    it "notifyEnabled == True" $
      productionConfig defaultConfig ^. configNotify . notifyEnabled
        `shouldBe` True

    it "не меняет dbHost" $
      productionConfig defaultConfig ^. configDb . dbHost
        `shouldBe` "localhost"

    it "не меняет dbPort" $
      productionConfig defaultConfig ^. configDb . dbPort
        `shouldBe` 5432

    it "не меняет poolTimeout" $
      productionConfig defaultConfig ^. configDb . dbPool . poolTimeout
        `shouldBe` 30

  describe "Упражнение 3: completeHighPriority" $ do
    it "задачи с High приоритетом получают статус Done" $ do
      let result = completeHighPriority tasks
      (result !! 1) ^. taskStatus `shouldBe` Done -- task2: High
      (result !! 3) ^. taskStatus `shouldBe` Done -- task4: High
    it "задачи с не-High приоритетом не меняются" $ do
      let result = completeHighPriority tasks
      head result ^. taskStatus `shouldBe` Todo -- task1: Low
      (result !! 2) ^. taskStatus `shouldBe` Done -- task3: Medium, уже Done
    it "заголовки и теги не меняются" $ do
      let result = completeHighPriority tasks
      (result !! 1) ^. taskTitle `shouldBe` "Написать отчёт"
      (result !! 1) ^. taskTags `shouldBe` ["работа"]

    it "пустой список — пустой результат" $
      completeHighPriority [] `shouldBe` []

  describe "Упражнение 4: poolMaxSizeL (ручная линза)" $ do
    it "view через ручную линзу" $
      view poolMaxSizeL (PoolConfig 10 30) `shouldBe` 10

    it "set через ручную линзу" $
      set poolMaxSizeL 42 (PoolConfig 10 30) `shouldBe` PoolConfig 42 30

    it "over через ручную линзу" $
      over poolMaxSizeL (+ 5) (PoolConfig 10 30) `shouldBe` PoolConfig 15 30

    it "не меняет poolTimeout" $
      set poolMaxSizeL 99 (PoolConfig 10 30) ^. poolTimeout `shouldBe` 30

    it "view совпадает с TH-линзой" $
      view poolMaxSizeL (PoolConfig 7 20) `shouldBe` view poolMaxSize (PoolConfig 7 20)

    it "set совпадает с TH-линзой" $
      set poolMaxSizeL 50 (PoolConfig 7 20) `shouldBe` set poolMaxSize 50 (PoolConfig 7 20)

  describe "Упражнение 5: призмы" $ do
    it "incrementMaybe (Just 5) == Just 6" $
      incrementMaybe (Just 5) `shouldBe` Just 6

    it "incrementMaybe (Just 0) == Just 1" $
      incrementMaybe (Just 0) `shouldBe` Just 1

    it "incrementMaybe (Just (-1)) == Just 0" $
      incrementMaybe (Just (-1)) `shouldBe` Just 0

    it "incrementMaybe Nothing == Nothing" $
      incrementMaybe Nothing `shouldBe` Nothing

    it "uppercaseError (Left \"err\") == Left \"ERR\"" $
      uppercaseError (Left "err") `shouldBe` (Left "ERR" :: Either Text Int)

    it "uppercaseError (Left \"hello world\") == Left \"HELLO WORLD\"" $
      uppercaseError (Left "hello world") `shouldBe` (Left "HELLO WORLD" :: Either Text Int)

    it "uppercaseError (Right 42) == Right 42" $
      uppercaseError (Right 42) `shouldBe` (Right 42 :: Either Text Int)

    it "uppercaseError (Left \"\") == Left \"\"" $
      uppercaseError (Left "") `shouldBe` (Left "" :: Either Text Int)

  describe "Упражнение 6: allTags" $ do
    it "извлекает все теги из списка задач" $
      allTags tasks `shouldBe` ["дом", "покупки", "работа", "дом", "работа", "важное"]

    it "пустой список — пустые теги" $
      allTags [] `shouldBe` []

    it "задача без тегов не добавляет ничего" $
      allTags [Task "Тест" Low Todo []] `shouldBe` []

    it "одна задача с одним тегом" $
      allTags [Task "Тест" Low Todo ["один"]] `shouldBe` ["один"]
