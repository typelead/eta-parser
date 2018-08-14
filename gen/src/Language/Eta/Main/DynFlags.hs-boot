module Language.Eta.Main.DynFlags where

import Language.Eta.Utils.Platform

data DynFlags

targetPlatform       :: DynFlags -> Platform
pprUserLength        :: DynFlags -> Int
pprCols              :: DynFlags -> Int
unsafeGlobalDynFlags :: DynFlags
useUnicode     :: DynFlags -> Bool
useUnicodeSyntax     :: DynFlags -> Bool
hasPprDebug          :: DynFlags -> Bool
shouldUseColor       :: DynFlags -> Bool