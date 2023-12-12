module A where

import Prelude

f a = (extracted a) + a + 1

extracted a =
  a + a + a
