module Data.BST
  ( BST(..)
  , insert
  , member
  , toAscList
  , fromList
  , valid
  , depth
  ) where

-- | Бинарное дерево поиска (binary search tree).
--
-- Инвариант: для каждого узла @Node l v r@ все значения в @l@ строго меньше @v@,
-- а все значения в @r@ строго больше @v@. Дубликаты не хранятся.
data BST a
  = Leaf
  | Node (BST a) a (BST a)
  deriving (Show, Eq)

-- | Вставка элемента в дерево. Дубликаты игнорируются.
--
-- >>> insert 3 (insert 1 (insert 2 Leaf))
-- Node (Node Leaf 1 Leaf) 2 (Node Leaf 3 Leaf)
insert :: Ord a => a -> BST a -> BST a
insert x Leaf = Node Leaf x Leaf
insert x (Node l v r)
  | x < v     = Node (insert x l) v r
  | x > v     = Node l v (insert x r)
  | otherwise  = Node l v r

-- | Проверка принадлежности элемента дереву.
--
-- >>> member 3 (fromList [1, 2, 3])
-- True
-- >>> member 4 (fromList [1, 2, 3])
-- False
member :: Ord a => a -> BST a -> Bool
member _ Leaf = False
member x (Node l v r)
  | x < v     = member x l
  | x > v     = member x r
  | otherwise  = True

-- | Обход дерева в порядке возрастания (in-order traversal).
--
-- >>> toAscList (fromList [3, 1, 2])
-- [1,2,3]
toAscList :: BST a -> [a]
toAscList Leaf         = []
toAscList (Node l v r) = toAscList l ++ [v] ++ toAscList r

-- | Построение BST из списка элементов.
--
-- >>> fromList [3, 1, 2]
-- Node (Node Leaf 1 (Node Leaf 2 Leaf)) 3 Leaf
fromList :: Ord a => [a] -> BST a
fromList = foldr insert Leaf

-- | Проверяет инвариант BST: для каждого узла все значения в левом поддереве
-- строго меньше значения узла, а в правом — строго больше.
--
-- >>> valid (fromList [1, 2, 3])
-- True
-- >>> valid (Node (Node Leaf 5 Leaf) 3 Leaf)
-- False
valid :: Ord a => BST a -> Bool
valid = go Nothing Nothing
  where
    go _ _ Leaf = True
    go lo hi (Node l v r) =
      maybe True (< v) lo
        && maybe True (v <) hi
        && go lo (Just v) l
        && go (Just v) hi r

-- | Глубина дерева (количество рёбер на самом длинном пути от корня до листа).
--
-- >>> depth Leaf
-- 0
-- >>> depth (fromList [2, 1, 3])
-- 1
depth :: BST a -> Int
depth Leaf         = 0
depth (Node l _ r) = 1 + max (depth l) (depth r)
