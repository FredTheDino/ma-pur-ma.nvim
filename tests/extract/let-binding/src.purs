module A where

import Prelude

f :: Int -> Int -> Int
f a b =
  let
    q1 = a + 1
    q2 = b + 1
  in
  q1 + q2
