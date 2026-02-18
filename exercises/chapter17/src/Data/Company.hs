module Data.Company
  ( -- * Типы
    Employee(..)
  , Department(..)
  , Company(..)
    -- * Линзы
  , employeeName
  , employeeSalary
  , departmentName
  , departmentEmployees
  , companyName
  , companyDepartments
    -- * Пример
  , exampleCompany
  ) where

import Control.Lens.TH (makeLenses)

-- | Сотрудник.
data Employee = Employee
  { _employeeName   :: String
  , _employeeSalary :: Double
  } deriving stock (Show, Eq)

makeLenses ''Employee

-- | Отдел.
data Department = Department
  { _departmentName      :: String
  , _departmentEmployees :: [Employee]
  } deriving stock (Show, Eq)

makeLenses ''Department

-- | Компания.
data Company = Company
  { _companyName        :: String
  , _companyDepartments :: [Department]
  } deriving stock (Show, Eq)

makeLenses ''Company

-- | Пример компании для упражнений.
exampleCompany :: Company
exampleCompany = Company "Acme"
  [ Department "Разработка"
      [ Employee "Алиса" 100000
      , Employee "Борис" 90000
      ]
  , Department "Маркетинг"
      [ Employee "Вера" 85000
      ]
  ]
