{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE MagicHash #-}

-- | Unsigned and signed words
module Haskus.Format.Binary.Word
   ( WordAtLeast
   , IntAtLeast
   , WordN
   , IntN
   -- * Some C types
   , CSize(..)
   , CUShort
   , CShort
   , CUInt
   , CInt
   , CULong
   , CLong
   -- * Unlifted
   , module GHC.Word
   , module GHC.Int
   , Word#
   , Int#
   , plusWord#
   , minusWord#
   , (+#)
   , (-#)
   , (==#)
   , (>#)
   , (<#)
   , (>=#)
   , (<=#)
   , ltWord#
   , leWord#
   , gtWord#
   , geWord#
   , eqWord#
   , isTrue#
   )
where

import Data.Word
import Data.Int
import Foreign.C.Types
import GHC.Word
import GHC.Int
import GHC.Exts

import Haskus.Utils.Types

-- | Return a Word with at least 'n' bits
type family WordAtLeast (n :: Nat) where
   WordAtLeast n =
       If (n <=? 8) Word8
      (If (n <=? 16) Word16
      (If (n <=? 32) Word32
      (Assert (n <=? 64) Word64
      ('Text "Cannot find Word with size " ':<>: 'ShowType n)
      )))

-- | Return a Int with at least 'n' bits
type family IntAtLeast (n :: Nat) where
   IntAtLeast n =
       If (n <=? 8) Int8
      (If (n <=? 16) Int16
      (If (n <=? 32) Int32
      (Assert (n <=? 64) Int64
      ('Text "Cannot find Int with size " ':<>: 'ShowType n)
      )))

-- | Return a Word with exactly 'n' bits
type family WordN (n :: Nat) where
   WordN 8  = Word8
   WordN 16 = Word16
   WordN 32 = Word32
   WordN 64 = Word64
   WordN n  = TypeError ('Text "Cannot find Word with size " ':<>: 'ShowType n)

-- | Return a Int with exactly 'n' bits
type family IntN (n :: Nat) where
   IntN 8  = Int8
   IntN 16 = Int16
   IntN 32 = Int32
   IntN 64 = Int64
   IntN n  = TypeError ('Text "Cannot find Int with size " ':<>: 'ShowType n)
