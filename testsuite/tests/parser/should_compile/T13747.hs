{-# LANGUAGE TypeFamilies #-}

module T13747 where

class C a where
  type family T a :: *

instance C Int where
  type instance T Int = Int
