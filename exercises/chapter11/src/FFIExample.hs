module FFIExample
  ( cAbs
  , cStrlen
  ) where

import Foreign.C.Types (CInt(..), CSize(..))
import Foreign.C.String (CString, withCString)

foreign import ccall "stdlib.h abs" c_abs :: CInt -> CInt

foreign import ccall "string.h strlen" c_strlen :: CString -> CSize

-- | Абсолютное значение через C-функцию @abs@.
--
-- >>> cAbs (-42)
-- 42
cAbs :: Int -> Int
cAbs = fromIntegral . c_abs . fromIntegral

-- | Длина строки через C-функцию @strlen@.
--
-- >>> cStrlen "hello"
-- 5
cStrlen :: String -> IO Int
cStrlen s = withCString s $ \cs ->
  return (fromIntegral (c_strlen cs))
