module Language.Eta.TypeCheck.TcType where
import Language.Eta.Utils.Outputable( SDoc )

data MetaDetails

data TcTyVarDetails
pprTcTyVarDetails :: TcTyVarDetails -> SDoc