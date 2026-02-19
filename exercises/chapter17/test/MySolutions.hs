module MySolutions where

import Control.Lens
import Data.Char (toUpper)
import Data.Functor.Const (Const(..))
import Data.Functor.Identity (Identity(..))

import Data.Company

-- Упражнение 1: линзы для Person / Address
--
-- Определите типы Address и Person с полями, начинающимися с _.
-- Вызовите makeLenses для генерации линз.
-- Реализуйте getCity, setCity, upperName через view, set, over.

data Address = Address
  { _city    :: String
  , _street  :: String
  , _zipCode :: String
  } deriving stock (Show, Eq)

makeLenses ''Address

data Person = Person
  { _personName    :: String
  , _personAge     :: Int
  , _personAddress :: Address
  } deriving stock (Show, Eq)

makeLenses ''Person

getCity :: Person -> String
getCity = undefined

setCity :: String -> Person -> Person
setCity = undefined

upperName :: Person -> Person
upperName = undefined

-- Упражнение 2: повышение зарплаты через traversal
--
-- Используйте over, traversed и составные линзы, чтобы
-- увеличить зарплату ВСЕХ сотрудников компании на заданную сумму.
--
-- Путь: companyDepartments . traversed . departmentEmployees . traversed . employeeSalary

raiseSalary :: Double -> Company -> Company
raiseSalary = undefined

-- Упражнение 3: извлечение Right-значений через призму
--
-- Используйте toListOf, traversed и _Right, чтобы
-- извлечь все Right-значения из списка Either.

rightValues :: [Either String Int] -> [Int]
rightValues = undefined

-- Упражнение 4: van Laarhoven lens
--
-- Реализуйте собственную кодировку линз.
-- Линза — это функция, которая работает с любым Functor f:
--   type MyLens s a = forall f. Functor f => (a -> f a) -> s -> f s
--
-- myView использует Const для «чтения» значения.
-- myOver использует Identity для «модификации» значения.
-- mySet  реализуется через myOver.
-- fstL, sndL — линзы для элементов пары.

type MyLens s a = forall f. Functor f => (a -> f a) -> s -> f s

myView :: MyLens s a -> s -> a
myView _ _ = undefined

myOver :: MyLens s a -> (a -> a) -> s -> s
myOver _ _ _ = undefined

mySet :: MyLens s a -> a -> s -> s
mySet _ _ _ = undefined

fstL :: MyLens (a, b) a
fstL = undefined

sndL :: MyLens (a, b) b
sndL = undefined
