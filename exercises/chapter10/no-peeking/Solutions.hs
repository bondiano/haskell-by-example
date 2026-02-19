{-# HLINT ignore "Redundant reverse" #-}
module Solutions where

import Data.List (isSubsequenceOf, sort)
import Data.Map.Strict qualified as Map
import Test.Hspec
import Test.QuickCheck

import TaskTracker

-- ============================================================
-- Упражнение 1: addTaskSpec
-- ============================================================

{- | Тесты для addTask.
Проверяем, что после добавления задачи:
  1. lookupTask находит её по идентификатору
  2. storeSize увеличивается на 1 (для нового ключа)
-}
addTaskSpec :: Spec
addTaskSpec = do
  let task = Task "Тестовая задача" Medium Todo
      store = addTask (TaskId 1) task emptyStore

  it "lookupTask находит добавленную задачу" $
    lookupTask (TaskId 1) store `shouldBe` Just task

  it "storeSize увеличивается на 1" $
    storeSize store `shouldBe` 1

  it "добавление второй задачи — размер 2" $ do
    let store2 = addTask (TaskId 2) (Task "Вторая" High Todo) store
    storeSize store2 `shouldBe` 2

  it "перезапись ключа не увеличивает размер" $ do
    let store2 = addTask (TaskId 1) (Task "Обновлённая" Low Done) store
    storeSize store2 `shouldBe` 1

-- ============================================================
-- Упражнение 2: filterTasksSpec
-- ============================================================

-- | Тесты для filterTasks с конкретными примерами.
filterTasksSpec :: Spec
filterTasksSpec = do
  let tasks =
        [ Task "Задача 1" High Todo
        , Task "Задача 2" Low Done
        , Task "Задача 3" Medium Todo
        , Task "Задача 4" High Done
        ]

  it "ByStatus Todo — только задачи со статусом Todo" $
    filterTasks (ByStatus Todo) tasks
      `shouldBe` [Task "Задача 1" High Todo, Task "Задача 3" Medium Todo]

  it "ByPriority High — только задачи с приоритетом High" $
    filterTasks (ByPriority High) tasks
      `shouldBe` [Task "Задача 1" High Todo, Task "Задача 4" High Done]

  it "AllTasks — все задачи без фильтрации" $
    filterTasks AllTasks tasks `shouldBe` tasks

  it "ByStatus InProgress — пустой результат, если нет таких" $
    filterTasks (ByStatus InProgress) tasks `shouldBe` []

-- ============================================================
-- Упражнение 3: trackerProperties
-- ============================================================

-- | QuickCheck-свойства для TaskStore.
trackerProperties :: Spec
trackerProperties = do
  it "addTask увеличивает размер на 1 (новый ключ)" $
    property $ \(Positive n) ->
      let tid = TaskId n
          task = Task "Тест" Medium Todo
          store = emptyStore
       in storeSize (addTask tid task store) == storeSize store + 1

  it "removeTask после addTask — исходное хранилище" $
    property $ \(Positive n) ->
      let tid = TaskId n
          task = Task "Тест" Medium Todo
       in removeTask tid (addTask tid task emptyStore) == emptyStore

  it "filterTasks AllTasks == id" $
    property $ \tasks ->
      filterTasks AllTasks (tasks :: [Task]) == tasks

-- ============================================================
-- Упражнение 4: reverseSpec
-- ============================================================

-- | Тесты для reverse.
reverseSpec :: Spec
reverseSpec = do
  it "reverse пустого списка" $
    reverse ([] :: [Int]) `shouldBe` []

  it "reverse одноэлементного списка" $
    reverse [42 :: Int] `shouldBe` [42]

  it "reverse многоэлементного списка" $
    reverse [1 :: Int, 2, 3] `shouldBe` [3, 2, 1]

  it "reverse . reverse == id" $
    reverse (reverse [1 :: Int, 2, 3, 4, 5]) `shouldBe` [1, 2, 3, 4, 5]

-- ============================================================
-- Упражнение 5: lookupSpec
-- ============================================================

-- | Тесты для Map.lookup.
lookupSpec :: Spec
lookupSpec = do
  let m = Map.fromList [("a" :: String, 1 :: Int), ("b", 2), ("c", 3)]

  it "находит существующий ключ" $
    Map.lookup "a" m `shouldBe` Just 1

  it "Nothing для отсутствующего ключа" $
    Map.lookup "z" m `shouldBe` Nothing

  it "Nothing в пустой Map" $
    Map.lookup "a" (Map.empty :: Map.Map String Int) `shouldBe` Nothing

-- ============================================================
-- Упражнение 6: Arbitrary инстансы и свойство фильтрации
-- ============================================================

{- | Arbitrary для Priority — выбираем из всех конструкторов.
arbitraryBoundedEnum использует Enum + Bounded.
-}
instance Arbitrary Priority where
  arbitrary = arbitraryBoundedEnum

-- | Arbitrary для Status.
instance Arbitrary Status where
  arbitrary = arbitraryBoundedEnum

{- | Arbitrary для Task — генерируем случайное название,
приоритет и статус.
-}
instance Arbitrary Task where
  arbitrary =
    Task
      <$> listOf (elements ['a' .. 'z'])
      <*> arbitrary
      <*> arbitrary

-- | Arbitrary для TaskFilter.
instance Arbitrary TaskFilter where
  arbitrary =
    oneof
      [ pure AllTasks
      , ByStatus <$> arbitrary
      , ByPriority <$> arbitrary
      ]

{- | Результат фильтрации — подмножество входного списка.
Каждый элемент результата должен присутствовать во входе.
-}
prop_filterSubset :: TaskFilter -> [Task] -> Bool
prop_filterSubset tf tasks =
  all (`elem` tasks) (filterTasks tf tasks)

-- ============================================================
-- Упражнение 7: Свойства сортировки
-- ============================================================

-- | Отсортированный список упорядочен: каждый элемент <= следующего.
prop_sortOrdered :: [Int] -> Bool
prop_sortOrdered xs =
  let sorted = sort xs
   in and $ zipWith (<=) sorted (drop 1 sorted)

-- | Идемпотентность: повторная сортировка не меняет результат.
prop_sortIdempotent :: [Int] -> Bool
prop_sortIdempotent xs = sort (sort xs) == sort xs
