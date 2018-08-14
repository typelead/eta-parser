{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
module Codec.JVM.Types where

import Codec.JVM.Internal
import Data.Set (Set)
import Data.Word (Word16)
import Data.Text (Text)
import Data.String (IsString)
import Data.Maybe (mapMaybe)
import Data.Bits
import Data.List

import qualified Data.Set as S
import qualified Data.Text as Text

data PrimType
  = JByte
  | JChar
  | JDouble
  | JFloat
  | JInt
  | JLong
  | JShort
  | JBool
  deriving (Eq, Ord, Show)

jbyte, jchar, jdouble, jfloat, jint, jlong, jshort, jbool, jobject :: FieldType
jbyte = BaseType JByte
jchar = BaseType JChar
jdouble = BaseType JDouble
jfloat = BaseType JFloat
jint = BaseType JInt
jlong = BaseType JLong
jshort = BaseType JShort
jbool = BaseType JBool
jobject = ObjectType jlObject

jarray :: FieldType -> FieldType
jarray = ArrayType

baseType :: FieldType -> PrimType
baseType (BaseType pt) = pt
baseType _ = error "baseType: Not base type!"

jstring :: FieldType
jstring = ObjectType jlString

jstringC :: Text
jstringC = "java/lang/String"

jobjectC :: Text
jobjectC = "java/lang/Object"

jlObject :: IClassName
jlObject = IClassName jobjectC

jlString :: IClassName
jlString = IClassName jstringC

-- | Binary class names in their internal form.
-- https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-4.html#jvms-4.2.1
newtype IClassName = IClassName Text
  deriving (Eq, Ord, Show, IsString)

-- | Unqualified name
-- https://docs.oracle.com/javase/specs/jvms/se8/html/jvms4.html#jvms-4.2.2
newtype UName = UName Text
  deriving (Eq, Ord, Show, IsString)

-- | Field descriptor
-- https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-4.html#jvms-4.3.2
newtype FieldDesc = FieldDesc Text
  deriving (Eq, Ord, Show)

data FieldType = BaseType PrimType | ObjectType  IClassName | ArrayType FieldType
  deriving (Eq, Ord, Show)

getFtClass :: FieldType -> Text
getFtClass (ObjectType (IClassName t)) = t
getFtClass ft@(ArrayType _) = mkFieldDesc' ft
getFtClass ft = error $ "getFtClass: " ++ show ft ++ " is not object type!"

isCategory2 :: FieldType -> Bool
isCategory2 (BaseType JLong)   = True
isCategory2 (BaseType JDouble) = True
isCategory2 _                   = False

isObjectFt :: FieldType -> Bool
isObjectFt (ObjectType _) = True
isObjectFt (ArrayType _)  = True
isObjectFt _ = False

getArrayElemFt :: FieldType -> Maybe FieldType
getArrayElemFt (ArrayType ft) = Just ft
getArrayElemFt _              = Nothing

mkFieldDesc :: FieldType -> FieldDesc
mkFieldDesc ft = FieldDesc $ mkFieldDesc' ft where

mkFieldDesc' :: FieldType -> Text
mkFieldDesc' ft = case ft of
  BaseType JByte              -> "B"
  BaseType JChar              -> "C"
  BaseType JDouble            -> "D"
  BaseType JFloat             -> "F"
  BaseType JInt               -> "I"
  BaseType JLong              -> "J"
  BaseType JShort             -> "S"
  BaseType JBool              -> "Z"
  ObjectType (IClassName cn)  -> objectWrap cn
  ArrayType ft'               -> arrayWrap (mkFieldDesc' ft')

decodeDesc :: Text -> Maybe (FieldType, Text)
decodeDesc desc
  | Just (c, rest) <- Text.uncons desc
  , let base x = Just (BaseType x, rest)
  = case c of
      'B' -> base JByte
      'C' -> base JChar
      'D' -> base JDouble
      'F' -> base JFloat
      'I' -> base JInt
      'J' -> base JLong
      'S' -> base JShort
      'Z' -> base JBool
      '[' -> case decodeDesc rest of
        Just (ft, rest') -> Just (ArrayType ft, rest')
        Nothing -> Nothing
      'L' -> case Text.span (/= ';') rest of
        (clsName, rest') -> Just (ObjectType (IClassName clsName), Text.drop 1 rest')
      _   -> Nothing
  | otherwise = Nothing

decodeFieldDesc :: Text -> Maybe FieldType
decodeFieldDesc desc
  | Just (ft, rest)<- decodeDesc desc
  , Text.null rest
  = Just ft
  | otherwise = Nothing

arrayWrap :: Text -> Text
arrayWrap = Text.append "["

objectWrap :: Text -> Text
objectWrap x = Text.concat ["L", x, ";"]

fieldSize :: FieldType -> Int
fieldSize (BaseType JLong)    = 2
fieldSize (BaseType JDouble)  = 2
fieldSize _                   = 1

fieldByteSize :: FieldType -> Int
fieldByteSize (BaseType JByte) = 1
fieldByteSize (BaseType JChar) = 2
fieldByteSize (BaseType JDouble) = 8
fieldByteSize (BaseType JFloat) = 4
fieldByteSize (BaseType JInt) = 4
fieldByteSize (BaseType JLong) = 8
fieldByteSize (BaseType JShort) = 2
fieldByteSize (BaseType JBool) = 1 -- TODO: Is this correct?
fieldByteSize _ = 4 -- TODO: Is this correct?

prim :: PrimType -> FieldType
prim = BaseType

obj :: Text -> FieldType
obj = ObjectType . IClassName

arr :: FieldType -> FieldType
arr = ArrayType

data MethodType = MethodType [FieldType] ReturnType

type ReturnType = Maybe FieldType

void :: ReturnType
void = Nothing

ret :: FieldType -> ReturnType
ret = Just

-- | Method descriptor
-- https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-4.html#jvms-4.3.3
data MethodDesc = MethodDesc Text
  deriving (Eq, Ord, Show)

mkMethodDesc :: [FieldType] -> ReturnType -> MethodDesc
mkMethodDesc fts rt = MethodDesc (mkMethodDesc' fts rt)

mkMethodDesc' :: [FieldType] -> ReturnType -> Text
mkMethodDesc' fts rt = Text.concat ["(", args, ")", result] where
  args = Text.concat $ mkFieldDesc' <$> fts
  result  = maybe "V" mkFieldDesc' rt

decodeMethodDesc :: Text -> Maybe ([FieldType], ReturnType)
decodeMethodDesc desc
  | Just ('(', rest) <- Text.uncons desc
  , (inside, outside') <- Text.span (/= ')') rest
  , let outside = Text.drop 1 outside'
  = let retType = case Text.uncons outside of
          Just ('V', rest')
            | Text.null rest' -> Just Nothing
            | otherwise -> Nothing
          _ -> case decodeDesc outside of
            Just (ft, rest') -> if Text.null rest' then Just (Just ft) else Nothing
            _ -> Nothing
    in do
      a <- argTypes inside []
      b <- retType
      return (a,b)
  | otherwise = Nothing --error $ "decodeMethodDesc: Bad desc: " ++ Text.unpack desc
  where argTypes text fts
          | Text.null text = Just $ reverse fts
          | Just (ft, rest') <- decodeDesc text = argTypes rest' (ft:fts)
          | otherwise = Nothing

-- | Field or method reference
-- https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-4.html#jvms-4.4.2

data FieldRef = FieldRef IClassName UName FieldType
  deriving (Eq, Ord, Show)

mkFieldRef :: Text -> Text -> FieldType -> FieldRef
mkFieldRef cn un ft = FieldRef (IClassName cn) (UName un) ft

data MethodRef = MethodRef IClassName UName [FieldType] ReturnType
  deriving (Eq, Ord, Show)

mkMethodRef :: Text -> Text -> [FieldType] -> ReturnType -> MethodRef
mkMethodRef cn un fts rt = MethodRef (IClassName cn) (UName un) fts rt

data NameAndDesc = NameAndDesc UName Desc
  deriving (Eq, Ord, Show)

-- | Field or method descriptor
newtype Desc = Desc Text
  deriving (Eq, Ord, Show)

data Version = Version
  { versionMaj :: Int
  , versionMin :: Int }
  deriving (Eq, Ord, Show)

java8 :: Version
java8 = Version 52 0

java7 :: Version
java7 = Version 51 0

-- https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-4.html#jvms-4.6-200-A.1
data AccessFlag
  = Public
  | Private
  | Protected
  | Static
  | Final
  | Super
  | Synchronized
  | Volatile
  | Bridge
  | VarArgs
  | Transient
  | Native
  | Interface
  | Abstract
  | Strict
  | Synthetic
  | Annotation
  | Enum
  deriving (Eq, Ord, Show, Enum)

data AccessType
  = ATClass
  | ATMethod
  | ATField
  | ATInnerClass
  | ATMethodParam
  deriving (Eq, Ord, Show)

accessFlagValue :: AccessFlag -> Word16
accessFlagValue Public        = 0x0001
accessFlagValue Private       = 0x0002
accessFlagValue Protected     = 0x0004
accessFlagValue Static        = 0x0008
accessFlagValue Final         = 0x0010
accessFlagValue Super         = 0x0020
accessFlagValue Synchronized  = 0x0020
accessFlagValue Volatile      = 0x0040
accessFlagValue Bridge        = 0x0040
accessFlagValue VarArgs       = 0x0080
accessFlagValue Transient     = 0x0080
accessFlagValue Native        = 0x0100
accessFlagValue Interface     = 0x0200
accessFlagValue Abstract      = 0x0400
accessFlagValue Strict        = 0x0800
accessFlagValue Synthetic     = 0x1000
accessFlagValue Annotation    = 0x2000
accessFlagValue Enum          = 0x4000

putAccessFlags :: Set AccessFlag -> Put
putAccessFlags accessFlags = putWord16be $ sum (accessFlagValue <$> (S.toList accessFlags))

getAccessFlags :: AccessType -> Get (Set AccessFlag)
getAccessFlags at = do
  mask <- getWord16be
  return $ S.fromList $ accessFlagsFromBitmask at mask

accessFlagsFromBitmask :: AccessType -> Word16 -> [AccessFlag]
accessFlagsFromBitmask at mask =
  mapMaybe (\(i, af) -> if testBit mask (16 - i)
                        then Just af
                        else Nothing) accessFlagMap
  where removeFlags = case at of
          ATClass -> [Synchronized, Bridge, Transient] -- Bridge and Transient are arbitrary choices
          _ -> []
        accessFlagMap = zip [0..] $ [Public ..] \\ removeFlags
