module Solutions where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Control.Monad.Writer

import Data.Phonebook (Phonebook)
import Data.Chess (KnightPos, moveKnight)

-- ============================================================
-- Упражнение 1: Безопасный поиск в телефонной книге
-- ============================================================

-- | Поиск телефона по городу и имени через >>=.
-- Map.lookup возвращает Maybe, и >>= протаскивает Nothing автоматически.
safeLookup :: String -> String -> Phonebook -> Maybe String
safeLookup city name book =
  Map.lookup city book >>= Map.lookup name

-- ============================================================
-- Упражнение 2: Безопасная индексация и цепочка
-- ============================================================

-- | Безопасный доступ по индексу (0-based).
safeIndex :: [a] -> Int -> Maybe a
safeIndex xs i
  | i < 0     = Nothing
  | otherwise = case drop i xs of
      []    -> Nothing
      (x:_) -> Just x

-- | Безопасная голова списка.
safeHead :: [a] -> Maybe a
safeHead []    = Nothing
safeHead (x:_) = Just x

-- | Третий элемент первого подсписка.
-- Цепочка: safeHead достаёт первый подсписок,
-- затем safeIndex достаёт элемент с индексом 2.
thirdElement :: [[a]] -> Maybe a
thirdElement xss = safeHead xss >>= \xs -> safeIndex xs 2

-- ============================================================
-- Упражнение 3: Ходы шахматного коня
-- ============================================================

-- | Проверяет, может ли конь достичь цели за ровно n ходов.
--
-- Генерируем все возможные позиции после n ходов через >>=:
-- каждое применение >>= с moveKnight разворачивает один ход.
-- За n ходов получаем список всех достижимых позиций.
canReachIn :: Int -> KnightPos -> KnightPos -> Bool
canReachIn n start end = end `elem` reachable n [start]
  where
    reachable 0 positions = positions
    reachable k positions = reachable (k - 1) (positions >>= moveKnight)

-- ============================================================
-- Упражнение 4: Логирование через Writer
-- ============================================================

-- | Последовательность Коллатца с логированием.
--
-- При каждом шаге записываем "n → m" в лог через tell.
-- Считаем количество шагов до достижения 1.
collatzLog :: Int -> Writer [String] Int
collatzLog 1 = return 0
collatzLog n = do
  let next = if even n then n `div` 2 else 3 * n + 1
  tell [show n ++ " \8594 " ++ show next]
  rest <- collatzLog next
  return (rest + 1)
