module Language.Eta.Prelude.TysWiredIn where

import {-# SOURCE #-} Language.Eta.Types.TyCon      (TyCon)
import {-# SOURCE #-} Language.Eta.Types.TypeRep    (Type)


eqTyCon, coercibleTyCon :: TyCon
typeNatKind, typeSymbolKind :: Type
mkBoxedTupleTy :: [Type] -> Type
