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
    K(..),
    I(..),
    U(..),
    (:+:)(..),
    (:*:)(..),
    C(..),
    Constructor(..), Fixity(..), Associativity(..),

    -- * Fixed-point type.
    Fix (..),

    -- * Type class capturing the structural representation of a type and the corresponding embedding-projection pairs.
    Regular (..)
    
  ) where


-----------------------------------------------------------------------------
-- Functorial structural representation types.
-----------------------------------------------------------------------------

-- | Structure type for constant values.
data K a r       = K a

-- | Structure type for recursive values.
data I r         = I r

-- | Structure type for empty constructors.
data U r         = U

-- | Structure type for alternatives in a type.
data (f :+: g) r = L (f r) | R (g r)

-- | Structure type for fields of a constructor.
data (f :*: g) r = f r :*: g r

-- | Structure type to store the name of a constructor.
data C c f r =  C { unC :: f r }

-- | Class for datatypes that represent data constructors.
-- For non-symbolic constructors, only 'conName' has to be defined.
-- The weird argument is supposed to be instantiated with 'C' from
-- base, hence the complex kind.
class Constructor c where
  conName   :: t c (f :: * -> *) r -> String
  conFixity :: t c (f :: * -> *) r -> Fixity
  conFixity = const Prefix

-- | Datatype to represent the fixity of a constructor. An infix declaration
-- directly corresponds to an application of 'Infix'.
data Fixity = Prefix | Infix Associativity Int
  deriving (Eq, Show, Ord, Read)

data Associativity = LeftAssociative | RightAssociative | NotAssociative
  deriving (Eq, Show, Ord, Read)

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

instance Functor I where
  fmap f (I r) = I (f r)

instance Functor (K a) where
  fmap _ (K a) = K a

instance Functor U where
  fmap _ U = U

instance (Functor f, Functor g) => Functor (f :+: g) where
  fmap f (L x) = L (fmap f x)
  fmap f (R y) = R (fmap f y)

instance (Functor f, Functor g) => Functor (f :*: g) where
  fmap f (x :*: y) = fmap f x :*: fmap f y

instance Functor f => Functor (C c f) where
  fmap f (C r) = C (fmap f r)

