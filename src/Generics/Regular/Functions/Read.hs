{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE TypeOperators         #-}
{-# LANGUAGE ScopedTypeVariables   #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  Generics.Regular.Functions.Read
-- Copyright   :  (c) 2010 Universiteit Utrecht
-- License     :  BSD3
--
-- Maintainer  :  generics@haskell.org
-- Stability   :  experimental
-- Portability :  non-portable
--
-- Summary: Generic read. This module is not exported by 
-- "Generics.Regular.Functions" to avoid clashes with "Prelude".
-----------------------------------------------------------------------------

module Generics.Regular.Functions.Read (

    -- * Read functions
    Read(..),
    read, readPrec, readsPrec

) where

-----------------------------------------------------------------------------
-- Generic read.
-----------------------------------------------------------------------------

import Generics.Regular.Base

import Data.Char
import Control.Monad
import Text.Read hiding (readsPrec, readPrec, read, Read)
import Prelude hiding (readsPrec, read, Read)
import qualified Prelude as P (readsPrec, Read)

-- * Count the number of terms in a product

class CountAtoms f where 
  countatoms :: f r -> Int

instance CountAtoms (K a) where
  countatoms _ = 1

instance CountAtoms I where
  countatoms _ = 1

instance (CountAtoms f, CountAtoms g) => CountAtoms (f :*: g) where
  countatoms (_ :: (f :*: g) r) = countatoms (undefined :: f r) 
                                + countatoms (undefined :: g r)

instance CountAtoms f => CountAtoms (S s f) where
  countatoms (_ :: S s f r) = countatoms (undefined :: f r)

-- * Generic read

class Read f where
   hreader :: ReadPrec a -> Bool -> ReadPrec (f a)


instance Read U where
   hreader _ _ = return U

instance (P.Read a) => Read (K a) where
   hreader _ _ = liftM K (readS_to_Prec P.readsPrec)

instance Read I where
   hreader f _ = liftM I f

instance (Read f, Read g) => Read (f :+: g) where
   hreader f r = liftM L (hreader f r) +++ liftM R (hreader f r)

instance (Read f, Read g) => Read (f :*: g) where
   hreader f r = do l' <- hreader f r
                    when r $ do Punc "," <- lexP
                                return ()
                    r' <- hreader f r
                    return (l' :*: r')



-- Dealing with constructors
-- No arguments
instance (Constructor c) => Read (C c U) where
   hreader f _ = let constr = undefined :: C c U r
                     name   = conName constr
                 in readCons (readNoArgsCons f name)

-- 1 argument
instance (Constructor c, Read I) => Read (C c I) where
   hreader f _ = let constr = undefined :: C c I r
                     name   = conName constr
                 in  readCons (readPrefixCons f True False name)

instance (Constructor c, Read (K a)) => Read (C c (K a)) where
   hreader f _ = let constr = undefined :: C c (K a) r
                     name   = conName constr
                 in  readCons (readPrefixCons f True False name) 

instance (Constructor c, Read (S s f)) => Read (C c (S s f)) where
   hreader f _ = let constr = undefined :: C c (K a) r
                     name   = conName constr
                 in  readCons (readPrefixCons f True True name)

-- 2 arguments or more
instance (Constructor c, CountAtoms f, CountAtoms g, Read f, Read g) 
         => Read (C c (f:*:g)) where
   hreader f _ = let constr = undefined :: C c (f:*:g) r
                     name   = conName constr
                     fixity = conFixity constr
                     isRecord = conIsRecord constr
                     (assoc,prc,isInfix) = case fixity of 
                                             Prefix    -> (LeftAssociative, 9, False)
                                             Infix a p -> (a, p, True)
                     nargs  = countatoms (undefined :: (f :*: g) r)
                 in  readCons $ readPrefixCons f (not isInfix) isRecord name
                                         +++
                                (do guard (nargs == 2)
                                    readInfixCons f (assoc,prc,isInfix) name
                                )


readCons :: (Constructor c) => ReadPrec (f a) -> ReadPrec (C c f a)
readCons = liftM C

readPrefixCons :: (Read f) 
               => ReadPrec a -> Bool -> Bool -> String -> ReadPrec (f a)
readPrefixCons f b r name = parens . prec appPrec $
                            do parens (prefixConsNm name b) 
                               step $ if r then braces (hreader f) else hreader f False
    where prefixConsNm s True  = do Ident n <- lexP
                                    guard (s == n)
          prefixConsNm s False = do Punc "(" <-lexP
                                    Symbol n <- lexP
                                    guard (s == n)
                                    Punc ")" <- lexP
                                    return ()

braces :: (Bool -> ReadPrec a) -> ReadPrec a
braces f = do hasBraces <- try $ do {Punc "{" <- lexP; return ()}
              res <- f hasBraces
              when hasBraces $ do {Punc "}" <- lexP; return ()}
              return res
           where
             try p = (p >> return True) `mplus` return False


readInfixCons :: (Read f, Read g)
              => ReadPrec a -> (Associativity,Int,Bool) -> String -> ReadPrec ((f :*: g) a)
readInfixCons f (asc,prc,b) name = parens . prec prc $
                                       do x <- {- (if asc == LeftAssociative  then id else step) -} step (hreader f False)
                                          parens (infixConsNm name b)
                                          y <- (if asc == RightAssociative then id else step) (hreader f False)
                                          return  (x :*: y)
     where  infixConsNm s True  = do Symbol n <- lexP
                                     guard (n == s) 
            infixConsNm s False = do Punc "`"  <- lexP
                                     Ident n   <- lexP
                                     guard (n == s)
                                     Punc "`"  <- lexP
                                     return ()

readNoArgsCons :: ReadPrec a -> String -> ReadPrec (U a)
readNoArgsCons _ name = parens $ 
                             do Ident n <- lexP
                                guard (n == name)
                                return U

appPrec :: Prec
appPrec = 10

instance (Selector s, Read f) => Read (S s f) where
   hreader f r = do when r $ do Ident n <- lexP
                                guard (n == selName (undefined :: S s f a))
                                Punc "=" <- lexP
                                return ()
                    liftM S (hreader f r)


-- Exported functions

readPrec :: (Regular a, Read (PF a)) => ReadPrec a
readPrec = liftM to (hreader readPrec False)

readsPrec :: (Regular a, Read (PF a)) => Int -> ReadS a
readsPrec n = readPrec_to_S readPrec n

read :: (Regular a, Read (PF a)) => String -> a
read s = case [x |  (x,remain) <- readsPrec 0 s , all isSpace remain] of
           [x] -> x 
           [ ] -> error "no parse"
           _   -> error "ambiguous parse"
