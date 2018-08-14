{-# LANGUAGE CPP #-}

-----------------------------------------------------------------------------
--  $Id: DriverPhases.hs,v 1.38 2005/05/17 11:01:59 simonmar Exp $
--
-- GHC Driver
--
-- (c) The University of Glasgow 2002
--
-----------------------------------------------------------------------------

module Language.Eta.Main.DriverPhases (
   HscSource(..), isHsBootOrSig, hscSourceString,
   Phase(..),
   happensBefore, eqPhase, anyHsc, isStopLn,
   startPhase,
   phaseInputExt,

   isHaskellishSuffix,
   isHaskellSrcSuffix,
   isObjectSuffix,
   isCishSuffix,
   isJavaishSuffix,
   isJavaClassishSuffix,
   isDynLibSuffix,
   isHaskellUserSrcSuffix,
   isHaskellSigSuffix,
   isSourceSuffix,

   isHaskellishFilename,
   isHaskellSrcFilename,
   isHaskellSigFilename,
   isObjectFilename,
   isCishFilename,
   isJavaishFilename,
   isJavaClassishFilename,
   isDynLibFilename,
   isHaskellUserSrcFilename,
   isSourceFilename
 ) where

#include "HsVersions.h"

import {-# SOURCE #-} Language.Eta.Main.DynFlags
import Language.Eta.Utils.Outputable
import Language.Eta.Utils.Platform
import System.FilePath

-----------------------------------------------------------------------------
-- Phases

{-
   Phase of the           | Suffix saying | Flag saying   | (suffix of)
   compilation system     | ``start here''| ``stop after''| output file

   literate pre-processor | .lhs          | -             | -
   C pre-processor (opt.) | -             | -E            | -
   Haskell compiler       | .hs           | -C, -S        | .hc, .s
   C compiler (opt.)      | .hc or .c     | -S            | .s
   assembler              | .s  or .S     | -c            | .o
   linker                 | other         | -             | a.out
-}

-- Note [HscSource types]
-- ~~~~~~~~~~~~~~~~~~~~~~
-- There are three types of source file for Haskell code:
--
--      * HsSrcFile is an ordinary hs file which contains code,
--
--      * HsBootFile is an hs-boot file, which is used to break
--        recursive module imports (there will always be an
--        HsSrcFile associated with it), and
--
--      * HsigFile is an hsig file, which contains only type
--        signatures and is used to specify signatures for
--        modules.
--
-- Syntactically, hs-boot files and hsig files are quite similar: they
-- only include type signatures and must be associated with an
-- actual HsSrcFile.  isHsBootOrSig allows us to abstract over code
-- which is indifferent to which.  However, there are some important
-- differences, mostly owing to the fact that hsigs are proper
-- modules (you `import Sig` directly) whereas HsBootFiles are
-- temporary placeholders (you `import {-# SOURCE #-} Mod).
-- When we finish compiling the true implementation of an hs-boot,
-- we replace the HomeModInfo with the real HsSrcFile.  An HsigFile, on the
-- other hand, is never replaced (in particular, we *cannot* use the
-- HomeModInfo of the original HsSrcFile backing the signature, since it
-- will export too many symbols.)
--
-- Additionally, while HsSrcFile is the only Haskell file
-- which has *code*, we do generate .o files for HsigFile, because
-- this is how the recompilation checker figures out if a file
-- needs to be recompiled.  These are fake object files which
-- should NOT be linked against.

data HscSource
   = HsSrcFile | HsBootFile | HsigFile
     deriving( Eq, Ord, Show )
        -- Ord needed for the finite maps we build in CompManager

hscSourceString :: HscSource -> String
hscSourceString HsSrcFile   = ""
hscSourceString HsBootFile  = "[boot]"
hscSourceString HsigFile    = "[sig]"

-- See Note [isHsBootOrSig]
isHsBootOrSig :: HscSource -> Bool
isHsBootOrSig HsBootFile = True
isHsBootOrSig HsigFile   = True
isHsBootOrSig _          = False

data Phase
        = Unlit HscSource
        | Cpp   HscSource
        | HsPp  HscSource
        | Hsc   HscSource
        | Ccpp
        -- | JJava
        -- | JClass
        | Cc
        | Cobjc
        | Cobjcpp
        | HCc           -- Haskellised C (as opposed to vanilla C) compilation
        | Splitter      -- Assembly file splitter (part of '-split-objs')
        | SplitAs       -- Assembler for split assembly files (part of '-split-objs')
        | As Bool       -- Assembler for regular assembly files (Bool: with-cpp)
        | LlvmOpt       -- Run LLVM opt tool over llvm assembly
        | LlvmLlc       -- LLVM bitcode to native assembly
        | LlvmMangle    -- Fix up TNTC by processing assembly produced by LLVM
        | CmmCpp        -- pre-process Cmm source
        | Cmm           -- parse & compile Cmm code
        | MergeStub     -- merge in the stub object file

        -- The final phase is a pseudo-phase that tells the pipeline to stop.
        -- There is no runPhase case for it.
        | StopLn        -- Stop, but linking will follow, so generate .o file
  deriving (Eq, Show)

instance Outputable Phase where
    ppr p = text (show p)

anyHsc :: Phase
anyHsc = Hsc (panic "anyHsc")

isStopLn :: Phase -> Bool
isStopLn StopLn = True
isStopLn _      = False

eqPhase :: Phase -> Phase -> Bool
-- Equality of constructors, ignoring the HscSource field
-- NB: the HscSource field can be 'bot'; see anyHsc above
eqPhase (Unlit _)   (Unlit _)  = True
eqPhase (Cpp   _)   (Cpp   _)  = True
eqPhase (HsPp  _)   (HsPp  _)  = True
eqPhase (Hsc   _)   (Hsc   _)  = True
eqPhase Ccpp        Ccpp       = True
-- eqPhase JJava       JJava      = True
-- eqPhase JClass      JClass     = True
eqPhase Cc          Cc         = True
eqPhase Cobjc       Cobjc      = True
eqPhase Cobjcpp     Cobjcpp    = True
eqPhase HCc         HCc        = True
eqPhase Splitter    Splitter   = True
eqPhase SplitAs     SplitAs    = True
eqPhase (As x)      (As y)     = x == y
eqPhase LlvmOpt     LlvmOpt    = True
eqPhase LlvmLlc     LlvmLlc    = True
eqPhase LlvmMangle  LlvmMangle = True
eqPhase CmmCpp      CmmCpp     = True
eqPhase Cmm         Cmm        = True
eqPhase MergeStub   MergeStub  = True
eqPhase StopLn      StopLn     = True
eqPhase _           _          = False

-- Partial ordering on phases: we want to know which phases will occur before
-- which others.  This is used for sanity checking, to ensure that the
-- pipeline will stop at some point (see DriverPipeline.runPipeline).
happensBefore :: DynFlags -> Phase -> Phase -> Bool
happensBefore dflags p1 p2 = p1 `happensBefore'` p2
    where StopLn `happensBefore'` _ = False
          x      `happensBefore'` y = after_x `eqPhase` y
                                   || after_x `happensBefore'` y
              where after_x = nextPhase dflags x

nextPhase :: DynFlags -> Phase -> Phase
nextPhase _ p
    -- A conservative approximation to the next phase, used in happensBefore
    = case p of
      Unlit sf   -> Cpp  sf
      Cpp   sf   -> HsPp sf
      HsPp  sf   -> Hsc  sf
      Hsc   _    -> As False
      Splitter   -> SplitAs
      LlvmOpt    -> LlvmLlc
      LlvmLlc    -> LlvmMangle
      LlvmMangle -> As False
      SplitAs    -> MergeStub
      As _       -> MergeStub
      Ccpp       -> As False
      Cc         -> As False
      Cobjc      -> As False
      Cobjcpp    -> As False
      CmmCpp     -> Cmm
      Cmm        -> As False
      HCc        -> As False
      MergeStub  -> StopLn
      StopLn     -> panic "nextPhase: nothing after StopLn"

-- the first compilation phase for a given file is determined
-- by its suffix.
startPhase :: String -> Phase
startPhase "lhs"      = Unlit HsSrcFile
startPhase "lhs-boot" = Unlit HsBootFile
startPhase "lhsig"    = Unlit HsigFile
startPhase "hs"       = Cpp   HsSrcFile
startPhase "hs-boot"  = Cpp   HsBootFile
startPhase "hsig"     = Cpp   HsigFile
startPhase "hscpp"    = HsPp  HsSrcFile
startPhase "hspp"     = Hsc   HsSrcFile
startPhase "hc"       = HCc
-- startPhase "java"     = JJava
-- startPhase "class"    = JClass
startPhase "c"        = Cc
startPhase "cpp"      = Ccpp
startPhase "C"        = Cc
startPhase "m"        = Cobjc
startPhase "M"        = Cobjcpp
startPhase "mm"       = Cobjcpp
startPhase "cc"       = Ccpp
startPhase "cxx"      = Ccpp
startPhase "split_s"  = Splitter
startPhase "s"        = As False
startPhase "S"        = As True
startPhase "ll"       = LlvmOpt
startPhase "bc"       = LlvmLlc
startPhase "lm_s"     = LlvmMangle
startPhase "o"        = StopLn
startPhase "cmm"      = CmmCpp
startPhase "cmmcpp"   = Cmm
startPhase _          = StopLn     -- all unknown file types

-- This is used to determine the extension for the output from the
-- current phase (if it generates a new file).  The extension depends
-- on the next phase in the pipeline.
phaseInputExt :: Phase -> String
phaseInputExt (Unlit HsSrcFile)   = "lhs"
phaseInputExt (Unlit HsBootFile)  = "lhs-boot"
phaseInputExt (Unlit HsigFile)    = "lhsig"
phaseInputExt (Cpp   _)           = "lpp"       -- intermediate only
phaseInputExt (HsPp  _)           = "hscpp"     -- intermediate only
phaseInputExt (Hsc   _)           = "hspp"      -- intermediate only
        -- NB: as things stand, phaseInputExt (Hsc x) must not evaluate x
        --     because runPipeline uses the StopBefore phase to pick the
        --     output filename.  That could be fixed, but watch out.
phaseInputExt HCc                 = "hc"
phaseInputExt Ccpp                = "cpp"
phaseInputExt Cobjc               = "m"
phaseInputExt Cobjcpp             = "mm"
-- phaseInputExt JJava               = "java"
-- phaseInputExt JClass              = "class"
phaseInputExt Cc                  = "c"
phaseInputExt Splitter            = "split_s"
phaseInputExt (As True)           = "S"
phaseInputExt (As False)          = "s"
phaseInputExt LlvmOpt             = "ll"
phaseInputExt LlvmLlc             = "bc"
phaseInputExt LlvmMangle          = "lm_s"
phaseInputExt SplitAs             = "split_s"
phaseInputExt CmmCpp              = "cmm"
phaseInputExt Cmm                 = "cmmcpp"
phaseInputExt MergeStub           = "o"
phaseInputExt StopLn              = "jar"

haskellish_src_suffixes, haskellish_suffixes, cish_suffixes,
    haskellish_user_src_suffixes, haskellish_sig_suffixes,
    javaish_suffixes, javaclassish_suffixes
 :: [String]
haskellish_src_suffixes      = haskellish_user_src_suffixes ++
                               [ "hspp", "hscpp", "hcr", "cmm", "cmmcpp" ]
haskellish_suffixes          = haskellish_src_suffixes ++ ["hc", "raw_s"]
cish_suffixes                = [ "c", "cpp", "C", "cc", "cxx", "s", "S", "ll", "bc", "lm_s", "m", "M", "mm" ]
javaish_suffixes             = [ "java" ] ++ javaclassish_suffixes
javaclassish_suffixes        = [ "class" ]
-- Will not be deleted as temp files:
haskellish_user_src_suffixes =
  haskellish_sig_suffixes ++ [ "hs", "lhs", "hs-boot", "lhs-boot" ]
haskellish_sig_suffixes      = [ "hsig", "lhsig" ]

objish_suffixes :: Platform -> [String]
objish_suffixes _ = ["class", "jar"]

dynlib_suffixes :: Platform -> [String]
dynlib_suffixes _ = ["so"]

isHaskellishSuffix, isHaskellSrcSuffix, isCishSuffix,
    isHaskellUserSrcSuffix, isHaskellSigSuffix, isJavaishSuffix,
    isJavaClassishSuffix
 :: String -> Bool
isHaskellishSuffix     s = s `elem` haskellish_suffixes
isHaskellSigSuffix     s = s `elem` haskellish_sig_suffixes
isHaskellSrcSuffix     s = s `elem` haskellish_src_suffixes
isCishSuffix           s = s `elem` cish_suffixes
isJavaishSuffix        s = s `elem` javaish_suffixes
isJavaClassishSuffix   s = s `elem` javaclassish_suffixes
isHaskellUserSrcSuffix s = s `elem` haskellish_user_src_suffixes

isObjectSuffix, isDynLibSuffix :: Platform -> String -> Bool
isObjectSuffix platform s = s `elem` objish_suffixes platform
isDynLibSuffix platform s = s `elem` dynlib_suffixes platform

isSourceSuffix :: String -> Bool
isSourceSuffix suff  = isHaskellishSuffix suff || isCishSuffix suff || isJavaishSuffix suff

isHaskellishFilename, isHaskellSrcFilename, isCishFilename,
    isHaskellUserSrcFilename, isSourceFilename, isHaskellSigFilename, isJavaishFilename,
    isJavaClassishFilename
 :: FilePath -> Bool
-- takeExtension return .foo, so we drop 1 to get rid of the .
isHaskellishFilename     f = isHaskellishSuffix     (drop 1 $ takeExtension f)
isHaskellSrcFilename     f = isHaskellSrcSuffix     (drop 1 $ takeExtension f)
isCishFilename           f = isCishSuffix           (drop 1 $ takeExtension f)
isJavaishFilename        f = isJavaishSuffix        (drop 1 $ takeExtension f)
isJavaClassishFilename   f = isJavaClassishSuffix   (drop 1 $ takeExtension f)
isHaskellUserSrcFilename f = isHaskellUserSrcSuffix (drop 1 $ takeExtension f)
isSourceFilename         f = isSourceSuffix         (drop 1 $ takeExtension f)
isHaskellSigFilename     f = isHaskellSigSuffix     (drop 1 $ takeExtension f)

isObjectFilename, isDynLibFilename :: Platform -> FilePath -> Bool
isObjectFilename platform f = isObjectSuffix platform (drop 1 $ takeExtension f)
isDynLibFilename platform f = isDynLibSuffix platform (drop 1 $ takeExtension f)
