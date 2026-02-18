module MySolutions where

import Control.Exception (IOException, try)
import Control.Monad.Except (throwError)
import Control.Monad.Reader (ask)
import Control.Monad.State.Strict (get, gets, modify)
import Data.Aeson (FromJSON, eitherDecode)
import qualified Data.ByteString.Lazy as BL
import Data.List (delete)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe)

import Game

-- Упражнение 1: осмотр комнаты
--
-- Получите текущую комнату из состояния (playerRoom),
-- найдите её описание в конфиге (getRoomDef),
-- покажите предметы и выходы.
--
-- Используйте: gets, ask, getRoomDef, showItems, showExits.
-- При несуществующей комнате бросьте GameOver.

look :: Game String
look = undefined

-- Упражнение 2: перемещение
--
-- Получите текущую комнату, проверьте наличие выхода
-- в данном направлении (roomExits). Если выход есть —
-- обновите playerRoom. Если нет — бросьте NoExit.
--
-- Используйте: gets, ask, modify, throwError, Map.lookup.

move :: Direction -> Game String
move = undefined

-- Упражнение 3: подбор предмета
--
-- Проверьте, есть ли предмет в текущей комнате (roomItems в состоянии).
-- Если есть — уберите из комнаты, добавьте в инвентарь.
-- Если нет — бросьте ItemNotFound.
--
-- Используйте: gets, modify, Map.adjust, delete, throwError.

pickUp :: Item -> Game String
pickUp = undefined

-- Упражнение 4: использование предмета
--
-- Проверьте, есть ли предмет в инвентаре.
-- Если есть — уберите из инвентаря и примените эффект:
--   Potion → +25 здоровья (максимум 100)
--   остальные → просто сообщение.
-- Если нет — бросьте ItemNotFound.
--
-- Используйте: gets, modify, delete, throwError.

useItem :: Item -> Game String
useItem = undefined

-- Упражнение 5: безопасное чтение JSON-файла
--
-- Используйте try для перехвата IOException при чтении файла,
-- затем eitherDecode для парсинга JSON.
-- Оба вида ошибок объединяются в Either String a.

safeReadJSON :: FromJSON a => FilePath -> IO (Either String a)
safeReadJSON = undefined
