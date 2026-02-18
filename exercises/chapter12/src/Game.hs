module Game
  ( -- * Типы
    Direction(..)
  , Item(..)
  , RoomDef(..)
  , GameConfig(..)
  , GameState(..)
  , GameError(..)
    -- * Монада Game
  , Game
  , runGame
    -- * Помощники
  , getRoomDef
  , showItem
  , showDirection
  , showItems
  , showExits
    -- * Пример
  , exampleConfig
  , initialState
  ) where

import Control.Monad.Except (ExceptT, runExceptT)
import Control.Monad.Reader (ReaderT, runReaderT)
import Control.Monad.State.Strict (StateT, runStateT)
import Data.Functor.Identity (Identity, runIdentity)
import Data.List (intercalate)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map

-- | Направление движения.
data Direction = North | South | East | West
  deriving stock (Show, Eq, Ord)

-- | Предмет в игре.
data Item = Lamp | Sword | Key | Potion
  deriving stock (Show, Eq, Ord)

-- | Описание комнаты (статическое — не меняется в процессе игры).
data RoomDef = RoomDef
  { roomDesc  :: String                -- ^ описание комнаты
  , roomExits :: Map Direction String  -- ^ направление → id комнаты
  } deriving stock (Show, Eq)

-- | Конфигурация игры (read-only).
data GameConfig = GameConfig
  { configRooms :: Map String RoomDef
  } deriving stock (Show, Eq)

-- | Изменяемое состояние игры.
data GameState = GameState
  { playerRoom   :: String             -- ^ текущая комната (id)
  , inventory    :: [Item]             -- ^ инвентарь игрока
  , playerHealth :: Int                -- ^ здоровье (0–100)
  , roomItems    :: Map String [Item]  -- ^ предметы в комнатах
  } deriving stock (Show, Eq)

-- | Ошибки игры.
data GameError
  = NoExit Direction      -- ^ нет выхода в этом направлении
  | ItemNotFound Item     -- ^ предмет не найден
  | GameOver String       -- ^ игра окончена
  deriving stock (Show, Eq)

-- | Монада игры: чтение конфига, мутабельное состояние, ошибки.
--
-- @ReaderT@ — доступ к конфигурации через @ask@/@asks@.
-- @StateT@  — мутабельное состояние через @get@/@modify@.
-- @ExceptT@ — обработка ошибок через @throwError@.
type Game a = ReaderT GameConfig (StateT GameState (ExceptT GameError Identity)) a

-- | Запуск Game-вычисления. Возвращает результат и финальное состояние
-- или ошибку.
runGame :: GameConfig -> GameState -> Game a -> Either GameError (a, GameState)
runGame config state game =
  runIdentity $ runExceptT $ runStateT (runReaderT game config) state

-- | Найти определение комнаты по id.
getRoomDef :: String -> GameConfig -> Maybe RoomDef
getRoomDef name config = Map.lookup name (configRooms config)

-- | Показать предмет по-русски.
showItem :: Item -> String
showItem Lamp   = "Лампа"
showItem Sword  = "Меч"
showItem Key    = "Ключ"
showItem Potion = "Зелье"

-- | Показать направление по-русски.
showDirection :: Direction -> String
showDirection North = "север"
showDirection South = "юг"
showDirection East  = "восток"
showDirection West  = "запад"

-- | Показать список предметов.
showItems :: [Item] -> String
showItems [] = "ничего"
showItems items = intercalate ", " (map showItem items)

-- | Показать список выходов.
showExits :: [Direction] -> String
showExits [] = "нет выходов"
showExits dirs = intercalate ", " (map showDirection dirs)

-- | Пример конфигурации: подземелье из 4 комнат.
exampleConfig :: GameConfig
exampleConfig = GameConfig $ Map.fromList
  [ ("entrance", RoomDef
      "Вход в подземелье. Каменные стены покрыты мхом."
      (Map.fromList [(North, "hall")]))
  , ("hall", RoomDef
      "Тёмный зал. Факелы едва освещают стены."
      (Map.fromList [(South, "entrance"), (East, "treasury"), (North, "throne")]))
  , ("treasury", RoomDef
      "Сокровищница. Золото блестит в свете факелов."
      (Map.fromList [(West, "hall")]))
  , ("throne", RoomDef
      "Тронный зал. Массивный каменный трон стоит в центре."
      (Map.fromList [(South, "hall")]))
  ]

-- | Начальное состояние: игрок у входа, пустой инвентарь, 100 HP.
initialState :: GameState
initialState = GameState
  { playerRoom   = "entrance"
  , inventory    = []
  , playerHealth = 100
  , roomItems    = Map.fromList
      [ ("entrance", [Lamp])
      , ("hall",     [Sword])
      , ("treasury", [Key])
      , ("throne",   [Potion])
      ]
  }
