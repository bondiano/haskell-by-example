module Solutions where

import Control.Lens
import Data.Text (Text)
import Data.Text qualified as T

import TaskTracker

-- | Упражнение 1: Чтение и запись через вложенные линзы.
getPoolMax :: TrackerConfig -> Int
getPoolMax cfg = cfg ^. configDb . dbPool . poolMaxSize

setPoolMax :: Int -> TrackerConfig -> TrackerConfig
setPoolMax n cfg = cfg & configDb . dbPool . poolMaxSize .~ n

-- | Упражнение 2: Создание «продакшен» конфигурации.
productionConfig :: TrackerConfig -> TrackerConfig
productionConfig cfg =
  cfg
    & configDb . dbPool . poolMaxSize .~ 20
    & configPort .~ 443
    & configNotify . notifyEnabled .~ True

-- | Упражнение 3: Завершить все задачи с высоким приоритетом.
completeHighPriority :: [Task] -> [Task]
completeHighPriority = over (traversed . filtered isHigh) (set taskStatus Done)
 where
  isHigh task = task ^. taskPriority == High

-- | Упражнение 4: Ручная линза без Template Haskell.
poolMaxSizeL :: Lens' PoolConfig Int
poolMaxSizeL f cfg = (\newMax -> cfg{_poolMaxSize = newMax}) <$> f (_poolMaxSize cfg)

-- | Упражнение 5: Работа с призмами.
incrementMaybe :: Maybe Int -> Maybe Int
incrementMaybe = over _Just (+ 1)

uppercaseError :: Either Text a -> Either Text a
uppercaseError = over _Left T.toUpper

-- | Упражнение 6: Извлечение всех тегов из списка задач.
allTags :: [Task] -> [Text]
allTags tasks = tasks ^.. traversed . taskTags . traversed
