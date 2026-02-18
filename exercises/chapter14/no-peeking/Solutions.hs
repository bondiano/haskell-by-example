module Solutions where

import Test.QuickCheck
import Data.List (sort)
import Data.MergeSort (mergeSort, merge, sorted)
import Data.BST (BST(..), insert, member, toAscList, fromList, valid)
import Data.Person (Person(..), encodePerson, decodePerson)

-- Упражнение 1: Свойства сортировки слиянием

-- | Сортировка не меняет длину списка.
prop_sortPreservesLength :: [Int] -> Bool
prop_sortPreservesLength xs = length (mergeSort xs) == length xs

-- | Результат сортировки упорядочен.
prop_sortOrdered :: [Int] -> Bool
prop_sortOrdered xs = sorted (mergeSort xs)

-- | Повторная сортировка не меняет результат.
prop_sortIdempotent :: [Int] -> Bool
prop_sortIdempotent xs = mergeSort (mergeSort xs) == mergeSort xs

-- Упражнение 2: Генератор BST и свойства

-- | Генерируем список случайных Int и строим BST через fromList.
genBST :: Gen (BST Int)
genBST = fromList <$> listOf arbitrary

-- | Все деревья из генератора валидны.
prop_genBSTValid :: Property
prop_genBSTValid = forAll genBST valid

-- | После вставки элемент находится в дереве.
prop_insertMember :: Property
prop_insertMember =
  forAll genBST $ \bst ->
    forAll arbitrary $ \(x :: Int) ->
      member x (insert x bst)

-- Упражнение 3: Round-trip кодирования

-- | Генератор Person: имя из строчных латинских букв (без ';'), возраст 0–150.
genPerson :: Gen Person
genPerson = Person
  <$> listOf (elements ['a'..'z'])
  <*> chooseInt (0, 150)

-- | Round-trip: декодирование отменяет кодирование.
prop_encodeDecodeRoundTrip :: Property
prop_encodeDecodeRoundTrip =
  forAll genPerson $ \p ->
    decodePerson (encodePerson p) == Just p

-- Упражнение 4: Слияние отсортированных списков

-- | Генератор отсортированного списка.
genSortedList :: Gen [Int]
genSortedList = sort <$> listOf arbitrary

-- | Слияние двух отсортированных списков даёт отсортированный список.
-- classify отслеживает распределение входных данных в отчёте QuickCheck.
prop_mergeOrdered :: Property
prop_mergeOrdered =
  forAll genSortedList $ \xs ->
    forAll genSortedList $ \ys ->
      classify (null xs || null ys) "один список пуст" $
      classify (length xs + length ys > 20) "большой вход" $
        sorted (merge xs ys)
