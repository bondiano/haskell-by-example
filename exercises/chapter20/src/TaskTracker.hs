module TaskTracker where

import Control.Lens (makeLenses)
import Data.Text (Text)

-- | Приоритет задачи.
data Priority = Low | Medium | High
  deriving (Show, Eq, Ord)

-- | Статус задачи.
data Status = Todo | InProgress | Done
  deriving (Show, Eq, Ord)

-- | Задача трекера.
data Task = Task
  { _taskTitle :: Text
  , _taskPriority :: Priority
  , _taskStatus :: Status
  , _taskTags :: [Text]
  }
  deriving (Show, Eq)

makeLenses ''Task

-- | Конфигурация пула подключений.
data PoolConfig = PoolConfig
  { _poolMaxSize :: Int
  , _poolTimeout :: Int
  }
  deriving (Show, Eq)

makeLenses ''PoolConfig

-- | Конфигурация базы данных.
data DatabaseConfig = DatabaseConfig
  { _dbHost :: Text
  , _dbPort :: Int
  , _dbPool :: PoolConfig
  }
  deriving (Show, Eq)

makeLenses ''DatabaseConfig

-- | Конфигурация уведомлений.
data NotificationConfig = NotificationConfig
  { _notifyEnabled :: Bool
  , _notifyEmail :: Text
  }
  deriving (Show, Eq)

makeLenses ''NotificationConfig

-- | Главная конфигурация трекера.
data TrackerConfig = TrackerConfig
  { _configDb :: DatabaseConfig
  , _configPort :: Int
  , _configNotify :: NotificationConfig
  }
  deriving (Show, Eq)

makeLenses ''TrackerConfig

-- | Конфигурация по умолчанию.
defaultConfig :: TrackerConfig
defaultConfig =
  TrackerConfig
    { _configDb =
        DatabaseConfig
          { _dbHost = "localhost"
          , _dbPort = 5432
          , _dbPool = PoolConfig{_poolMaxSize = 5, _poolTimeout = 30}
          }
    , _configPort = 8080
    , _configNotify =
        NotificationConfig
          { _notifyEnabled = False
          , _notifyEmail = ""
          }
    }

-- | Примеры задач для тестирования.
exampleTasks :: [Task]
exampleTasks =
  [ Task "Купить молоко" Low Todo ["дом", "покупки"]
  , Task "Написать отчёт" High InProgress ["работа"]
  , Task "Полить цветы" Medium Done ["дом"]
  , Task "Подготовить презентацию" High Todo ["работа", "важное"]
  ]
