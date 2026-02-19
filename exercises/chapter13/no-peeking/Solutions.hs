module Solutions where

import Control.Monad.Except
import Control.Monad.State
import Data.Functor.Identity (Identity (..))
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map

import TaskTracker

-- ============================================================
-- Упражнение 1: Удаление задачи (чистая версия)
-- ============================================================

-- | Проверяем наличие задачи, затем удаляем через Map.delete.
deleteTaskPure :: TaskId -> TaskStore -> Either AppError TaskStore
deleteTaskPure tid store@(TaskStore m) =
  case lookupTask tid store of
    Nothing -> Left (TaskNotFound tid)
    Just _ -> Right (TaskStore (Map.delete tid m))

-- ============================================================
-- Упражнение 2: Список задач
-- ============================================================

-- | Преобразуем Map в список пар.
listTasksPure :: TaskStore -> [(TaskId, Task)]
listTasksPure = Map.toList . unTaskStore

-- ============================================================
-- Упражнения 3–6: Калькулятор на StateT
-- ============================================================

-- | Стек трансформеров: состояние (журнал) + ошибки.
type Calc a = StateT [String] (Either String) a

-- ============================================================
-- Упражнение 3: runCalc
-- ============================================================

-- | Запускаем StateT с пустым начальным состоянием.
runCalc :: Calc a -> Either String (a, [String])
runCalc calc = runStateT calc []

-- ============================================================
-- Упражнение 4: calcDivide
-- ============================================================

-- | Деление с проверкой на ноль и журналированием.
calcDivide :: Double -> Double -> Calc Double
calcDivide _ 0 = throwError "Деление на ноль"
calcDivide a b = do
  let result = a / b
  modify (++ [show a ++ " / " ++ show b ++ " = " ++ show result])
  return result

-- ============================================================
-- Упражнение 5: calcHistory
-- ============================================================

-- | Возвращаем текущее состояние (журнал).
calcHistory :: Calc [String]
calcHistory = get

-- ============================================================
-- Упражнение 6: Цепочка вычислений
-- ============================================================

-- | 100 / 5 = 20, затем 20 / 4 = 5.
calcChain :: Calc Double
calcChain = do
  r1 <- calcDivide 100 5
  calcDivide r1 4
