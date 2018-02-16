#!/usr/bin/runghc

{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE LambdaCase #-}

import Control.DeepSeq
import Control.Monad
import Data.Binary
import Data.List (intercalate, isPrefixOf)
import System.Environment
import System.Exit
import System.IO

tableNames =
  [ "alex_base"
  , "alex_table"
  , "alex_check"
  , "alex_deflt"
  ]

extraImports =
  [ "import Data.Binary (decode)"
  , "import Data.String (fromString)"
  ]

main :: IO ()
main = do
  fileName <- getArgs >>= \case
    [n] -> return n
    _ -> do
      hPutStrLn stderr "Missing file argument (use - for stdin)"
      exitFailure

  let readContents :: IO String
      readContents = case fileName of
        "-" -> getContents
        _ -> readFile fileName

      writeContents :: String -> IO ()
      writeContents s = case fileName of
        "-" -> putStrLn s
        _ -> writeFile fileName s

  !contents <- force <$> readContents
  writeContents $ process $ lines $ contents

process :: [String] -> String
process strings = loop "" $ addImports strings
  where
  addImports :: [String] -> [String]
  addImports ss =
    let (beforeImports, importsAndAfter) = break ("import " `isPrefixOf`) ss
    in beforeImports ++ extraImports ++ importsAndAfter

  loop :: String -> [String] -> String
  loop acc [] = acc
  loop acc ss =
    case ss of
      (x0:x1:xs) | isTableDef x0 ->
        let (res, rem) = transform xs
        in loop (intercalate "\n" [acc, x0, x1, res]) rem
      (x:xs) -> loop (acc ++ "\n" ++ x) xs

  isTableDef :: String -> Bool
  isTableDef x = any (`isPrefixOf` x) $ map (++ " ::") tableNames

  transform :: [String] -> (String, [String])
  transform [] = error "Cannot transform empty list"
  transform xs@(x:_)
    | '[' `elem` x =
        case break (']' `elem`) xs of
          (ys, z:zs) -> (convert $ join $ ys ++ [z], zs)
          _ -> error "Failed to find closing list bracket: ']'"
    | otherwise = error "Cannot transform list not starting with a '['"

  convert :: String -> String
  convert s = "  $ decode $ fromString " ++ show (encode (read s :: [Int]))
