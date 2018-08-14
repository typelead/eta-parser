-- \section[Hooks]{Low level API hooks}

-- NB: this module is SOURCE-imported by DynFlags, and should primarily
--     refer to *types*, rather than *code*
-- If you import too muchhere , then the revolting compiler_stage2_dll0_MODULES
-- stuff in compiler/ghc.mk makes DynFlags link to too much stuff

module Language.Eta.Main.Hooks ( Hooks
             , emptyHooks
             , lookupHook
             , getHooked
               -- the hooks:
             , dsForeignsHook
             , tcForeignImportsHook
             , tcForeignExportsHook
             , hscFrontendHook
             , hscCompileOneShotHook
             , hscCompileCoreExprHook
             , ghcPrimIfaceHook
             , runPhaseHook
             , runMetaHook
             , linkHook
             , runQuasiQuoteHook
             , runRnSpliceHook
             , getValueSafelyHook
             ) where

import Language.Eta.Main.DynFlags
import Language.Eta.HsSyn.HsTypes
import Language.Eta.BasicTypes.Name
import Language.Eta.Main.PipelineMonad
import Language.Eta.Main.HscTypes
import Language.Eta.HsSyn.HsDecls
import Language.Eta.HsSyn.HsBinds
import Language.Eta.HsSyn.HsExpr
import Language.Eta.Utils.OrdList
import Language.Eta.BasicTypes.Id
import Language.Eta.TypeCheck.TcRnTypes
import Language.Eta.Utils.Bag
import Language.Eta.BasicTypes.RdrName
import Language.Eta.Core.CoreSyn
import Language.Eta.BasicTypes.BasicTypes
import Language.Eta.Types.Type
import Language.Eta.BasicTypes.SrcLoc

import Data.Maybe

{-
************************************************************************
*                                                                      *
\subsection{Hooks}
*                                                                      *
************************************************************************
-}

-- | Hooks can be used by GHC API clients to replace parts of
--   the compiler pipeline. If a hook is not installed, GHC
--   uses the default built-in behaviour

emptyHooks :: Hooks
emptyHooks = Hooks Nothing Nothing Nothing Nothing Nothing Nothing
                   Nothing Nothing Nothing Nothing Nothing Nothing
                   Nothing

data Hooks = Hooks
  { dsForeignsHook         :: Maybe ([LForeignDecl Id] -> DsM (ForeignStubs, OrdList (Id, CoreExpr)))
  , tcForeignImportsHook   :: Maybe ([LForeignDecl Name] -> TcM ([Id], [LForeignDecl Id], Bag GlobalRdrElt))
  , tcForeignExportsHook   :: Maybe ([LForeignDecl Name] -> TcM (LHsBinds TcId, [LForeignDecl TcId], Bag GlobalRdrElt))
  , hscFrontendHook        :: Maybe (ModSummary -> Hsc TcGblEnv)
  , hscCompileOneShotHook  :: Maybe (HscEnv -> ModSummary -> SourceModified -> IO HscStatus)
  , hscCompileCoreExprHook :: Maybe (HscEnv -> SrcSpan -> CoreExpr -> IO HValue)
  , ghcPrimIfaceHook       :: Maybe ModIface
  , runPhaseHook           :: Maybe (PhasePlus -> FilePath -> DynFlags -> CompPipeline (PhasePlus, FilePath))
  , runMetaHook            :: Maybe (MetaHook TcM)
  , linkHook               :: Maybe (GhcLink -> DynFlags -> Bool -> HomePackageTable -> IO SuccessFlag)
  , runQuasiQuoteHook      :: Maybe (HsQuasiQuote Name -> RnM (HsQuasiQuote Name))
  , runRnSpliceHook        :: Maybe (LHsExpr Name -> RnM (LHsExpr Name))
  , getValueSafelyHook     :: Maybe (HscEnv -> Name -> Type -> IO (Maybe HValue))
  }

getHooked :: (Functor f, HasDynFlags f) => (Hooks -> Maybe a) -> a -> f a
getHooked hook def = fmap (lookupHook hook def) getDynFlags

lookupHook :: (Hooks -> Maybe a) -> a -> DynFlags -> a
lookupHook hook def = fromMaybe def . hook . hooks
