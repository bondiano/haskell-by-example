module MySolutions where

import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as T
import TaskTracker

-- | Упражнение 1: Количество задач в хранилище.
storeSize :: TaskStore -> Int
storeSize = undefined

-- | Упражнение 2: Обновить статус задачи по идентификатору.
updateTaskStatus :: TaskId -> Status -> TaskStore -> TaskStore
updateTaskStatus = undefined

-- | Упражнение 3: Найти все задачи с данным тегом.
findByTag :: Tag -> TaskStore -> [Task]
findByTag = undefined

-- | Упражнение 4: Инвертировать отображение (поменять ключи и значения местами).
invertMap :: (Ord k, Ord v) => Map k v -> Map v k
invertMap = undefined

-- | Упражнение 5: Общие элементы двух списков (через Set).
commonElements :: (Ord a) => [a] -> [a] -> [a]
commonElements = undefined

-- | Упражнение 6: Частотный словарь слов в тексте (слова приведены к нижнему регистру).
wordFrequency :: Text -> Map Text Int
wordFrequency = undefined
