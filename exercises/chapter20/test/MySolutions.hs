module MySolutions where

import Control.Lens
import Data.Text (Text)
import TaskTracker

{- | Упражнение 1: Чтение и запись через вложенные линзы.
  getPoolMax — получить _poolMaxSize через цепочку configDb.dbPool.poolMaxSize.
  setPoolMax — установить _poolMaxSize.
-}
getPoolMax :: TrackerConfig -> Int
getPoolMax = undefined

setPoolMax :: Int -> TrackerConfig -> TrackerConfig
setPoolMax = undefined

{- | Упражнение 2: Создание «продакшен» конфигурации.
  Примените несколько изменений через оператор (&):
  - poolMaxSize → 20
  - configPort → 443
  - notifyEnabled → True
-}
productionConfig :: TrackerConfig -> TrackerConfig
productionConfig = undefined

{- | Упражнение 3: Завершить все задачи с высоким приоритетом.
  Используйте traversed, filtered и (.~) для массового обновления.
-}
completeHighPriority :: [Task] -> [Task]
completeHighPriority = undefined

{- | Упражнение 4: Ручная линза без Template Haskell.
  Реализуйте линзу для поля _poolMaxSize вручную.
-}
poolMaxSizeL :: Lens' PoolConfig Int
poolMaxSizeL = undefined

{- | Упражнение 5: Работа с призмами.
  incrementMaybe — увеличить значение внутри Just на 1.
  uppercaseError — привести текст ошибки (Left) к верхнему регистру.
-}
incrementMaybe :: Maybe Int -> Maybe Int
incrementMaybe = undefined

uppercaseError :: Either Text a -> Either Text a
uppercaseError = undefined

{- | Упражнение 6: Извлечение всех тегов из списка задач.
  Используйте (^..) с traversed и taskTags.
-}
allTags :: [Task] -> [Text]
allTags = undefined
