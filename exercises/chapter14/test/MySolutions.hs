module MySolutions where

import Test.QuickCheck
import Data.List (sort)
import Data.MergeSort (mergeSort, merge, sorted)
import Data.BST (BST(..), insert, member, toAscList, fromList, valid)
import Data.Person (Person(..), encodePerson, decodePerson)

-- ============================================================
-- Упражнение 1: Свойства сортировки слиянием
--
-- Реализуйте три свойства функции mergeSort.
-- Каждое свойство принимает произвольный список [Int] и возвращает Bool.
-- QuickCheck сгенерирует случайные списки и проверит, что свойство
-- выполняется для каждого из них.
-- ============================================================

-- | Сортировка не меняет длину списка.
prop_sortPreservesLength :: [Int] -> Bool
prop_sortPreservesLength xs = undefined

-- | Результат сортировки упорядочен (используйте функцию sorted из Data.MergeSort).
prop_sortOrdered :: [Int] -> Bool
prop_sortOrdered xs = undefined

-- | Сортировка идемпотентна: повторная сортировка не меняет результат.
prop_sortIdempotent :: [Int] -> Bool
prop_sortIdempotent xs = undefined

-- ============================================================
-- Упражнение 2: Генератор BST и свойства
--
-- Напишите генератор бинарного дерева поиска и два свойства.
-- Используйте forAll для подключения генератора к свойствам.
--
-- Подсказка: самый простой способ создать BST — сгенерировать
-- список и построить дерево через fromList.
-- ============================================================

-- | Генератор корректного BST с элементами типа Int.
genBST :: Gen (BST Int)
genBST = undefined

-- | Все деревья из генератора удовлетворяют инварианту BST.
prop_genBSTValid :: Property
prop_genBSTValid = undefined

-- | После insert x в дерево, member x возвращает True.
prop_insertMember :: Property
prop_insertMember = undefined

-- ============================================================
-- Упражнение 3: Round-trip тестирование
--
-- Напишите генератор Person и свойство round-trip для encodePerson/decodePerson.
--
-- Важно: имя не должно содержать символ ';' (это разделитель в encodePerson).
-- Используйте listOf и elements для генерации допустимых символов.
-- ============================================================

-- | Генератор Person с корректным именем (без символа ';').
genPerson :: Gen Person
genPerson = undefined

-- | decodePerson (encodePerson p) == Just p для всех корректных Person.
prop_encodeDecodeRoundTrip :: Property
prop_encodeDecodeRoundTrip = undefined

-- ============================================================
-- Упражнение 4 (продвинутое): Слияние отсортированных списков
--
-- Напишите свойство для функции merge с использованием:
--   - forAll для подключения генератора отсортированных списков
--   - classify для отслеживания распределения входных данных
--
-- Подсказка: отсортированный список можно получить так:
--   sort <$> arbitrary  или  sort <$> listOf arbitrary
-- ============================================================

-- | Слияние двух отсортированных списков даёт отсортированный список.
-- Используйте classify для разделения на категории:
--   - "один список пуст" — когда хотя бы один список пуст
--   - "большой вход"     — когда суммарная длина > 20
prop_mergeOrdered :: Property
prop_mergeOrdered = undefined
