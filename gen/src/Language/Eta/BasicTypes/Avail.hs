--
-- (c) The University of Glasgow
--

module Language.Eta.BasicTypes.Avail (
    Avails,
    AvailInfo(..),
    availsToNameSet,
    availsToNameEnv,
    findSames,
    availName, availNames,
    stableAvailCmp
  ) where

import qualified Data.Char as C
import qualified Data.Map as M

import Language.Eta.BasicTypes.Name
import Language.Eta.BasicTypes.NameEnv
import Language.Eta.BasicTypes.NameSet

import Language.Eta.Utils.Binary
import Language.Eta.Utils.Outputable
import Language.Eta.Utils.Util

-- -----------------------------------------------------------------------------
-- The AvailInfo type

-- | Records what things are "available", i.e. in scope
data AvailInfo = Avail Name      -- ^ An ordinary identifier in scope
               | AvailTC Name
                         [Name]  -- ^ A type or class in scope. Parameters:
                                 --
                                 --  1) The name of the type or class
                                 --  2) The available pieces of type or class.
                                 --
                                 -- The AvailTC Invariant:
                                 --   * If the type or class is itself
                                 --     to be in scope, it must be
                                 --     *first* in this list.  Thus,
                                 --     typically: @AvailTC Eq [Eq, ==, \/=]@
                deriving( Eq )
                        -- Equality used when deciding if the
                        -- interface has changed

-- | A collection of 'AvailInfo' - several things that are \"available\"
type Avails = [AvailInfo]

-- | Compare lexicographically
stableAvailCmp :: AvailInfo -> AvailInfo -> Ordering
stableAvailCmp (Avail n1)     (Avail n2)     = n1 `stableNameCmp` n2
stableAvailCmp (Avail {})     (AvailTC {})   = LT
stableAvailCmp (AvailTC n ns) (AvailTC m ms) = (n `stableNameCmp` m) `thenCmp`
                                               (cmpList stableNameCmp ns ms)
stableAvailCmp (AvailTC {})   (Avail {})     = GT


-- -----------------------------------------------------------------------------
-- Operations on AvailInfo

availsToNameSet :: [AvailInfo] -> NameSet
availsToNameSet avails = foldr add emptyNameSet avails
      where add avail set = extendNameSetList set (availNames avail)

availsToNameEnv :: [AvailInfo] -> NameEnv AvailInfo
availsToNameEnv avails = foldr add emptyNameEnv avails
     where add avail env = extendNameEnvList env
                                (zip (availNames avail) (repeat avail))

findSames :: [AvailInfo] -> [[Name]]
findSames as = filter (\l -> length l > 1) sames
  where
    sames = M.elems mm ++ M.elems dm ++ M.elems vm
    (mm, dm, vm) = foldr addTo (M.empty, M.empty, M.empty) as
    addTo a (mm, dm, vm) =
        ( addName n mm
        -- Separate maps for data constructors and variables
        -- Don't want to mix them up
        , foldr addName dm (filter isDataConName ns)
        , foldr addName vm (filter isVarName ns)
        )
      where (n:ns) = availNames a
    addName n m =
      case M.lookup l m of
        Just ns -> M.insert l (n : ns) m
        Nothing -> M.insert l [n] m
      where l = toLower n
    toLower n = map C.toLower (occNameString (nameOccName n))

-- | Just the main name made available, i.e. not the available pieces
-- of type or class brought into scope by the 'GenAvailInfo'
availName :: AvailInfo -> Name
availName (Avail n)     = n
availName (AvailTC n _) = n

-- | All names made available by the availability information
availNames :: AvailInfo -> [Name]
availNames (Avail n)      = [n]
availNames (AvailTC _ ns) = ns

-- -----------------------------------------------------------------------------
-- Printing

instance Outputable AvailInfo where
   ppr = pprAvail

pprAvail :: AvailInfo -> SDoc
pprAvail (Avail n)      = ppr n
pprAvail (AvailTC n ns) = ppr n <> braces (hsep (punctuate comma (map ppr ns)))

instance Binary AvailInfo where
    put_ bh (Avail aa) = do
            putByte bh 0
            put_ bh aa
    put_ bh (AvailTC ab ac) = do
            putByte bh 1
            put_ bh ab
            put_ bh ac
    get bh = do
            h <- getByte bh
            case h of
              0 -> do aa <- get bh
                      return (Avail aa)
              _ -> do ab <- get bh
                      ac <- get bh
                      return (AvailTC ab ac)

