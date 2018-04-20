{-# LANGUAGE CPP #-}
{-# OPTIONS_GHC -fno-warn-missing-fields #-}
module Main where

import Data.Monoid
import Language.Eta.BasicTypes.SrcLoc
import Language.Eta.Main.DynFlags
import Language.Eta.Parser.Lexer
import Language.Eta.Utils.FastString
import Language.Eta.Utils.StringBuffer

main :: IO ()
main = do
  content <- readFile __FILE__
  let res =
        lexTokenStream
            (stringToStringBuffer content)
            (mkRealSrcLoc (mkFastString __FILE__) 0 0)
            flags
  case res of
    POk _ tokens ->
      mapM_ (\(L srcSpan token) -> putStrLn $ show srcSpan ++ ": " ++ show token) tokens
    _ -> error "failed"
  where
  -- Note: We're not passing all of the needed flags.
  -- Warnings suppressed with -fno-warn-missing-fields.
  flags = DynFlags
    { generalFlags = mempty
    , safeHaskell = Sf_None
    , extensionFlags = mempty
    }
