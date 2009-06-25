{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeOperators     #-}
{-# LANGUAGE TypeFamilies      #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  Generics.Regular.Functions
-- Copyright   :  (c) 2008 Universiteit Utrecht
-- License     :  BSD3
--
-- Maintainer  :  generics@haskell.org
-- Stability   :  experimental
-- Portability :  non-portable
--
-- Summary: Generic functionality for regular dataypes: mapM, flatten, zip,
-- equality, show and value generation.
-----------------------------------------------------------------------------

module Generics.Regular.Functions (

  -- * Functorial map function.
  Functor (..),
  
  -- * Monadic functorial map function.
  GMap (..),
  
  -- * Crush functions.
  Crush (..),
  flatten,

  -- * Zip functions.
  Zip (..),
  fzip,
  fzip',

  -- * Equality function.
  geq,

  -- * Show function.
  GShow (..),
  gshow,
  
  -- * Functions for generating values that are different on top-level.
  LRBase (..),
  LR (..),
  left,
  right,
  
  -- * Functions for generating values that are different on top-level.
  Alg, Algebra,
  Fold, alg,
  fold,
  (&)  

) where

import Control.Monad

import Generics.Regular.Base


-----------------------------------------------------------------------------
-- Monadic functorial map function.
-----------------------------------------------------------------------------

-- | The @GMap@ class defines a monadic functorial map.
class GMap f where
  fmapM :: Monad m => (a -> m b) -> f a -> m (f b)

instance GMap I where
  fmapM f (I r) = liftM I (f r)

instance GMap (K a) where
  fmapM _ (K x)  = return (K x)

instance GMap U where
  fmapM _ U = return U

instance (GMap f, GMap g) => GMap (f :+: g) where
  fmapM f (L x) = liftM L (fmapM f x)
  fmapM f (R x) = liftM R (fmapM f x)

instance (GMap f, GMap g) => GMap (f :*: g) where
  fmapM f (x :*: y) = liftM2 (:*:) (fmapM f x) (fmapM f y)

instance GMap f => GMap (C c f) where
  fmapM f (C x) = liftM C (fmapM f x)


-----------------------------------------------------------------------------
-- Crush functions.
-----------------------------------------------------------------------------

-- | The @Crush@ class defines a crush on functorial values. In fact,
-- @crush@ is a generalized @foldr@.
class Crush f where
  crush :: (a -> b -> b) -> b -> f a -> b

instance Crush I where
  crush op e (I x) = x `op` e

instance Crush (K a) where
  crush _ e _ = e

instance Crush U where
  crush _ e _ = e

instance (Crush f, Crush g) => Crush (f :+: g) where
  crush op e (L x) = crush op e x
  crush op e (R y) = crush op e y

instance (Crush f, Crush g) => Crush (f :*: g) where
  crush op e (x :*: y) = crush op (crush op e y) x

instance Crush f => Crush (C c f) where
  crush op e (C x) = crush op e x

-- | Flatten a structure by collecting all the elements present.
flatten :: Crush f => f a -> [a]
flatten = crush (:) []


-----------------------------------------------------------------------------
-- Zip functions.
-----------------------------------------------------------------------------

-- | The @Zip@ class defines a monadic zip on functorial values.
class Zip f where
  fzipM :: Monad m => (a -> b -> m c) -> f a -> f b -> m (f c)

instance Zip I where
  fzipM f (I x) (I y) = liftM I (f x y)

instance Eq a => Zip (K a) where
  fzipM _ (K x) (K y) 
    | x == y    = return (K x)
    | otherwise = fail "fzipM: structure mismatch"

instance Zip U where
  fzipM _ U U = return U

instance (Zip f, Zip g) => Zip (f :+: g) where
  fzipM f (L x) (L y) = liftM L (fzipM f x y)
  fzipM f (R x) (R y) = liftM R (fzipM f x y)
  fzipM _ _       _       = fail "fzipM: structure mismatch"

instance (Zip f, Zip g) => Zip (f :*: g) where
  fzipM f (x1 :*: y1) (x2 :*: y2) = 
    liftM2 (:*:) (fzipM f x1 x2)
                 (fzipM f y1 y2)

instance Zip f => Zip (C c f) where
  fzipM f (C x) (C y) = liftM C (fzipM f x y)

-- | Functorial zip with a non-monadic function, resulting in a monadic value.
fzip  :: (Zip f, Monad m) => (a -> b -> c) -> f a -> f b -> m (f c)
fzip f = fzipM (\x y -> return (f x y))

-- | Partial functorial zip with a non-monadic function.
fzip' :: Zip f => (a -> b -> c) -> f a -> f b -> f c
fzip' f x y = maybe (error "fzip': structure mismatch") id (fzip f x y)


-----------------------------------------------------------------------------
-- Equality function.
-----------------------------------------------------------------------------

-- | Equality on values based on their structural representation.
geq :: (b ~ PF a, Regular a, Crush b, Zip b) => a -> a -> Bool
geq x y = maybe False (crush (&&) True) (fzip geq (from x) (from y))


-----------------------------------------------------------------------------
-- Show function.
-----------------------------------------------------------------------------

-- | The @GShow@ class defines a show on values.
class GShow f where
  gshowf :: (a -> ShowS) -> f a -> ShowS

instance GShow I where
  gshowf f (I r) = f r

instance Show a => GShow (K a) where
  gshowf _ (K x) = shows x

instance GShow U where
  gshowf _ U = id

instance (GShow f, GShow g) => GShow (f :+: g) where
  gshowf f (L x) = gshowf f x
  gshowf f (R x) = gshowf f x

instance (GShow f, GShow g) => GShow (f :*: g) where
  gshowf f (x :*: y) = gshowf f x . showChar ' ' . gshowf f y


instance (Constructor c, GShow f) => GShow (C c f) where
  gshowf f cx@(C x) = 
    showParen True (showString (conName cx) . showChar ' ' . gshowf f x)


gshow :: (Regular a, GShow (PF a)) => a -> ShowS
gshow x = gshowf gshow (from x)

-----------------------------------------------------------------------------
-- Functions for generating values that are different on top-level.
-----------------------------------------------------------------------------

-- | The @LRBase@ class defines two functions, @leftb@ and @rightb@, which 
-- should produce different values.
class LRBase a where
  leftb  :: a
  rightb :: a

instance LRBase Int where
  leftb  = 0
  rightb = 1

instance LRBase Integer where
  leftb  = 0
  rightb = 1

instance LRBase Char where
  leftb  = 'L'
  rightb = 'R'
 
instance LRBase a => LRBase [a] where
  leftb  = []
  rightb = [error "Should never be inspected"]

-- | The @LR@ class defines two functions, @leftf@ and @rightf@, which should 
-- produce different functorial values.
class LR f where
  leftf  :: a -> f a
  rightf :: a -> f a

instance LR I where
  leftf  x = I x
  rightf x = I x

instance LRBase a => LR (K a) where
  leftf  _ = K leftb
  rightf _ = K rightb

instance LR U where
  leftf  _ = U
  rightf _ = U

instance (LR f, LR g) => LR (f :+: g) where
  leftf  x = L (leftf x)
  rightf x = R (rightf x)

instance (LR f, LR g) => LR (f :*: g) where
  leftf  x = leftf x :*: leftf x
  rightf x = rightf x :*: rightf x

instance LR f => LR (C c f) where
  leftf  x = C (leftf x)
  rightf x = C (rightf x)

-- | Produces a value which should be different from the value returned by 
-- @right@.
left :: (Regular a, LR (PF a)) => a
left = to (leftf left)

-- | Produces a value which should be different from the value returned by 
-- @left@.
right :: (Regular a, LR (PF a)) => a
right = to (rightf right)


-----------------------------------------------------------------------------
-- Folds
-----------------------------------------------------------------------------

type family Alg (f :: (* -> *)) 
                (r :: *) -- result type
                :: *

-- | For a constant, we take the constant value to a result.
type instance Alg (K a) r = a -> r

-- | For a unit, no arguments are available.
type instance Alg U r = r

-- | For an identity, we turn the recursive result into a final result.
type instance Alg I r = r -> r

-- | For a sum, the algebra is a pair of two algebras.
type instance Alg (f :+: g) r = (Alg f r, Alg g r)

-- | For a product where the left hand side is a constant, we
--   take the value as an additional argument.
type instance Alg (K a :*: g) r = a -> Alg g r

-- | For a product where the left hand side is an identity, we
--   take the recursive result as an additional argument.
type instance Alg (I :*: g) r = r -> Alg g r

-- | Constructors are ignored.
type instance Alg (C c f) r = Alg f r


type Algebra a r = Alg (PF a) r

-- * The class to turn convenient algebras into standard algebras.

-- | The class fold explains how to convert a convenient algebra
--   'Alg' back into a function from functor to result, as required
--   by the standard fold function.
class Fold (f :: * -> *) where
  alg :: Alg f r -> f r -> r

instance Fold (K a) where
  alg f (K x) = f x

instance Fold U where
  alg f U     = f

instance Fold I where
  alg f (I x) = f x

instance (Fold f, Fold g) => Fold (f :+: g) where
  alg (f, _) (L x) = alg f x
  alg (_, g) (R x) = alg g x

instance (Fold g) => Fold (K a :*: g) where
  alg f (K x :*: y) = alg (f x) y

instance (Fold g) => Fold (I :*: g) where
  alg f (I x :*: y) = alg (f x) y

instance (Fold f) => Fold (C c f) where
  alg f (C x) = alg f x

-- * Interface

-- | Fold with convenient algebras.
fold :: (Regular a, Fold (PF a), Functor (PF a))
     => Algebra a r -> a -> r
fold f = alg f . fmap (\x -> fold f x) . from

-- * Construction of algebras

infixr 5 &

-- | For constructing algebras that are made of nested pairs rather
--   than n-ary tuples, it is helpful to use this pairing combinator.
(&) :: a -> b -> (a, b)
(&) = (,)
