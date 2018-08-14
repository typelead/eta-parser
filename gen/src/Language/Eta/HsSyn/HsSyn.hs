{-
(c) The University of Glasgow 2006
(c) The GRASP/AQUA Project, Glasgow University, 1992-1998

\section{Haskell abstract syntax definition}

This module glues together the pieces of the Haskell abstract syntax,
which is declared in the various \tr{Hs*} modules.  This module,
therefore, is almost nothing but re-exporting.
-}

{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE UndecidableInstances #-} -- Note [Pass sensitive types]
                                      -- in module PlaceHolder
{-# LANGUAGE ConstraintKinds #-}

module Language.Eta.HsSyn.HsSyn (
        module Language.Eta.HsSyn.HsBinds,
        module Language.Eta.HsSyn.HsDecls,
        module Language.Eta.HsSyn.HsExpr,
        module Language.Eta.HsSyn.HsImpExp,
        module Language.Eta.HsSyn.HsLit,
        module Language.Eta.HsSyn.HsPat,
        module Language.Eta.HsSyn.HsTypes,
        module Language.Eta.HsSyn.HsUtils,
        module Language.Eta.HsSyn.HsDoc,
        module Language.Eta.HsSyn.PlaceHolder,
        Fixity,

        HsModule(..)
) where

-- friends:
import Language.Eta.HsSyn.HsDecls
import Language.Eta.HsSyn.HsBinds
import Language.Eta.HsSyn.HsExpr
import Language.Eta.HsSyn.HsImpExp
import Language.Eta.HsSyn.HsLit
import Language.Eta.HsSyn.PlaceHolder
import Language.Eta.HsSyn.HsPat
import Language.Eta.HsSyn.HsTypes  hiding  ( mkHsForAllTy )
import Language.Eta.BasicTypes.BasicTypes       ( Fixity, WarningTxt )
import Language.Eta.HsSyn.HsUtils
import Language.Eta.HsSyn.HsDoc

-- others:
import Language.Eta.BasicTypes.OccName          ( HasOccName )
import Language.Eta.Utils.Outputable
import Language.Eta.BasicTypes.SrcLoc
import Language.Eta.BasicTypes.Module           ( ModuleName )
import Language.Eta.Utils.FastString

-- libraries:
import Data.Data hiding ( Fixity )

-- | All we actually declare here is the top-level structure for a module.
data HsModule name
  = HsModule {
      hsmodName :: Maybe (Located ModuleName),
        -- ^ @Nothing@: \"module X where\" is omitted (in which case the next
        --     field is Nothing too)
      hsmodExports :: Maybe (Located [LIE name]),
        -- ^ Export list
        --
        --  - @Nothing@: export list omitted, so export everything
        --
        --  - @Just []@: export /nothing/
        --
        --  - @Just [...]@: as you would expect...
        --
        --
        --  - 'ApiAnnotation.AnnKeywordId's : 'ApiAnnotation.AnnOpen'
        --                                   ,'ApiAnnotation.AnnClose'

        -- For details on above see note [Api annotations] in ApiAnnotation
      hsmodImports :: [LImportDecl name],
        -- ^ We snaffle interesting stuff out of the imported interfaces early
        -- on, adding that info to TyDecls/etc; so this list is often empty,
        -- downstream.
      hsmodDecls :: [LHsDecl name],
        -- ^ Type, class, value, and interface signature decls
      hsmodDeprecMessage :: Maybe (Located WarningTxt),
        -- ^ reason\/explanation for warning/deprecation of this module
        --
        --  - 'ApiAnnotation.AnnKeywordId's : 'ApiAnnotation.AnnOpen'
        --                                   ,'ApiAnnotation.AnnClose'
        --

        -- For details on above see note [Api annotations] in ApiAnnotation
      hsmodHaddockModHeader :: Maybe LHsDocString
        -- ^ Haddock module info and description, unparsed
        --
        --  - 'ApiAnnotation.AnnKeywordId's : 'ApiAnnotation.AnnOpen'
        --                                   ,'ApiAnnotation.AnnClose'

        -- For details on above see note [Api annotations] in ApiAnnotation
   }
     -- ^ 'ApiAnnotation.AnnKeywordId's
     --
     --  - 'ApiAnnotation.AnnModule','ApiAnnotation.AnnWhere'
     --
     --  - 'ApiAnnotation.AnnOpen','ApiAnnotation.AnnSemi',
     --    'ApiAnnotation.AnnClose' for explicit braces and semi around
     --    hsmodImports,hsmodDecls if this style is used.

     -- For details on above see note [Api annotations] in ApiAnnotation
      deriving (Typeable)
deriving instance (DataId name) => Data (HsModule name)

instance (OutputableBndr name, HasOccName name)
        => Outputable (HsModule name) where

    ppr (HsModule Nothing _ imports decls _ mbDoc)
      = pp_mb mbDoc $$ pp_nonnull imports
                    $$ pp_nonnull decls

    ppr (HsModule (Just name) exports imports decls deprec mbDoc)
      = vcat [
            pp_mb mbDoc,
            case exports of
              Nothing -> pp_header (ptext (sLit "where"))
              Just es -> vcat [
                           pp_header lparen,
                           nest 8 (fsep (punctuate comma (map ppr (unLoc es)))),
                           nest 4 (ptext (sLit ") where"))
                          ],
            pp_nonnull imports,
            pp_nonnull decls
          ]
      where
        pp_header rest = case deprec of
           Nothing -> pp_modname <+> rest
           Just d -> vcat [ pp_modname, ppr d, rest ]

        pp_modname = ptext (sLit "module") <+> ppr name

pp_mb :: Outputable t => Maybe t -> SDoc
pp_mb (Just x) = ppr x
pp_mb Nothing  = empty

pp_nonnull :: Outputable t => [t] -> SDoc
pp_nonnull [] = empty
pp_nonnull xs = vcat (map ppr xs)
