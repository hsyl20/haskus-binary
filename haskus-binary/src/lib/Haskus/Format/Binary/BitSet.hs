{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE FlexibleContexts #-}

-- | A bit set based on Enum to name the bits. Use bitwise operations and
-- minimal storage in a safer way.
--
-- Similar to Data.Bitset.Generic from bitset package, but
--
--     * We don't have the Num constraint
--     * We dont use the deprecated bitSize function
--     * We use countTrailingZeros instead of iterating on the
--     number of bits
--     * We add a typeclass CBitSet
--
-- Example:
--
-- @
-- {-# LANGUAGE DeriveAnyClass #-}
-- data Flag
--    = FlagXXX
--    | FlagYYY
--    | FlagWWW
--    deriving (Show,Eq,Enum,CBitSet)
--
-- -- Adapt the backing type, here we choose Word16
-- type Flags = 'BitSet' Word16 Flag
-- @
--
-- Then you can convert (for free) a Word16 into Flags with 'fromBits' and
-- convert back with 'toBits'.
--
-- You can check if a flag is set or not with 'member' and 'notMember' and get
-- a list of set flags with 'toList'. You can 'insert' or 'delete' flags. You
-- can also perform set operations such as 'union' and 'intersection'.
--
module Haskus.Format.Binary.BitSet
   ( BitSet
   , CBitSet (..)
   , null
   , empty
   , singleton
   , insert
   , delete
   , toBits
   , fromBits
   , member
   , elem
   , notMember
   , elems
   , intersection
   , union
   , unions
   , fromListToBits
   , toListFromBits
   , enumerateSetBits
   , fromList
   , toList
   )
where

import Prelude hiding (null,elem)

import qualified GHC.Exts as Ext

import Data.Foldable (foldl')

import Haskus.Format.Binary.Bits
import Haskus.Format.Binary.Storable

-- | A bit set: use bitwise operations (fast!) and minimal storage (sizeOf
-- basetype)
--
-- * b is the base type (Bits b)
-- * a is the element type (Enum a)
--
-- The elements in the Enum a are flags corresponding to each bit of b starting
-- from the least-significant bit.
newtype BitSet b a = BitSet b deriving (Eq,Ord,Storable)

instance
   ( Show a
   , CBitSet a
   , FiniteBits b
   , IndexableBits b
   , Eq b
   ) => Show (BitSet b a)
   where
      show b = "fromList " ++ show (toList b)

-- | Indicate if the set is empty
null ::
   ( FiniteBits b
   , Eq b
   ) => BitSet b a -> Bool
{-# INLINE null #-}
null (BitSet b) = b == zeroBits


-- | Empty bitset
empty :: (FiniteBits b) => BitSet b a
{-# INLINE empty #-}
empty = BitSet zeroBits


-- | Create a BitSet from a single element
singleton :: (IndexableBits b, CBitSet a) => a -> BitSet b a
{-# INLINE singleton #-}
singleton e = BitSet $ bit (toBitOffset e)


-- | Insert an element in the set
insert :: (IndexableBits b, CBitSet a) => BitSet b a -> a -> BitSet b a
{-# INLINE insert #-}
insert (BitSet b) e = BitSet $ setBit b (toBitOffset e)


-- | Remove an element from the set
delete :: (IndexableBits b, CBitSet a) => BitSet b a -> a -> BitSet b a
{-# INLINE delete #-}
delete (BitSet b) e = BitSet $ clearBit b (toBitOffset e)


-- | Unwrap the bitset
toBits :: BitSet b a -> b
toBits (BitSet b) = b

-- | Wrap a bitset
fromBits :: (CBitSet a, FiniteBits b) => b -> BitSet b a
fromBits = BitSet

-- | Test if an element is in the set
member ::
   ( CBitSet a
   , FiniteBits b
   , IndexableBits b
   ) => BitSet b a -> a -> Bool
{-# INLINE member #-}
member (BitSet b) e = testBit b (toBitOffset e)


-- | Test if an element is in the set
elem ::
   ( CBitSet a
   , FiniteBits b
   , IndexableBits b
   ) => a -> BitSet b a -> Bool
{-# INLINE elem #-}
elem e (BitSet b) = testBit b (toBitOffset e)


-- | Test if an element is not in the set
notMember ::
   ( CBitSet a
   , FiniteBits b
   , IndexableBits b
   ) => BitSet b a -> a -> Bool
{-# INLINE notMember #-}
notMember b e = not (member b e)


-- | Retrieve elements in the set
elems ::
   ( CBitSet a
   , FiniteBits b
   , IndexableBits b
   , Eq b
   ) => BitSet b a -> [a]
elems (BitSet b) = go b
   where
      go !c
         | c == zeroBits = []
         | otherwise     = let e = countTrailingZeros c in fromBitOffset e : go (clearBit c e)

-- | Intersection of two sets
intersection ::
   ( FiniteBits b
   , Bitwise b
   ) => BitSet b a -> BitSet b a -> BitSet b a
{-# INLINE intersection #-}
intersection (BitSet b1) (BitSet b2) = BitSet (b1 .&. b2)


-- | Intersection of two sets
union ::
   ( FiniteBits b
   , Bitwise b
   ) => BitSet b a -> BitSet b a -> BitSet b a
{-# INLINE union #-}
union (BitSet b1) (BitSet b2) = BitSet (b1 .|. b2)


-- | Intersection of several sets
unions ::
   ( FiniteBits b
   , Bitwise b
   ) => [BitSet b a] -> BitSet b a
{-# INLINE unions #-}
unions = foldl' union empty


-- | Bit set indexed with a
class CBitSet a where
   -- | Return the bit offset of an element
   toBitOffset         :: a -> Word
   default toBitOffset :: Enum a => a -> Word
   toBitOffset         = fromIntegral . fromEnum

   -- | Return the value associated with a bit offset
   fromBitOffset         :: Word -> a
   default fromBitOffset :: Enum a => Word -> a
   fromBitOffset         = toEnum . fromIntegral

-- | It can be useful to get the indexes of the set bits
instance CBitSet Int where
   toBitOffset   = fromIntegral
   fromBitOffset = fromIntegral

-- | It can be useful to get the indexes of the set bits
instance CBitSet Word where
   toBitOffset   = id
   fromBitOffset = id
   


-- | Convert a list of enum elements into a bitset Warning: b
-- must have enough bits to store the given elements! (we don't
-- perform any check, for performance reason)
fromListToBits ::
   ( CBitSet a
   , FiniteBits b
   , IndexableBits b
   , Foldable m
   ) => m a -> b
fromListToBits = toBits . fromList

-- | Convert a bitset into a list of Enum elements
toListFromBits ::
   ( CBitSet a
   , FiniteBits b
   , IndexableBits b
   , Eq b
   ) => b -> [a]
toListFromBits = toList . BitSet

-- | Convert a bitset into a list of Enum elements by testing the Enum values
-- successively.
--
-- The difference with `toListFromBits` is that extra values in the BitSet will
-- be ignored.
enumerateSetBits ::
   ( CBitSet a
   , FiniteBits b
   , IndexableBits b
   , Eq b
   , Bounded a
   , Enum a
   ) => b -> [a]
enumerateSetBits b = go [] [minBound..]
   where
      go rs []     = rs
      go rs (x:xs)
         | member (BitSet b) x = go (x:rs) xs
         | otherwise           = go rs xs

-- | Convert a set into a list
toList ::
   ( CBitSet a
   , FiniteBits b
   , IndexableBits b
   , Eq b
   ) => BitSet b a -> [a]
toList = elems

-- | Convert a Foldable into a set
fromList ::
   ( CBitSet a
   , IndexableBits b
   , FiniteBits b
   , Foldable m
   ) => m a -> BitSet b a
fromList = foldl' insert (BitSet zeroBits)


instance
   ( FiniteBits b
   , IndexableBits b
   , CBitSet a
   , Eq b
   ) => Ext.IsList (BitSet b a)
   where
      type Item (BitSet b a) = a
      fromList = fromList
      toList   = toList
