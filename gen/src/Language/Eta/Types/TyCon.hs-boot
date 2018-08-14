module Language.Eta.Types.TyCon where

import Language.Eta.BasicTypes.Name (Name)
import Language.Eta.BasicTypes.Unique (Unique)

data TyCon

tyConName           :: TyCon -> Name
tyConUnique         :: TyCon -> Unique
isTupleTyCon        :: TyCon -> Bool
isUnboxedTupleTyCon :: TyCon -> Bool
isFunTyCon          :: TyCon -> Bool
