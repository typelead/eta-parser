module Language.Eta.BasicTypes.DataCon where
import Language.Eta.BasicTypes.Name( Name, NamedThing )
import {-# SOURCE #-} Language.Eta.Types.TyCon( TyCon )
import Language.Eta.BasicTypes.Unique ( Uniquable )
import Language.Eta.Utils.Outputable ( Outputable, OutputableBndr )

data DataCon
data DataConRep
dataConName      :: DataCon -> Name
dataConTyCon     :: DataCon -> TyCon
isVanillaDataCon :: DataCon -> Bool

instance Eq DataCon
instance Ord DataCon
instance Uniquable DataCon
instance NamedThing DataCon
instance Outputable DataCon
instance OutputableBndr DataCon
