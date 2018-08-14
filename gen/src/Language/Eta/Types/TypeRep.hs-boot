module Language.Eta.Types.TypeRep where

import Language.Eta.Utils.Outputable (Outputable)

data Type
data TyThing

type PredType = Type
type Kind = Type
type SuperKind = Type

instance Outputable Type
