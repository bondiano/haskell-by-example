module Solutions where

import Control.Exception (IOException, try)
import Control.Monad.Except (throwError)
import Control.Monad.Reader (ask)
import Control.Monad.State.Strict (gets, modify)
import Data.Aeson (FromJSON, eitherDecode)
import qualified Data.ByteString.Lazy as BL
import Data.List (delete)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe)

import Game

-- Упражнение 1: осмотр комнаты

look :: Game String
look = do
  name <- gets playerRoom
  config <- ask
  case getRoomDef name config of
    Nothing -> throwError (GameOver ("Неизвестная комната: " <> name))
    Just room -> do
      items <- gets (fromMaybe [] . Map.lookup name . roomItems)
      let exits = Map.keys (roomExits room)
      return $ roomDesc room
        <> "\nПредметы: " <> showItems items
        <> "\nВыходы: " <> showExits exits

-- Упражнение 2: перемещение

move :: Direction -> Game String
move dir = do
  name <- gets playerRoom
  config <- ask
  case getRoomDef name config of
    Nothing -> throwError (GameOver ("Неизвестная комната: " <> name))
    Just room ->
      case Map.lookup dir (roomExits room) of
        Nothing -> throwError (NoExit dir)
        Just nextRoom -> do
          modify (\s -> s { playerRoom = nextRoom })
          return ("Вы идёте на " <> showDirection dir <> ".")

-- Упражнение 3: подбор предмета

pickUp :: Item -> Game String
pickUp item = do
  name <- gets playerRoom
  items <- gets (fromMaybe [] . Map.lookup name . roomItems)
  if item `notElem` items
    then throwError (ItemNotFound item)
    else do
      modify (\s -> s
        { roomItems = Map.adjust (delete item) name (roomItems s)
        , inventory = inventory s <> [item]
        })
      return ("Вы подобрали: " <> showItem item)

-- Упражнение 4: использование предмета

useItem :: Item -> Game String
useItem item = do
  inv <- gets inventory
  if item `notElem` inv
    then throwError (ItemNotFound item)
    else do
      modify (\s -> s { inventory = delete item (inventory s) })
      case item of
        Potion -> do
          modify (\s -> s { playerHealth = min 100 (playerHealth s + 25) })
          return "Вы выпили зелье. Здоровье восстановлено."
        Lamp   -> return "Лампа освещает тёмный путь."
        Sword  -> return "Вы взмахнули мечом. Впечатляюще!"
        Key    -> return "Вы использовали ключ."

-- Упражнение 5: безопасное чтение JSON-файла

safeReadJSON :: FromJSON a => FilePath -> IO (Either String a)
safeReadJSON path = do
  result <- try (BL.readFile path) :: IO (Either IOException BL.ByteString)
  case result of
    Left err -> return (Left (show err))
    Right bs -> return (eitherDecode bs)
