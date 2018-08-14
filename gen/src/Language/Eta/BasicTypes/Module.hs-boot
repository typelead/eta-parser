module Language.Eta.BasicTypes.Module where
import Language.Eta.Utils.FastString

data Module
data ModuleName
data UnitId
data InstalledUnitId
newtype ComponentId = ComponentId FastString

moduleName :: Module -> ModuleName
moduleUnitId :: Module -> UnitId
unitIdString :: UnitId -> String
