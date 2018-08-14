module Language.Eta.BasicTypes.MkId where
import Language.Eta.BasicTypes.Name( Name )
import Language.Eta.BasicTypes.Var( Id )
import {-# SOURCE #-} Language.Eta.BasicTypes.DataCon( DataCon )
import {-# SOURCE #-} Language.Eta.Prelude.PrimOp( PrimOp )

data DataConBoxer

mkDataConWorkId :: Name -> DataCon -> Id
mkPrimOpId      :: PrimOp -> Id

magicDictId :: Id
