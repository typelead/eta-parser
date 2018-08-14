module Language.Eta.BasicTypes.PatSyn where
import Language.Eta.BasicTypes.Name( NamedThing )
import Data.Typeable ( Typeable )
import Data.Data ( Data )
import Language.Eta.Utils.Outputable ( Outputable, OutputableBndr )
import Language.Eta.BasicTypes.Unique ( Uniquable )

data PatSyn

instance Eq PatSyn
instance Ord PatSyn
instance NamedThing PatSyn
instance Outputable PatSyn
instance OutputableBndr PatSyn
instance Uniquable PatSyn
instance Typeable PatSyn
instance Data PatSyn
