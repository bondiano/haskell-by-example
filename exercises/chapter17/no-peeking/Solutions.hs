module Solutions where

import Control.Lens
import Data.Char (toUpper)
import Data.Functor.Const (Const(..))
import Data.Functor.Identity (Identity(..))

import Data.Company

-- Упражнение 1: линзы для Person / Address

data Address = Address
  { _city   :: String
  , _street :: String
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
getCity = view (personAddress . city)

setCity :: String -> Person -> Person
setCity = set (personAddress . city)

upperName :: Person -> Person
upperName = over personName (map toUpper)

-- Упражнение 2: повышение зарплаты через traversal

raiseSalary :: Double -> Company -> Company
raiseSalary amount =
  over (companyDepartments . traversed . departmentEmployees . traversed . employeeSalary)
       (+ amount)

-- Упражнение 3: извлечение Right-значений через призму

rightValues :: [Either String Int] -> [Int]
rightValues = toListOf (traversed . _Right)

-- Упражнение 4: van Laarhoven lens

type MyLens s a = forall f. Functor f => (a -> f a) -> s -> f s

myView :: MyLens s a -> s -> a
myView l s = getConst (l Const s)

myOver :: MyLens s a -> (a -> a) -> s -> s
myOver l f s = runIdentity (l (Identity . f) s)

mySet :: MyLens s a -> a -> s -> s
mySet l a = myOver l (const a)

fstL :: MyLens (a, b) a
fstL f (a, b) = (\a' -> (a', b)) <$> f a

sndL :: MyLens (a, b) b
sndL f (a, b) = (\b' -> (a, b')) <$> f b
