module Data.Path
  ( Path(..)
  , root
  , filename
  , fileSize
  , isDirectory
  , children
  , allPaths
  ) where

-- | Путь в виртуальной файловой системе.
-- Дерево, где каждый узел — файл (с именем и размером) или каталог (с именем и дочерними путями).
data Path
  = File String Int          -- ^ имя файла, размер в байтах
  | Directory String [Path]  -- ^ имя каталога, содержимое
  deriving (Show, Eq)

-- | Имя файла или каталога.
filename :: Path -> String
filename (File name _)      = name
filename (Directory name _) = name

-- | Размер файла. Для каталогов возвращает @Nothing@.
fileSize :: Path -> Maybe Int
fileSize (File _ s)      = Just s
fileSize (Directory _ _) = Nothing

-- | Проверить, является ли путь каталогом.
isDirectory :: Path -> Bool
isDirectory (Directory _ _) = True
isDirectory _               = False

-- | Непосредственные дочерние элементы. Для файлов — пустой список.
children :: Path -> [Path]
children (Directory _ cs) = cs
children _                = []

-- | Все пути в дереве (включая каталоги), начиная с корня.
allPaths :: Path -> [Path]
allPaths p = p : concatMap allPaths (children p)

-- | Пример файловой системы.
root :: Path
root = Directory "/"
  [ Directory "bin"
    [ File "cp" 24800
    , File "ls" 34700
    , File "mv" 20200
    ]
  , Directory "etc"
    [ File "hosts" 300
    , File "network.conf" 1200
    ]
  , Directory "home"
    [ Directory "user"
      [ File "todo.txt" 1820
      , File "notes.md" 3400
      , Directory "projects"
        [ File "README.md" 540
        , File "Main.hs" 2700
        ]
      ]
    ]
  ]
