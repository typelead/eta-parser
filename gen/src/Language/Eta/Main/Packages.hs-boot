module Language.Eta.Main.Packages where
import {-# SOURCE #-} Language.Eta.Main.DynFlags(DynFlags)
import {-# SOURCE #-} Language.Eta.BasicTypes.Module(ComponentId, UnitId, InstalledUnitId)
data PackageState
data PackageConfigMap
emptyPackageState :: PackageState
componentIdString :: DynFlags -> ComponentId -> Maybe String
displayInstalledUnitId :: DynFlags -> InstalledUnitId -> Maybe String
improveUnitId :: PackageConfigMap -> UnitId -> UnitId
getPackageConfigMap :: DynFlags -> PackageConfigMap