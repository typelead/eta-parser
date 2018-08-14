{-
(c) The University of Glasgow 2006
(c) The GRASP/AQUA Project, Glasgow University, 1998
-}

module Language.Eta.BasicTypes.NameSet (
        -- * Names set type
        NameSet,

        -- ** Manipulating these sets
        emptyNameSet, unitNameSet, mkNameSet, unionNameSet, unionNameSets,
        minusNameSet, elemNameSet, nameSetElems, extendNameSet, extendNameSetList,
        delFromNameSet, delListFromNameSet, isEmptyNameSet, foldNameSet, filterNameSet,
        intersectsNameSet, intersectNameSet,

        -- * Free variables
        FreeVars,

        -- ** Manipulating sets of free variables
        isEmptyFVs, emptyFVs, plusFVs, plusFV,
        mkFVs, addOneFV, unitFV, delFV, delFVs,

        -- * Defs and uses
        Defs, Uses, DefUse, DefUses,

        -- ** Manipulating defs and uses
        emptyDUs, usesOnly, mkDUs, plusDU,
        findUses, duDefs, duUses, allUses
    ) where

import Language.Eta.BasicTypes.Name
import Language.Eta.Utils.UniqSet

{-
************************************************************************
*                                                                      *
\subsection[Sets of names}
*                                                                      *
************************************************************************
-}

type NameSet = UniqSet Name

emptyNameSet       :: NameSet
unitNameSet        :: Name -> NameSet
extendNameSetList   :: NameSet -> [Name] -> NameSet
extendNameSet    :: NameSet -> Name -> NameSet
mkNameSet          :: [Name] -> NameSet
unionNameSet      :: NameSet -> NameSet -> NameSet
unionNameSets  :: [NameSet] -> NameSet
minusNameSet       :: NameSet -> NameSet -> NameSet
elemNameSet        :: Name -> NameSet -> Bool
nameSetElems      :: NameSet -> [Name]
isEmptyNameSet     :: NameSet -> Bool
delFromNameSet     :: NameSet -> Name -> NameSet
delListFromNameSet :: NameSet -> [Name] -> NameSet
foldNameSet        :: (Name -> b -> b) -> b -> NameSet -> b
filterNameSet      :: (Name -> Bool) -> NameSet -> NameSet
intersectNameSet   :: NameSet -> NameSet -> NameSet
intersectsNameSet  :: NameSet -> NameSet -> Bool
-- ^ True if there is a non-empty intersection.
-- @s1 `intersectsNameSet` s2@ doesn't compute @s2@ if @s1@ is empty

isEmptyNameSet    = isEmptyUniqSet
emptyNameSet      = emptyUniqSet
unitNameSet       = unitUniqSet
mkNameSet         = mkUniqSet
extendNameSetList  = addListToUniqSet
extendNameSet   = addOneToUniqSet
unionNameSet     = unionUniqSets
unionNameSets = unionManyUniqSets
minusNameSet      = minusUniqSet
elemNameSet       = elementOfUniqSet
nameSetElems     = uniqSetToList
delFromNameSet    = delOneFromUniqSet
foldNameSet       = foldUniqSet
filterNameSet     = filterUniqSet
intersectNameSet  = intersectUniqSets

delListFromNameSet set ns = foldl delFromNameSet set ns

intersectsNameSet s1 s2 = not (isEmptyNameSet (s1 `intersectNameSet` s2))

{-
************************************************************************
*                                                                      *
\subsection{Free variables}
*                                                                      *
************************************************************************

These synonyms are useful when we are thinking of free variables
-}

type FreeVars   = NameSet

plusFV   :: FreeVars -> FreeVars -> FreeVars
addOneFV :: FreeVars -> Name -> FreeVars
unitFV   :: Name -> FreeVars
emptyFVs :: FreeVars
plusFVs  :: [FreeVars] -> FreeVars
mkFVs    :: [Name] -> FreeVars
delFV    :: Name -> FreeVars -> FreeVars
delFVs   :: [Name] -> FreeVars -> FreeVars

isEmptyFVs :: NameSet -> Bool
isEmptyFVs  = isEmptyNameSet
emptyFVs    = emptyNameSet
plusFVs     = unionNameSets
plusFV      = unionNameSet
mkFVs       = mkNameSet
addOneFV    = extendNameSet
unitFV      = unitNameSet
delFV n s   = delFromNameSet s n
delFVs ns s = delListFromNameSet s ns

{-
************************************************************************
*                                                                      *
                Defs and uses
*                                                                      *
************************************************************************
-}

-- | A set of names that are defined somewhere
type Defs = NameSet

-- | A set of names that are used somewhere
type Uses = NameSet

-- | @(Just ds, us) =>@ The use of any member of the @ds@
--                      implies that all the @us@ are used too.
--                      Also, @us@ may mention @ds@.
--
-- @Nothing =>@ Nothing is defined in this group, but
--              nevertheless all the uses are essential.
--              Used for instance declarations, for example
type DefUse  = (Maybe Defs, Uses)

-- | A number of 'DefUse's in dependency order: earlier 'Defs' scope over later 'Uses'
--   In a single (def, use) pair, the defs also scope over the uses
type DefUses = [DefUse]

emptyDUs :: DefUses
emptyDUs = []

usesOnly :: Uses -> DefUses
usesOnly uses = [(Nothing, uses)]

mkDUs :: [(Defs,Uses)] -> DefUses
mkDUs pairs = [(Just defs, uses) | (defs,uses) <- pairs]

plusDU :: DefUses -> DefUses -> DefUses
plusDU = (++)

duDefs :: DefUses -> Defs
duDefs dus = foldr get emptyNameSet dus
  where
    get (Nothing, _u1) d2 = d2
    get (Just d1, _u1) d2 = d1 `unionNameSet` d2

allUses :: DefUses -> Uses
-- ^ Just like 'duUses', but 'Defs' are not eliminated from the 'Uses' returned
allUses dus = foldr get emptyNameSet dus
  where
    get (_d1, u1) u2 = u1 `unionNameSet` u2

duUses :: DefUses -> Uses
-- ^ Collect all 'Uses', regardless of whether the group is itself used,
-- but remove 'Defs' on the way
duUses dus = foldr get emptyNameSet dus
  where
    get (Nothing,   rhs_uses) uses = rhs_uses `unionNameSet` uses
    get (Just defs, rhs_uses) uses = (rhs_uses `unionNameSet` uses)
                                     `minusNameSet` defs

findUses :: DefUses -> Uses -> Uses
-- ^ Given some 'DefUses' and some 'Uses', find all the uses, transitively.
-- The result is a superset of the input 'Uses'; and includes things defined
-- in the input 'DefUses' (but only if they are used)
findUses dus uses
  = foldr get uses dus
  where
    get (Nothing, rhs_uses) uses
        = rhs_uses `unionNameSet` uses
    get (Just defs, rhs_uses) uses
        | defs `intersectsNameSet` uses         -- Used
        || any (startsWithUnderscore . nameOccName) (nameSetElems defs)
                -- At least one starts with an "_",
                -- so treat the group as used
        = rhs_uses `unionNameSet` uses
        | otherwise     -- No def is used
        = uses
