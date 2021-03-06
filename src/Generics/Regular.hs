-----------------------------------------------------------------------------
-- |
-- Module      :  Generics.Regular
-- Copyright   :  (c) 2008 Universiteit Utrecht
-- License     :  BSD3
--
-- Maintainer  :  generics@haskell.org
-- Stability   :  experimental
-- Portability :  non-portable
--
-- Summary: Top-level module for this library.
-- By importing this module, the user is able to use all the generic
-- functionality. The user is only required to provide an instance of
-- @Regular@ for the datatype.
--
-- Consider a datatype representing logical expressions:
--
-- >  data Logic = Var String
-- >             | Logic :->:  Logic  -- implication
-- >             | Logic :<->: Logic  -- equivalence
-- >             | Logic :&&:  Logic  -- and (conjunction)
-- >             | Logic :||:  Logic  -- or (disjunction)
-- >             | Not Logic          -- not
-- >             | T                  -- true
-- >             | F                  -- false
--
-- First we import the relevant modules:
--
-- > import Generics.Regular
-- > import Generics.Regular.Functions
-- > import qualified Generics.Regular.Functions.Show as G
-- > import qualified Generics.Regular.Functions.Read as G
--
-- An instance of @Regular@ can be derived automatically with TH by invoking:
--
-- > $(deriveAll ''Logic "PFLogic")
-- > type instance PF Logic = PFLogic
--
-- We define some logic expressions:
--
-- > l1, l2, l3 :: Logic
-- > l1 = Var "p"
-- > l2 = Not l1
-- > l3 = l1 :->: l2
--
-- And now we can use all of the generic functions. Flattening:
--
-- > ex0 :: [Logic]
-- > ex0 = flattenr (from l3)
-- >
-- > > [Var "p",Not (Var "p")]
--
-- Generic equality:
--
-- > ex1, ex2 :: Bool
-- > ex1 = eq l3 l3
-- >
-- > > True
-- >
-- >
-- > ex2 = eq l3 l2
-- >
-- > > False
--
-- Generic show:
--
-- > ex3 :: String
-- > ex3 = G.show l3
-- >
-- > > "((:->:) (Var \"p\") (Not (Var \"p\")))"
--
-- Generic read:
--
-- > ex4 :: Logic
-- > ex4 = G.read ex3
-- >
-- > > Var "p" :->: Not (Var "p")
--
-- Value generation:
--
-- > ex5, ex6 :: Logic
-- > ex5 = left
-- >
-- > > Var ""
-- >
-- >
-- > ex6 = right
-- >
-- > > F
--
-- Folding:
--
-- > ex7 :: Bool
-- > ex7 = fold (alg (\_ -> False)) l3 where
-- >   alg env = (env & impl & (==) & (&&) & (||) & not & True & False)
-- >   impl p q = not p || q
-- >
-- > > True
--
-- Unfolding:
--
-- > ex8 :: Logic
-- > ex8 = unfold alg 8 where
-- >   alg :: CoAlgebra Logic Int
-- >   alg n | odd n || n <= 0 = Left ""
-- >         | even n          = Right (Left (n-1,n-2))
-- >
-- > > Var "" :->: (Var "" :->: (Var "" :->: (Var "" :->: Var "")))
--
-- Constructor names:
--
-- > ex9 = conNames (undefined :: Logic)
-- >
-- > > ["Var",":->:",":<->:",":&&:",":||:","Not","T","F"]
--
-- Deep seq:
--
-- > ex10 = gdseq (Not (T :->: (error "deep seq works"))) ()
-- >
-- > > *** Exception: deep seq works
-- 
-----------------------------------------------------------------------------

module Generics.Regular (
    module Generics.Regular.Base,
    module Generics.Regular.TH,
    module Generics.Regular.Functions
  ) where

import Generics.Regular.Base
import Generics.Regular.TH
import Generics.Regular.Functions
