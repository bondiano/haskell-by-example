module MySolutions where

import Control.Monad (foldM)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)

import TaskTracker

-- ============================================================
-- Упражнение 1: Завершение задачи
--
-- Найдите задачу по идентификатору, убедитесь, что она ещё
-- не завершена (иначе — AlreadyDone), и установите статус Done.
--
-- Используйте do-нотацию с Either.
--
-- Подсказка: note (TaskNotFound tid) (lookupTask tid store)
-- ============================================================

{- | Завершение задачи.

>>> completeTask (TaskId 1) exampleStore
Right (TaskStore ...)

>>> completeTask (TaskId 3) exampleStore
Left (AlreadyDone (TaskId 3))

>>> completeTask (TaskId 99) exampleStore
Left (TaskNotFound (TaskId 99))
-}
completeTask :: TaskId -> TaskStore -> Either AppError TaskStore
completeTask = undefined

-- ============================================================
-- Упражнение 2: Удаление задачи
--
-- Найдите задачу (ошибка TaskNotFound, если нет), затем
-- удалите её из хранилища.
--
-- Подсказка: note + Map.delete
-- ============================================================

{- | Удаление задачи из хранилища.

>>> deleteTask (TaskId 1) exampleStore
Right (TaskStore ...)

>>> deleteTask (TaskId 99) exampleStore
Left (TaskNotFound (TaskId 99))
-}
deleteTask :: TaskId -> TaskStore -> Either AppError TaskStore
deleteTask = undefined

-- ============================================================
-- Упражнение 3: Обработка команд
--
-- Обработайте список команд последовательно.
-- AddCmd создаёт задачу с приоритетом по умолчанию из конфига.
-- CompleteCmd завершает задачу.
-- Новые задачи получают TaskId = текущий размер хранилища + 1.
--
-- Подсказка: foldM
-- ============================================================

{- | Последовательная обработка команд.

>>> let cfg = AppConfig Medium 10
>>> processCommands cfg [AddCmd "Задача"] emptyStore
Right (TaskStore ...)
-}
processCommands :: AppConfig -> [Command] -> TaskStore -> Either AppError TaskStore
processCommands = undefined

-- ============================================================
-- Упражнение 4: safeHead и firstPlusSecond
--
-- safeHead возвращает первый элемент списка в Maybe.
-- firstPlusSecond складывает первый и второй элементы списка,
-- используя do-нотацию с Maybe.
--
-- Подсказка: для второго элемента используйте safeHead (drop 1 xs)
-- ============================================================

{- | Безопасное взятие первого элемента.

>>> safeHead [1,2,3]
Just 1

>>> safeHead ([] :: [Int])
Nothing
-}
safeHead :: [a] -> Maybe a
safeHead = undefined

{- | Сумма первых двух элементов списка.

>>> firstPlusSecond [10, 20, 30]
Just 30

>>> firstPlusSecond [5]
Nothing

>>> firstPlusSecond ([] :: [Int])
Nothing
-}
firstPlusSecond :: [Int] -> Maybe Int
firstPlusSecond = undefined

-- ============================================================
-- Упражнение 5: Валидация задачи
--
-- Проверьте, что:
--   1. Название не пустое → Left "Пустое название"
--   2. Название не длиннее 200 символов → Left "Название слишком длинное"
-- ============================================================

{- | Валидация задачи.

>>> validateTask (Task "Тест" Medium Todo)
Right (Task "Тест" Medium Todo)

>>> validateTask (Task "" Medium Todo)
Left "Пустое название"
-}
validateTask :: Task -> Either Text Task
validateTask = undefined

-- ============================================================
-- Упражнение 6: Все комбинации (монада списка)
--
-- Сгенерируйте все пары (Priority, Status), используя
-- do-нотацию монады списка.
--
-- Результат: 9 пар (3 приоритета × 3 статуса).
-- ============================================================

{- | Все комбинации приоритетов и статусов.

>>> length allTaskCombinations
9

>>> head allTaskCombinations
(Low, Todo)
-}
allTaskCombinations :: [(Priority, Status)]
allTaskCombinations = undefined

-- ============================================================
-- Упражнение 7: Цепочка поисков
--
-- По списку ключей последовательно ищет значения в Map.
-- Каждый ключ ищется независимо; все должны быть найдены.
-- Возвращается значение последнего найденного ключа.
--
-- safeLookupChain [] _ = Nothing
-- safeLookupChain ["a"] m → Map.lookup "a" m
-- safeLookupChain ["a","b"] m → lookup "a", затем lookup "b",
--   вернуть результат lookup "b"
--
-- Подсказка: используйте foldM с Map.lookup.
-- ============================================================

{- | Цепочка поисков в Map.

>>> let m = Map.fromList [("a","b"),("b","c")]
>>> safeLookupChain ["a"] m
Just "b"

>>> safeLookupChain ["a","b"] m
Just "c"

>>> safeLookupChain ["a","x"] m
Nothing

>>> safeLookupChain [] m
Nothing
-}
safeLookupChain :: (Ord k) => [k] -> Map k k -> Maybe k
safeLookupChain = undefined
