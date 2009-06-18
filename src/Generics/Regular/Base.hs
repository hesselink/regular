{-# LANGUAGE FlexibleContexts   #-}
{-# LANGUAGE TypeOperators      #-}
{-# LANGUAGE TypeFamilies       #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  Generics.Regular.Base
-- Copyright   :  (c) 2008 Universiteit Utrecht
-- License     :  BSD3
--
-- Maintainer  :  generics@haskell.org
-- Stability   :  experimental
-- Portability :  non-portable
--
-- Summary: Types for structural representation.
-----------------------------------------------------------------------------

module Generics.Regular.Base (

    -- * Functorial structural representation types.
    K (..),
    Id (..),
    Unit (..),
    (:+:) (..),
    (:*:) (..),
    Con (..),

    -- * Fixed-point type.
    Fix (..),

    -- * Type class capturing the structural representation of a type and the corresponding embedding-projection pairs.
    Regular (..)
    
  ) where


-----------------------------------------------------------------------------
-- Functorial structural representation types.
-----------------------------------------------------------------------------

-- | Structure type for constant values.
data K a r      = K a

-- | Structure type for recursive values.
data Id r       = Id r

-- | Structure type for empty constructors.
data Unit r     = Unit

-- | Structure type for alternatives in a type.
data (f :+: g) r  = L (f r) | R (g r)

-- | Structure type for fields of a constructor.
data (f :*: g) r = f r :*: g r

-- | Structure type to store the name of a constructor.
data Con f r    = Con String (f r)

infixr 6 :+:
infixr 7 :*:

-----------------------------------------------------------------------------
-- Fixed-point type.
-----------------------------------------------------------------------------

-- | The well-known fixed-point type.
newtype Fix f = In (f (Fix f))


-----------------------------------------------------------------------------
-- Type class capturing the structural representation of a type and the
-- corresponding embedding-projection pairs.
-----------------------------------------------------------------------------

-- | The type class @Regular@ captures the structural representation of a 
-- type and the corresponding embedding-projection pairs.
--
-- To be able to use the rewriting functions, the user is required to provide
-- an instance of this type class.
class Functor (PF a) => Regular a where
  type PF a :: * -> *
  from      :: a -> PF a a
  to        :: PF a a -> a

-----------------------------------------------------------------------------
-- Functorial map function.
-----------------------------------------------------------------------------

instance Functor Id where
  fmap f (Id r) = Id (f r)

instance Functor (K a) where
  fmap _ (K a) = K a

instance Functor Unit where
  fmap _ Unit = Unit

instance (Functor f, Functor g) => Functor (f :+: g) where
  fmap f (L x) = L (fmap f x)
  fmap f (R y) = R (fmap f y)

instance (Functor f, Functor g) => Functor (f :*: g) where
  fmap f (x :*: y) = fmap f x :*: fmap f y

instance Functor f => Functor (Con f) where
  fmap f (Con con r) = Con con (fmap f r)
