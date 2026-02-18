module Data.Todo
  ( -- * Модель
    Todo(..)
  , TodoId
  , EntityField(..)
  , migrateAll
    -- * Помощники для работы с пулом
  , withTestDb
  , runDB
  ) where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Logger (runNoLoggingT)
import Data.Text (Text)
import Database.Persist.Sqlite
import Database.Persist.TH

share [mkPersist sqlSettings, mkMigrate "migrateAll"] [persistLowerCase|
Todo
    title Text
    completed Bool
    deriving Show Eq
|]

-- | Создать in-memory SQLite пул, выполнить миграцию и запустить действие.
--
-- Используется в тестах для изоляции: каждый тест получает чистую БД.
withTestDb :: (ConnectionPool -> IO a) -> IO a
withTestDb action = runNoLoggingT $
  withSqlitePool ":memory:" 1 $ \pool -> do
    liftIO $ runSqlPool (runMigration migrateAll) pool
    liftIO $ action pool

-- | Выполнить действие в контексте пула соединений.
runDB :: ConnectionPool -> SqlPersistT IO a -> IO a
runDB = flip runSqlPool
