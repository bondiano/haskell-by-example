module MySolutions where

import Data.List (isSubsequenceOf, sort)
import Data.Map.Strict qualified as Map
import Test.Hspec
import Test.QuickCheck

import TaskTracker

-- ============================================================
-- Упражнение 1: addTaskSpec
--
-- Напишите тесты для функции addTask:
--   - после добавления задачи lookupTask находит её
--   - после добавления storeSize увеличивается на 1
--     (при условии, что ключ новый)
-- ============================================================

addTaskSpec :: Spec
addTaskSpec = undefined

-- ============================================================
-- Упражнение 2: filterTasksSpec
--
-- Напишите тесты для функции filterTasks:
--   - ByStatus фильтрует по статусу
--   - ByPriority фильтрует по приоритету
--   - AllTasks возвращает все задачи
-- Минимум 3 теста.
-- ============================================================

filterTasksSpec :: Spec
filterTasksSpec = undefined

-- ============================================================
-- Упражнение 3: trackerProperties (QuickCheck)
--
-- Напишите свойства:
--   - addTask увеличивает размер на 1 (для нового ключа)
--   - removeTask после addTask возвращает исходное хранилище
--     (если ключ до этого отсутствовал)
--   - filterTasks AllTasks возвращает тот же список
-- ============================================================

trackerProperties :: Spec
trackerProperties = undefined

-- ============================================================
-- Упражнение 4: reverseSpec
--
-- Напишите тесты для стандартной функции reverse:
--   - reverse пустого списка
--   - reverse одноэлементного списка
--   - reverse многоэлементного списка
-- ============================================================

reverseSpec :: Spec
reverseSpec = undefined

-- ============================================================
-- Упражнение 5: lookupSpec
--
-- Напишите тесты для Map.lookup:
--   - поиск существующего ключа
--   - поиск отсутствующего ключа
--   - поиск в пустой Map
-- ============================================================

lookupSpec :: Spec
lookupSpec = undefined

-- ============================================================
-- Упражнение 6: Arbitrary инстансы и свойство фильтрации
--
-- Определите Arbitrary инстансы для Priority, Status,
-- Task и TaskFilter.
--
-- Затем напишите свойство: результат filterTasks —
-- всегда подмножество входного списка.
-- ============================================================

instance Arbitrary Priority where
  arbitrary = undefined

instance Arbitrary Status where
  arbitrary = undefined

instance Arbitrary Task where
  arbitrary = undefined

instance Arbitrary TaskFilter where
  arbitrary = undefined

-- | Результат фильтрации — подмножество входного списка.
prop_filterSubset :: TaskFilter -> [Task] -> Bool
prop_filterSubset = undefined

-- ============================================================
-- Упражнение 7: Свойства сортировки
--
-- prop_sortOrdered    — отсортированный список упорядочен
-- prop_sortIdempotent — повторная сортировка не меняет результат
-- ============================================================

-- | Отсортированный список упорядочен.
prop_sortOrdered :: [Int] -> Bool
prop_sortOrdered = undefined

-- | sort . sort == sort (идемпотентность).
prop_sortIdempotent :: [Int] -> Bool
prop_sortIdempotent = undefined
