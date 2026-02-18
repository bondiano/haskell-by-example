module Solutions where

import Data.Path
import Data.List (foldl')

-- | Все файлы (не каталоги) в дереве.
allFiles :: Path -> [Path]
allFiles f@(File _ _)      = [f]
allFiles (Directory _ cs)  = concatMap allFiles cs

-- | Самый большой файл в дереве.
largestFile :: Path -> Maybe (Path, Int)
largestFile path =
  case allFiles path of
    []    -> Nothing
    files -> Just $ foldl1 bigger (map withSize files)
  where
    withSize f@(File _ s) = (f, s)
    withSize _            = error "impossible: allFiles returns only Files"
    bigger a@(_, s1) b@(_, s2)
      | s1 >= s2  = a
      | otherwise = b

-- | Найти файл по имени и вернуть содержащий его каталог.
whereIs :: Path -> String -> Maybe Path
whereIs (File _ _) _ = Nothing
whereIs dir@(Directory _ cs) target
  | any (\c -> not (isDirectory c) && filename c == target) cs = Just dir
  | otherwise = case concatMap (\c -> maybe [] (:[]) (whereIs c target)) cs of
      (found:_) -> Just found
      []        -> Nothing

-- | Суммарный размер всех файлов в дереве.
totalSize :: Path -> Int
totalSize (File _ s)      = s
totalSize (Directory _ cs) = foldl' (\acc c -> acc + totalSize c) 0 cs

-- | Собственная строгая левая свёртка через seq.
strictFoldl :: (b -> a -> b) -> b -> [a] -> b
strictFoldl _ z []     = z
strictFoldl f z (x:xs) = let z' = f z x
                          in z' `seq` strictFoldl f z' xs
