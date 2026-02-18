module MySolutions where

import Data.Text (Text)
import Database.Persist
import Database.Persist.Sql (SqlPersistT)

import Data.Todo (Todo(..), TodoId, EntityField(..))

-- Упражнение 1: вставка задачи
--
-- Вставьте новую задачу (Todo) с заданным заголовком и completed = False.
-- Верните ключ (Key Todo) созданной записи.
-- Используйте функцию insert из Database.Persist.

insertTodo :: Text -> SqlPersistT IO (Key Todo)
insertTodo = undefined

-- Упражнение 2: переключение статуса
--
-- Переключите поле completed задачи с данным ключом.
-- Если задача не найдена — ничего не делайте.
-- Подсказка: используйте get для чтения, update с (=.) для записи.

toggleTodo :: Key Todo -> SqlPersistT IO ()
toggleTodo = undefined

-- Упражнение 3: фильтрация задач
--
-- Верните все задачи с указанным значением completed.
-- Используйте selectList с фильтром (==.).

filteredTodos :: Bool -> SqlPersistT IO [Entity Todo]
filteredTodos = undefined

-- Упражнение 4: архивация завершённых
--
-- Удалите все завершённые задачи (completed == True).
-- Верните количество удалённых задач.
-- Подсказка: используйте selectList для подсчёта и deleteWhere для удаления.

archiveDone :: SqlPersistT IO Int
archiveDone = undefined
