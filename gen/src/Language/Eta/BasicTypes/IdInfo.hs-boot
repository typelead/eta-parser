module Language.Eta.BasicTypes.IdInfo where
import Language.Eta.Utils.Outputable
data IdInfo
data IdDetails

vanillaIdInfo :: IdInfo
coVarDetails :: IdDetails
pprIdDetails :: IdDetails -> SDoc
