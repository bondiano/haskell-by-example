module Main where

import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as T
import Test.Hspec

import MySolutions
import TaskTracker

main :: IO ()
main = hspec $ do
  -- Тестовые данные
  let task1 = Task "Купить молоко" Medium Todo
      task2 = Task "Написать отчёт" High InProgress
      task3 = Task "Полить цветы" Low Done
      task4 = Task "Подготовить презентацию" High Todo
      store =
        TaskStore $
          Map.fromList
            [ (TaskId 1, task1)
            , (TaskId 2, task2)
            , (TaskId 3, task3)
            , (TaskId 4, task4)
            ]

  describe "Упражнение 1: computeStats" $ do
    it "считает статистику для хранилища с задачами" $ do
      let stats = computeStats store
      totalTasks stats `shouldBe` 4
      todoCount stats `shouldBe` 2
      doneCount stats `shouldBe` 1
      highPriority stats `shouldBe` 2

    it "считает статистику для пустого хранилища" $ do
      let stats = computeStats emptyStore
      totalTasks stats `shouldBe` 0
      todoCount stats `shouldBe` 0
      doneCount stats `shouldBe` 0
      highPriority stats `shouldBe` 0

    it "считает статистику для хранилища с одной задачей" $ do
      let s = addTask (TaskId 1) (Task "Тест" High Done) emptyStore
          stats = computeStats s
      totalTasks stats `shouldBe` 1
      todoCount stats `shouldBe` 0
      doneCount stats `shouldBe` 1
      highPriority stats `shouldBe` 1

  describe "Упражнение 2: mkPriority" $ do
    it "парсит \"low\"" $
      mkPriority "low" `shouldBe` Just Low

    it "парсит \"medium\"" $
      mkPriority "medium" `shouldBe` Just Medium

    it "парсит \"high\"" $
      mkPriority "high" `shouldBe` Just High

    it "регистронезависимый: \"HIGH\"" $
      mkPriority "HIGH" `shouldBe` Just High

    it "регистронезависимый: \"Medium\"" $
      mkPriority "Medium" `shouldBe` Just Medium

    it "регистронезависимый: \"LoW\"" $
      mkPriority "LoW" `shouldBe` Just Low

    it "неизвестное значение — Nothing" $
      mkPriority "urgent" `shouldBe` Nothing

    it "пустая строка — Nothing" $
      mkPriority "" `shouldBe` Nothing

  describe "Упражнение 3: parseCommand" $ do
    it "парсит команду add" $
      parseCommand "add Купить хлеб" `shouldBe` Just (AddCmd "Купить хлеб")

    it "парсит команду list" $
      parseCommand "list" `shouldBe` Just ListCmd

    it "парсит команду done" $
      parseCommand "done 3" `shouldBe` Just (DoneCmd (TaskId 3))

    it "парсит команду delete" $
      parseCommand "delete 5" `shouldBe` Just (DeleteCmd (TaskId 5))

    it "парсит команду quit" $
      parseCommand "quit" `shouldBe` Just QuitCmd

    it "неизвестная команда — Nothing" $
      parseCommand "unknown" `shouldBe` Nothing

    it "done без числа — Nothing" $
      parseCommand "done abc" `shouldBe` Nothing

    it "delete без числа — Nothing" $
      parseCommand "delete" `shouldBe` Nothing

    it "add без текста — Nothing" $
      parseCommand "add" `shouldBe` Nothing

  describe "Упражнение 4: renderTask, renderTaskList, renderStats" $ do
    it "renderTask форматирует задачу" $
      renderTask (TaskId 1, Task "Купить молоко" Medium Todo)
        `shouldBe` "[1] Купить молоко (Medium, Todo)"

    it "renderTask для другой задачи" $
      renderTask (TaskId 3, Task "Полить цветы" Low Done)
        `shouldBe` "[3] Полить цветы (Low, Done)"

    it "renderTaskList форматирует список задач" $ do
      let tasks = [(TaskId 1, task1), (TaskId 2, task2)]
      renderTaskList tasks
        `shouldBe` "[1] Купить молоко (Medium, Todo)\n[2] Написать отчёт (High, InProgress)"

    it "renderTaskList для пустого списка" $
      renderTaskList [] `shouldBe` ""

    it "renderStats форматирует статистику" $ do
      let stats = TaskStats 4 2 1 2
      renderStats stats
        `shouldBe` "Всего: 4, Todo: 2, Done: 1, Высокий приоритет: 2"

  describe "Упражнение 5: NonEmptyText" $ do
    it "принимает непустой текст" $
      mkNonEmptyText "hello" `shouldSatisfy` isJust

    it "отклоняет пустой текст" $
      mkNonEmptyText "" `shouldBe` Nothing

    it "отклоняет текст из одних пробелов" $
      mkNonEmptyText "   " `shouldBe` Nothing

    it "извлекает значение обратно" $
      case mkNonEmptyText "hello" of
        Just net -> unNonEmptyText net `shouldBe` "hello"
        Nothing -> expectationFailure "Ожидали Just"

    it "сохраняет пробелы внутри текста" $
      case mkNonEmptyText "hello world" of
        Just net -> unNonEmptyText net `shouldBe` "hello world"
        Nothing -> expectationFailure "Ожидали Just"

  describe "Упражнение 6: lookupDefault" $ do
    it "находит существующий ключ" $ do
      let m = Map.fromList [("a" :: String, 1 :: Int), ("b", 2)]
      lookupDefault 0 "a" m `shouldBe` 1

    it "возвращает значение по умолчанию для отсутствующего ключа" $ do
      let m = Map.fromList [("a" :: String, 1 :: Int)]
      lookupDefault 42 "z" m `shouldBe` 42

    it "работает с пустым Map" $ do
      let m = Map.empty :: Map.Map String Int
      lookupDefault 99 "x" m `shouldBe` 99

  describe "Упражнение 7: parseCSV" $ do
    it "парсит одну строку" $
      parseCSV "Купить молоко,low,todo"
        `shouldBe` Right [Task "Купить молоко" Low Todo]

    it "парсит несколько строк" $
      parseCSV "Задача 1,high,todo\nЗадача 2,medium,done"
        `shouldBe` Right
          [ Task "Задача 1" High Todo
          , Task "Задача 2" Medium Done
          ]

    it "парсит все статусы" $
      parseCSV "A,low,todo\nB,low,in_progress\nC,low,done"
        `shouldBe` Right
          [ Task "A" Low Todo
          , Task "B" Low InProgress
          , Task "C" Low Done
          ]

    it "ошибка при неверном приоритете" $
      parseCSV "Задача,urgent,todo"
        `shouldSatisfy` isLeft

    it "ошибка при неверном статусе" $
      parseCSV "Задача,low,waiting"
        `shouldSatisfy` isLeft

    it "ошибка при неверном формате (недостаточно полей)" $
      parseCSV "Задача,low"
        `shouldSatisfy` isLeft

    it "пустая строка — пустой список" $
      parseCSV "" `shouldBe` Right []

-- | Вспомогательные функции для проверки
isJust :: Maybe a -> Bool
isJust (Just _) = True
isJust Nothing = False

isLeft :: Either a b -> Bool
isLeft (Left _) = True
isLeft (Right _) = False
