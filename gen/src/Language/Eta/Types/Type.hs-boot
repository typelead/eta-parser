module Language.Eta.Types.Type where
import {-# SOURCE #-} Language.Eta.Types.TypeRep( Type, Kind )
import Language.Eta.BasicTypes.Var

isPredTy :: Type -> Bool

typeKind :: Type -> Kind
substKiWith :: [KindVar] -> [Kind] -> Kind -> Kind
eqKind :: Kind -> Kind -> Bool
