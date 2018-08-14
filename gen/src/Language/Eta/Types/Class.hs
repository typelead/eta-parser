-- (c) The University of Glasgow 2006
-- (c) The GRASP/AQUA Project, Glasgow University, 1992-1998
--
-- The @Class@ datatype

{-# LANGUAGE CPP, DeriveDataTypeable #-}

module Language.Eta.Types.Class (
        Class,
        ClassOpItem, DefMeth (..),
        ClassATItem(..),
        ClassMinimalDef,
        defMethSpecOfDefMeth,

        FunDep, pprFundeps, pprFunDep,

        mkClass, classTyVars, classArity,
        classKey, className, classATs, classATItems, classTyCon, classMethods,
        classOpItems, classBigSig, classExtraBigSig, classTvsFds, classSCTheta,
        classAllSelIds, classSCSelId, classMinimalDef
    ) where

#include "HsVersions.h"

import {-# SOURCE #-} Language.Eta.Types.TyCon     ( TyCon, tyConName, tyConUnique )
import {-# SOURCE #-} Language.Eta.Types.TypeRep   ( Type, PredType )
import Language.Eta.BasicTypes.Var
import Language.Eta.BasicTypes.Name
import Language.Eta.BasicTypes.BasicTypes
import Language.Eta.BasicTypes.Unique
import Language.Eta.Utils.Util
import Language.Eta.BasicTypes.SrcLoc
import Language.Eta.Utils.Outputable
import Language.Eta.Utils.FastString
import Language.Eta.Utils.BooleanFormula (BooleanFormula)

import Data.Typeable (Typeable)
import qualified Data.Data as Data

{-
************************************************************************
*                                                                      *
\subsection[Class-basic]{@Class@: basic definition}
*                                                                      *
************************************************************************

A @Class@ corresponds to a Greek kappa in the static semantics:
-}

data Class
  = Class {
        classTyCon :: TyCon,    -- The data type constructor for
                                -- dictionaries of this class
                                -- See Note [ATyCon for classes] in TypeRep

        className :: Name,              -- Just the cached name of the TyCon
        classKey  :: Unique,            -- Cached unique of TyCon

        classTyVars  :: [TyVar],        -- The class kind and type variables;
                                        -- identical to those of the TyCon

        classFunDeps :: [FunDep TyVar], -- The functional dependencies

        -- Superclasses: eg: (F a ~ b, F b ~ G a, Eq a, Show b)
        -- We need value-level selectors for both the dictionary
        -- superclasses and the equality superclasses
        classSCTheta :: [PredType],     -- Immediate superclasses,
        classSCSels  :: [Id],           -- Selector functions to extract the
                                        --   superclasses from a
                                        --   dictionary of this class
        -- Associated types
        classATStuff :: [ClassATItem],  -- Associated type families

        -- Class operations (methods, not superclasses)
        classOpStuff :: [ClassOpItem],  -- Ordered by tag

        -- Minimal complete definition
        classMinimalDef :: ClassMinimalDef
     }
  deriving Typeable

--  | e.g.
--
-- >  class C a b c | a b -> c, a c -> b where...
--
--  Here fun-deps are [([a,b],[c]), ([a,c],[b])]
--
--  - 'ApiAnnotation.AnnKeywordId' : 'ApiAnnotation.AnnRarrow'',

-- For details on above see note [Api annotations] in ApiAnnotation
type FunDep a = ([a],[a])

type ClassOpItem = (Id, DefMeth)
        -- Selector function; contains unfolding
        -- Default-method info

data DefMeth = NoDefMeth                -- No default method
             | DefMeth Name             -- A polymorphic default method
             | GenDefMeth Name          -- A generic default method
             deriving Eq

data ClassATItem
  = ATI TyCon         -- See Note [Associated type tyvar names]
        (Maybe (Type, SrcSpan))
                      -- Default associated type (if any) from this template
                      -- Note [Associated type defaults]

type ClassMinimalDef = BooleanFormula Name -- Required methods

-- | Convert a `DefMethSpec` to a `DefMeth`, which discards the name field in
--   the `DefMeth` constructor of the `DefMeth`.
defMethSpecOfDefMeth :: DefMeth -> DefMethSpec
defMethSpecOfDefMeth meth
 = case meth of
        NoDefMeth       -> NoDM
        DefMeth _       -> VanillaDM
        GenDefMeth _    -> GenericDM

{-
Note [Associated type defaults]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The following is an example of associated type defaults:
   class C a where
     data D a r

     type F x a b :: *
     type F p q r = (p,q)->r    -- Default

Note that

 * The TyCons for the associated types *share type variables* with the
   class, so that we can tell which argument positions should be
   instantiated in an instance decl.  (The first for 'D', the second
   for 'F'.)

 * We can have default definitions only for *type* families,
   not data families

 * In the default decl, the "patterns" should all be type variables,
   but (in the source language) they don't need to be the same as in
   the 'type' decl signature or the class.  It's more like a
   free-standing 'type instance' declaration.

 * HOWEVER, in the internal ClassATItem we rename the RHS to match the
   tyConTyVars of the family TyCon.  So in the example above we'd get
   a ClassATItem of
        ATI F ((x,a) -> b)
   So the tyConTyVars of the family TyCon bind the free vars of
   the default Type rhs

The @mkClass@ function fills in the indirect superclasses.

The SrcSpan is for the entire original declaration.
-}

mkClass :: [TyVar]
        -> [([TyVar], [TyVar])]
        -> [PredType] -> [Id]
        -> [ClassATItem]
        -> [ClassOpItem]
        -> ClassMinimalDef
        -> TyCon
        -> Class

mkClass tyvars fds super_classes superdict_sels at_stuff
        op_stuff mindef tycon
  = Class { classKey     = tyConUnique tycon,
            className    = tyConName tycon,
            classTyVars  = tyvars,
            classFunDeps = fds,
            classSCTheta = super_classes,
            classSCSels  = superdict_sels,
            classATStuff = at_stuff,
            classOpStuff = op_stuff,
            classMinimalDef = mindef,
            classTyCon   = tycon }

{-
Note [Associated type tyvar names]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The TyCon of an associated type should use the same variable names as its
parent class. Thus
    class C a b where
      type F b x a :: *
We make F use the same Name for 'a' as C does, and similary 'b'.

The reason for this is when checking instances it's easier to match
them up, to ensure they match.  Eg
    instance C Int [d] where
      type F [d] x Int = ....
we should make sure that the first and third args match the instance
header.

Having the same variables for class and tycon is also used in checkValidRoles
(in TcTyClsDecls) when checking a class's roles.


************************************************************************
*                                                                      *
\subsection[Class-selectors]{@Class@: simple selectors}
*                                                                      *
************************************************************************

The rest of these functions are just simple selectors.
-}

classArity :: Class -> Arity
classArity clas = length (classTyVars clas)
        -- Could memoise this

classAllSelIds :: Class -> [Id]
-- Both superclass-dictionary and method selectors
classAllSelIds c@(Class {classSCSels = sc_sels})
  = sc_sels ++ classMethods c

classSCSelId :: Class -> Int -> Id
-- Get the n'th superclass selector Id
-- where n is 0-indexed, and counts
--    *all* superclasses including equalities
classSCSelId (Class { classSCSels = sc_sels }) n
  = {-ASSERT( n >= 0 && n < length sc_sels )-}
    sc_sels !! n

classMethods :: Class -> [Id]
classMethods (Class {classOpStuff = op_stuff})
  = [op_sel | (op_sel, _) <- op_stuff]

classOpItems :: Class -> [ClassOpItem]
classOpItems = classOpStuff

classATs :: Class -> [TyCon]
classATs (Class { classATStuff = at_stuff })
  = [tc | ATI tc _ <- at_stuff]

classATItems :: Class -> [ClassATItem]
classATItems = classATStuff

classTvsFds :: Class -> ([TyVar], [FunDep TyVar])
classTvsFds c
  = (classTyVars c, classFunDeps c)

classBigSig :: Class -> ([TyVar], [PredType], [Id], [ClassOpItem])
classBigSig (Class {classTyVars = tyvars, classSCTheta = sc_theta,
                    classSCSels = sc_sels, classOpStuff = op_stuff})
  = (tyvars, sc_theta, sc_sels, op_stuff)

classExtraBigSig :: Class -> ([TyVar], [FunDep TyVar], [PredType], [Id], [ClassATItem], [ClassOpItem])
classExtraBigSig (Class {classTyVars = tyvars, classFunDeps = fundeps,
                         classSCTheta = sc_theta, classSCSels = sc_sels,
                         classATStuff = ats, classOpStuff = op_stuff})
  = (tyvars, fundeps, sc_theta, sc_sels, ats, op_stuff)

{-
************************************************************************
*                                                                      *
\subsection[Class-instances]{Instance declarations for @Class@}
*                                                                      *
************************************************************************

We compare @Classes@ by their keys (which include @Uniques@).
-}

instance Eq Class where
    c1 == c2 = classKey c1 == classKey c2
    c1 /= c2 = classKey c1 /= classKey c2

instance Ord Class where
    c1 <= c2 = classKey c1 <= classKey c2
    c1 <  c2 = classKey c1 <  classKey c2
    c1 >= c2 = classKey c1 >= classKey c2
    c1 >  c2 = classKey c1 >  classKey c2
    compare c1 c2 = classKey c1 `compare` classKey c2

instance Uniquable Class where
    getUnique c = classKey c

instance NamedThing Class where
    getName clas = className clas

instance Outputable Class where
    ppr c = ppr (getName c)

instance Outputable DefMeth where
    ppr (DefMeth n)    =  ptext (sLit "Default method") <+> ppr n
    ppr (GenDefMeth n) =  ptext (sLit "Generic default method") <+> ppr n
    ppr NoDefMeth      =  empty   -- No default method

pprFundeps :: Outputable a => [FunDep a] -> SDoc
pprFundeps []  = empty
pprFundeps fds = hsep (ptext (sLit "|") : punctuate comma (map pprFunDep fds))

pprFunDep :: Outputable a => FunDep a -> SDoc
pprFunDep (us, vs) = hsep [interppSP us, ptext (sLit "->"), interppSP vs]

instance Data.Data Class where
    -- don't traverse?
    toConstr _   = abstractConstr "Class"
    gunfold _ _  = error "gunfold"
    dataTypeOf _ = mkNoRepType "Class"
