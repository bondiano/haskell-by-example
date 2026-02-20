module Main where

import MySolutions
import TaskTracker
import Test.Hspec

import Data.Map.Strict qualified as Map
import Data.Set qualified as Set

-- | Вспомогательная функция: найти задачу в хранилище напрямую через Map.
directLookup :: TaskId -> TaskStore -> Maybe Task
directLookup tid (TaskStore m) = Map.lookup tid m

main :: IO ()
main = hspec $ do
  -- Тестовые данные
  let task1 = Task "Релиз" "Подготовить релиз v2.0" High Todo (Set.fromList ["dev"])
      task2 = Task "Документация" "Обновить README" Medium InProgress (Set.fromList ["docs"])
      task3 = Task "Рефакторинг" "Переписать парсер" Low Done (Set.fromList ["dev"])
      store =
        addTask 1 task1
          . addTask 2 task2
          . addTask 3 task3
          $ emptyStore

  describe "Упражнение 1: lookupTask" $ do
    it "находит существующую задачу" $
      MySolutions.lookupTask 1 store `shouldBe` Just task1
    it "возвращает Nothing для несуществующей задачи" $
      MySolutions.lookupTask 999 store `shouldBe` Nothing
    it "находит задачу с другим идентификатором" $
      MySolutions.lookupTask 3 store `shouldBe` Just task3

  describe "Упражнение 2: serializeStore" $ do
    it "сериализует пустое хранилище в пустую строку" $
      serializeStore emptyStore `shouldBe` ""
    it "сериализует хранилище с одной задачей" $ do
      let s = addTask 1 task1 emptyStore
      serializeStore s `shouldBe` "1|Релиз|High|Todo"
    it "сериализует несколько задач через перенос строки" $ do
      let s = addTask 1 task1 . addTask 2 task2 $ emptyStore
          result = serializeStore s
      -- Проверяем, что обе строки присутствуют
      lines result `shouldContain` ["1|Релиз|High|Todo"]
      lines result `shouldContain` ["2|Документация|Medium|InProgress"]
      length (lines result) `shouldBe` 2

  describe "Упражнение 3: parseStore" $ do
    it "разбирает пустую строку в пустое хранилище" $
      parseStore "" `shouldBe` Right emptyStore
    it "разбирает одну строку" $ do
      let result = parseStore "1|Релиз|High|Todo"
      case result of
        Left err -> expectationFailure $ "Ожидался Right, получен Left: " ++ err
        Right s -> do
          fmap taskTitle (directLookup 1 s) `shouldBe` Just "Релиз"
          fmap taskPriority (directLookup 1 s) `shouldBe` Just High
          fmap taskStatus (directLookup 1 s) `shouldBe` Just Todo
    it "разбирает несколько строк" $ do
      let input = "1|Релиз|High|Todo\n2|Документация|Medium|InProgress"
          result = parseStore input
      case result of
        Left err -> expectationFailure $ "Ожидался Right, получен Left: " ++ err
        Right s -> do
          fmap taskTitle (directLookup 1 s) `shouldBe` Just "Релиз"
          fmap taskTitle (directLookup 2 s) `shouldBe` Just "Документация"
    it "возвращает Left для некорректного формата" $ do
      let result = parseStore "некорректные данные"
      result `shouldSatisfy` isLeft
    it "round-trip: serialize → parse" $ do
      let s = addTask 1 task1 . addTask 2 task2 $ emptyStore
          serialized = serializeStore s
      case parseStore serialized of
        Left err -> expectationFailure $ "Ожидался Right, получен Left: " ++ err
        Right s' -> do
          fmap taskTitle (directLookup 1 s') `shouldBe` Just "Релиз"
          fmap taskTitle (directLookup 2 s') `shouldBe` Just "Документация"

  describe "Упражнение 4: addNumbers" $ do
    it "нумерует строки" $
      addNumbers "hello\nworld" `shouldBe` "1: hello\n2: world"
    it "работает с одной строкой" $
      addNumbers "hello" `shouldBe` "1: hello"
    it "работает с пустой строкой" $
      addNumbers "" `shouldBe` ""
    it "нумерует три строки" $
      addNumbers "a\nb\nc" `shouldBe` "1: a\n2: b\n3: c"

  describe "parseCommand (из TaskTracker)" $ do
    it "разбирает команду add" $
      parseCommand "add задача" `shouldBe` Just (AddCmd "задача")
    it "разбирает команду list" $
      parseCommand "list" `shouldBe` Just ListCmd
    it "разбирает команду done" $
      parseCommand "done 1" `shouldBe` Just (DoneCmd (TaskId 1))
    it "разбирает команду show" $
      parseCommand "show 3" `shouldBe` Just (ShowCmd (TaskId 3))
    it "разбирает команду quit" $
      parseCommand "quit" `shouldBe` Just QuitCmd
    it "возвращает Nothing для неизвестной команды" $
      parseCommand "unknown" `shouldBe` Nothing

-- | Вспомогательная функция для проверки Left.
isLeft :: Either a b -> Bool
isLeft (Left _) = True
isLeft (Right _) = False
