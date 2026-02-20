module Main where

import Control.Monad.Logger (runStdoutLoggingT)
import Database.Persist.Sqlite (runMigration, runSqlPool)
import Network.Wai.Handler.Warp (run)
import Servant

import API

main :: IO ()
main = do
  putStrLn "Инициализация базы данных..."
  pool <- createPool
  runStdoutLoggingT $ runSqlPool (runMigration migrateAll) pool

  putStrLn "Сервер запущен на http://localhost:3000"
  putStrLn ""
  putStrLn "Доступные эндпоинты:"
  putStrLn "  GET    /tasks          - список всех задач"
  putStrLn "  GET    /tasks/:id      - получить задачу по ID"
  putStrLn "  POST   /tasks          - создать задачу"
  putStrLn "  PUT    /tasks/:id      - обновить задачу"
  putStrLn "  DELETE /tasks/:id      - удалить задачу"
  putStrLn "  PATCH  /tasks/:id/complete - завершить задачу"
  putStrLn "  GET    /stats          - статистика задач"
  putStrLn ""

  run 3000 (serve taskAPI (taskServer pool))
