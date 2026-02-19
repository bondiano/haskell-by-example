module Solutions where

import Data.List (foldl')
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as T
import TaskTracker

-- | Упражнение 1: Количество задач в хранилище.
storeSize :: TaskStore -> Int
storeSize = Map.size . unTaskStore

-- | Упражнение 2: Обновить статус задачи по идентификатору.
updateTaskStatus :: TaskId -> Status -> TaskStore -> TaskStore
updateTaskStatus tid newStatus (TaskStore m) =
  TaskStore (Map.adjust (\task -> task{taskStatus = newStatus}) tid m)

-- | Упражнение 3: Найти все задачи с данным тегом.
findByTag :: Tag -> TaskStore -> [Task]
findByTag tag (TaskStore m) =
  Map.elems (Map.filter (Set.member tag . taskTags) m)

-- | Упражнение 4: Инвертировать отображение.
invertMap :: (Ord k, Ord v) => Map k v -> Map v k
invertMap = Map.fromList . map (\(k, v) -> (v, k)) . Map.toList

-- | Упражнение 5: Общие элементы двух списков (через Set).
commonElements :: (Ord a) => [a] -> [a] -> [a]
commonElements xs ys =
  Set.toList (Set.intersection (Set.fromList xs) (Set.fromList ys))

-- | Упражнение 6: Частотный словарь слов в тексте.
wordFrequency :: Text -> Map Text Int
wordFrequency t =
  foldl' (\acc w -> Map.insertWith (+) w 1 acc) Map.empty (map T.toLower (T.words t))
