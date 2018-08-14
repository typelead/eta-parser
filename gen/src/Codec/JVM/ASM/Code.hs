module Codec.JVM.ASM.Code where

import Control.Monad.Reader
import Data.Text (Text)
import Data.ByteString (ByteString)
import Data.Foldable (fold)
import Data.Monoid ((<>))
import Data.Word (Word8, Word16)
import Data.Int (Int32, Int64)

import qualified Data.ByteString as BS

import Codec.JVM.ASM.Code.Instr (Instr(..))
import Codec.JVM.Const
import Codec.JVM.Internal (packWord16be, packI16)
import Codec.JVM.Opcode (Opcode)
import Codec.JVM.Types

import Codec.JVM.ASM.Code.Types
import Codec.JVM.ASM.Code.CtrlFlow (VerifType(..), Stack)
import qualified Codec.JVM.ASM.Code.CtrlFlow as CF
import qualified Codec.JVM.ASM.Code.Instr as IT
import qualified Codec.JVM.ConstPool as CP
import qualified Codec.JVM.Opcode as OP

import Data.IntMap.Strict (IntMap)
import qualified Data.IntMap.Strict as IntMap

import Data.Maybe (maybeToList, catMaybes)

data Code = Code
  { consts  :: [Const]
  , instr   :: Instr }
  deriving Show

instance Monoid Code where
  mempty = Code mempty mempty
  mappend (Code cs0 i0) (Code cs1 i1) = Code (mappend cs0 cs1) (mappend i0 i1)

mkCode :: [Const] -> Instr -> Code
mkCode = Code

mkCode' :: Instr -> Code
mkCode' = mkCode []

modifyStack :: (Stack -> Stack) -> Instr
modifyStack = IT.modifyStack

codeConst :: Opcode -> FieldType -> Const -> Code
codeConst oc ft c = mkCode cs $ fold
  [ IT.op oc
  , IT.ix c
  , modifyStack $ CF.push ft ]
    where cs = CP.unpack c

codeBytes :: ByteString -> Code
codeBytes bs = mkCode [] $ IT.bytes bs

op :: Opcode -> Code
op = mkCode' . IT.op

pushBytes :: Opcode -> FieldType -> ByteString -> Code
pushBytes oc ft bs = mkCode' $ fold
  [ IT.op oc
  , IT.bytes bs
  , modifyStack $ CF.push ft ]

--
-- Operations
--

bipush :: FieldType -> Word8 -> Code
bipush ft w = pushBytes OP.bipush ft $ BS.singleton w

sipush :: FieldType -> Word16 -> Code
sipush ft w = pushBytes OP.sipush ft $ packWord16be w

dup :: FieldType -> Code
dup ft = mkCode'
       $ IT.op dupOp
       <> modifyStack (CF.push ft)
  where fsz = fieldSize ft
        dupOp = if fsz == 1 then OP.dup else OP.dup2

-- TODO: Support category 2 types
gdup :: Code
gdup = mkCode' $ IT.op OP.dup
              <> IT.withStack (\vts -> (head vts) : vts)

pop :: FieldType -> Code
pop ft = mkCode'
       $ IT.op popOp
       <> modifyStack (CF.pop ft)
  where fsz = fieldSize ft
        popOp = if fsz == 1 then OP.pop else OP.pop2

invoke :: Bool -> Bool -> Opcode -> MethodRef -> Code
invoke this interface oc mr@(MethodRef _ _ fts rt) = mkCode cs $
     IT.op oc
  <> IT.ix c
  <> (if interface then IT.bytes $ BS.pack [fromIntegral $ sumArgSizes + 1, 0] else mempty)
  <> modifyStack (maybePushReturn . popArgs)
    where
      maybePushReturn = maybe id CF.push rt
      sumArgSizes = sum (fieldSize <$> fts)
      popArgs = CF.pop'
              $ sumArgSizes
              + (if this then 1 else 0)
      c = (if interface then CInterfaceMethodRef else CMethodRef) mr
      cs = CP.unpack c

invokeinterface :: MethodRef -> Code
invokeinterface = invoke True True OP.invokeinterface

invokevirtual :: MethodRef -> Code
invokevirtual = invoke True False OP.invokevirtual

invokespecial :: MethodRef -> Code
invokespecial = invoke True False OP.invokespecial

invokestatic :: MethodRef -> Code
invokestatic = invoke False False OP.invokestatic

getfield :: FieldRef -> Code
getfield fr@(FieldRef _ _ ft) = mkCode cs $ fold
  [ IT.op OP.getfield
  , IT.ix c
  , modifyStack
  $ CF.push ft
  . CF.pop' 1 ] -- NOTE: Assumes that an object ref takes 1 stack slot
  where c = CFieldRef fr
        cs = CP.unpack c

putfield :: FieldRef -> Code
putfield fr@(FieldRef _ _ ft) = mkCode cs $ fold
  [ IT.op OP.putfield
  , IT.ix c
  , modifyStack
  $ CF.pop' 1  -- NOTE: Assumes that an object ref takes 1 stack slot
  . CF.pop  ft ]
  where c = CFieldRef fr
        cs = CP.unpack c

getstatic :: FieldRef -> Code
getstatic fr@(FieldRef _ _ ft) = mkCode cs $ fold
  [ IT.op OP.getstatic
  , IT.ix c
  , modifyStack
  $ CF.push ft ]
  where c = CFieldRef fr
        cs = CP.unpack c

putstatic :: FieldRef -> Code
putstatic fr@(FieldRef _ _ ft) = mkCode cs $ fold
  [ IT.op OP.putstatic
  , IT.ix c
  , modifyStack
  $ CF.pop ft ]
  where c = CFieldRef fr
        cs = CP.unpack c

opStack :: (FieldType -> Stack -> Stack) -> FieldType -> Opcode -> Code
opStack f ft oc = mkCode' $ IT.op oc <> modifyStack (f ft)

unaryOp, binaryOp, shiftOp, cmpOp :: FieldType -> Opcode -> Code
unaryOp  = opStack (\ft -> CF.push ft . CF.pop ft)
binaryOp = opStack (\ft -> CF.push ft . CF.pop ft . CF.pop ft)
shiftOp  = opStack (\ft -> CF.push ft . CF.pop ft . CF.pop jint)
cmpOp    = opStack (\ft -> CF.push jint . CF.pop ft . CF.pop ft)

iadd, ladd, fadd, dadd :: Code
iadd = binaryOp jint OP.iadd
ladd = binaryOp jlong OP.ladd
fadd = binaryOp jfloat OP.fadd
dadd = binaryOp jdouble OP.dadd

isub, lsub, fsub, dsub :: Code
isub = binaryOp jint OP.isub
lsub = binaryOp jlong OP.lsub
fsub = binaryOp jfloat OP.fsub
dsub = binaryOp jdouble OP.dsub

imul, lmul, fmul, dmul :: Code
imul = binaryOp jint OP.imul
lmul = binaryOp jlong OP.lmul
fmul = binaryOp jfloat OP.fmul
dmul = binaryOp jdouble OP.dmul

idiv, ldiv, fdiv, ddiv :: Code
idiv = binaryOp jint OP.idiv
ldiv = binaryOp jlong OP.ldiv
fdiv = binaryOp jfloat OP.fdiv
ddiv = binaryOp jdouble OP.ddiv

irem, lrem, frem, drem :: Code
irem = binaryOp jint OP.irem
lrem = binaryOp jlong OP.lrem
frem = binaryOp jfloat OP.frem
drem = binaryOp jdouble OP.drem

ineg, lneg, fneg, dneg :: Code
ineg = unaryOp jint OP.ineg
lneg = unaryOp jlong OP.lneg
fneg = unaryOp jfloat OP.fneg
dneg = unaryOp jdouble OP.dneg

ishl, ishr, iushr, lshl, lshr, lushr :: Code
ishl  = shiftOp jint OP.ishl
ishr  = shiftOp jint OP.ishr
iushr = shiftOp jint OP.iushr
lshl  = shiftOp jlong OP.lshl
lshr  = shiftOp jlong OP.lshr
lushr = shiftOp jlong OP.lushr

ior, lor, iand, land, ixor, lxor, inot, lnot :: Code
ior  = binaryOp jint OP.ior
iand = binaryOp jint OP.iand
ixor = binaryOp jint OP.ixor
lor  = binaryOp jlong OP.lor
land = binaryOp jlong OP.land
lxor = binaryOp jlong OP.lxor
inot = iconst jint (-1)
    <> ixor
lnot = lconst (-1)
    <> lxor

fcmpl, fcmpg, dcmpl, dcmpg, lcmp :: Code
fcmpl = cmpOp jfloat OP.fcmpl
fcmpg = cmpOp jfloat OP.fcmpg
dcmpg = cmpOp jdouble OP.dcmpg
dcmpl = cmpOp jdouble OP.dcmpl
lcmp  = cmpOp jlong OP.lcmp

gcmp :: FieldType -> Code -> Code -> Code
gcmp (BaseType bt) arg1 arg2 = arg1 <> arg2 <> cmp
  where cmp = case bt of
          JFloat  -> fcmpl
          JDouble -> dcmpl
          JLong   -> lcmp
          _       -> error $ "gcmp: Unsupported primitive type: " ++ show bt
gcmp _ _ _ = error "gcmp: Non-primitive types not supported."

gbranch :: (FieldType -> Stack -> Stack)
        -> FieldType -> Opcode -> Code -> Code -> Code
gbranch f ft oc ok ko = mkCode cs ins
  where cs = [ok, ko] >>= consts
        ins = IT.gbranch f ft oc (instr ok) (instr ko)

unaryBranch, binaryBranch :: FieldType -> Opcode -> Code -> Code -> Code
unaryBranch  = gbranch CF.pop
binaryBranch = gbranch (\ft -> CF.pop ft . CF.pop ft)

intBranch1, intBranch2 :: Opcode -> Code -> Code -> Code
intBranch1 = unaryBranch jint
intBranch2 = binaryBranch jint

ifne, ifeq, ifle, iflt, ifge, ifgt, ifnull, ifnonnull
  :: Code -> Code -> Code
ifne      = intBranch1 OP.ifne
ifeq      = intBranch1 OP.ifeq
ifle      = intBranch1 OP.ifle
iflt      = intBranch1 OP.iflt
ifgt      = intBranch1 OP.ifgt
ifge      = intBranch1 OP.ifge
ifnull    = unaryBranch jobject OP.ifnull
ifnonnull = unaryBranch jobject OP.ifnonnull

if_icmpeq, if_icmpne, if_icmplt, if_icmpge, if_icmpgt, if_icmple,
  if_acmpeq, if_acmpne :: Code -> Code -> Code
if_icmpeq = intBranch2 OP.if_icmpeq
if_icmpne = intBranch2 OP.if_icmpne
if_icmplt = intBranch2 OP.if_icmplt
if_icmpge = intBranch2 OP.if_icmpge
if_icmpgt = intBranch2 OP.if_icmpgt
if_icmple = intBranch2 OP.if_icmple
if_acmpeq = binaryBranch jobject OP.if_acmpeq
if_acmpne = binaryBranch jobject OP.if_acmpne

gthrow :: FieldType -> Code
gthrow ft = mkCode' $
     IT.op OP.athrow
  <> modifyStack ( CF.push ft
                 . CF.pop  ft )

-- Generic instruction which selects either
-- the original opcode or the modified opcode
-- based on size
gwide :: (Integral a) => Opcode -> a -> Instr
gwide opcode n = wideInstr
  where wideInstr
          | n <= 255  = IT.op opcode
                     <> IT.bytes (BS.singleton $ fromIntegral n)
          | otherwise = IT.op OP.wide
                     <> IT.op opcode
                     <> IT.bytes (packI16 $ fromIntegral n)

ginstanceof :: FieldType -> Code
ginstanceof ft@(ObjectType (IClassName className )) =
  mkCode cs $
       IT.op OP.instanceof
    <> IT.ix c
    <> modifyStack ( CF.push jint
                   . CF.pop  ft   )
  where c  = CClass . IClassName $ className
        cs = CP.unpack c

ginstanceof _ = error "we don't support non-object types with instanceof"

-- Generic load instruction
gload :: FieldType -> Int -> Code
gload ft n = mkCode cs $ fold
  [ loadOp
  , IT.ctrlFlow
  $ CF.load n ft ]
  where loadOp = case CF.fieldTypeFlatVerifType ft of
          VInteger -> case n of
            0 -> IT.op OP.iload_0
            1 -> IT.op OP.iload_1
            2 -> IT.op OP.iload_2
            3 -> IT.op OP.iload_3
            _ -> gwide OP.iload n
          VLong -> case n of
            0 -> IT.op OP.lload_0
            1 -> IT.op OP.lload_1
            2 -> IT.op OP.lload_2
            3 -> IT.op OP.lload_3
            _ -> gwide OP.lload n
          VFloat -> case n of
            0 -> IT.op OP.fload_0
            1 -> IT.op OP.fload_1
            2 -> IT.op OP.fload_2
            3 -> IT.op OP.fload_3
            _ -> gwide OP.fload n
          VDouble -> case n of
            0 -> IT.op OP.dload_0
            1 -> IT.op OP.dload_1
            2 -> IT.op OP.dload_2
            3 -> IT.op OP.dload_3
            _ -> gwide OP.dload n
          VObject _ -> case n of
            0 -> IT.op OP.aload_0
            1 -> IT.op OP.aload_1
            2 -> IT.op OP.aload_2
            3 -> IT.op OP.aload_3
            _ -> gwide OP.aload n
          _ -> error "gload: Wrong type of load!"
        cs = maybeToList $ getObjConst ft

-- Generic store instruction
gstore :: (Integral a) => FieldType -> a -> Code
gstore ft n' = mkCode cs $ fold
  [ storeOp
  , IT.ctrlFlow
  $ CF.store n ft ]
  where n = fromIntegral n' :: Int
        storeOp = case CF.fieldTypeFlatVerifType ft of
          VInteger -> case n of
            0 -> IT.op OP.istore_0
            1 -> IT.op OP.istore_1
            2 -> IT.op OP.istore_2
            3 -> IT.op OP.istore_3
            _ -> gwide OP.istore n'
          VLong -> case n of
            0 -> IT.op OP.lstore_0
            1 -> IT.op OP.lstore_1
            2 -> IT.op OP.lstore_2
            3 -> IT.op OP.lstore_3
            _ -> gwide OP.lstore n'
          VFloat -> case n of
            0 -> IT.op OP.fstore_0
            1 -> IT.op OP.fstore_1
            2 -> IT.op OP.fstore_2
            3 -> IT.op OP.fstore_3
            _ -> gwide OP.fstore n'
          VDouble -> case n of
            0 -> IT.op OP.dstore_0
            1 -> IT.op OP.dstore_1
            2 -> IT.op OP.dstore_2
            3 -> IT.op OP.dstore_3
            _ -> gwide OP.dstore n'
          VObject _ -> case n of
            0 -> IT.op OP.astore_0
            1 -> IT.op OP.astore_1
            2 -> IT.op OP.astore_2
            3 -> IT.op OP.astore_3
            _ -> gwide OP.astore n'
          _ -> error "gstore: Wrong type of load!"
        cs = maybeToList $ getObjConst ft

initCtrlFlow :: Bool -> [FieldType] -> Code
initCtrlFlow isStatic args@(_:args')
  = mkCode cs $ IT.initCtrl
              . CF.mapLocals
              . const
              . CF.localsFromList
              $ fts
  where fts = if isStatic then args' else args
        cs = catMaybes $ map isClass fts
        isClass ft
          | VObject iclassName <- CF.fieldTypeFlatVerifType ft
          = Just (CClass iclassName)
          | otherwise = Nothing
initCtrlFlow _ _ = error "initCtrlFlow: Must have at least one argument."

-- Void return
vreturn :: Code
vreturn = mkCode' $ IT.returnInstr OP.vreturn

-- Generic, non-void return
greturn :: FieldType -> Code
greturn ft = mkCode' $ fold
  [ IT.returnInstr returnOp
  , modifyStack $ CF.pop ft ]
  where returnOp = case CF.fieldTypeFlatVerifType ft of
          VInteger  -> OP.ireturn
          VLong     -> OP.lreturn
          VFloat    -> OP.freturn
          VDouble   -> OP.dreturn
          VObject _ -> OP.areturn
          _ -> error "greturn: Wrong type of return!"

new :: FieldType -> Code
new (ObjectType (IClassName className)) = mkCode cs $
  IT.withOffset $ \offset -> fold
    [ IT.op OP.new
    , IT.ix c
    , modifyStack (CF.vpush (VUninitialized $ fromIntegral offset))]
  where c = CClass . IClassName $ className
        cs = CP.unpack c

new ft@(ArrayType (BaseType bt)) = mkCode' $ fold
  [ IT.op OP.newarray
  , IT.bytes (BS.singleton atype)
  , modifyStack (CF.push ft . CF.pop jint) ]
  where atype = case bt of
          JBool   -> 4 :: Word8
          JChar   -> 5
          JFloat  -> 6
          JDouble -> 7
          JByte   -> 8
          JShort  -> 9
          JInt    -> 10
          JLong   -> 11

new ft@(ArrayType (ObjectType (IClassName className))) = mkCode cs $ fold
  [ IT.op OP.anewarray
  , IT.ix c
  , modifyStack $ CF.push ft . CF.pop jint ]
  where c = CClass . IClassName $ className
        cs = CP.unpack c
new (BaseType bt) = error $ "new: Cannot instantiate a primitive type: " ++ show bt
new ft = error $ "new: Type not supported" ++ show ft

aconst_null :: FieldType -> Code
aconst_null ft = mkCode cs $ IT.op OP.aconst_null <> modifyStack (CF.push ft)
  where cs = maybeToList $ getObjConst ft

iconst :: FieldType -> Int32 -> Code
iconst ft i
  | i >= -1 && i <= 5 = mkCode' . (<> modifyStack (CF.push ft)) $
    case i of
      -1 -> IT.op OP.iconst_m1
      0  -> IT.op OP.iconst_0
      1  -> IT.op OP.iconst_1
      2  -> IT.op OP.iconst_2
      3  -> IT.op OP.iconst_3
      4  -> IT.op OP.iconst_4
      5  -> IT.op OP.iconst_5
      _  -> error "iconst: -1 <= i <= 5 DEFAULT"
  | i >= -128 && i <= 127 = bipush ft $ fromIntegral i
  | i >= -32768 && i <= 32767 = sipush ft $ fromIntegral i
  | otherwise = gldc ft $ cint i

constCode :: FieldType -> Opcode -> Code
constCode ft opc = mkCode' $ IT.op opc <> modifyStack (CF.push ft)

lconst :: Int64 -> Code
lconst l
  | l == 0 = code OP.lconst_0
  | l == 1 = code OP.lconst_1
  | otherwise = gldc ft $ clong l
  where ft = jlong
        code = constCode ft

fconst :: Float -> Code
fconst f
  | f == 0.0 = code OP.fconst_0
  | f == 1.0 = code OP.fconst_1
  | f == 2.0 = code OP.fconst_2
  | otherwise = gldc ft $ cfloat f
  where ft = jfloat
        code = constCode ft

dconst :: Double -> Code
dconst d
  | d == 0.0 = code OP.dconst_0
  | d == 1.0 = code OP.dconst_1
  | otherwise = gldc ft $ cdouble d
  where ft = jdouble
        code = constCode ft

sconst :: Text -> Code
sconst = gldc jstring . cstring

gldc :: FieldType -> Const -> Code
gldc ft c = mkCode cs $ loadCode
                     <> modifyStack (CF.push ft)
  where cs = CP.unpack c ++ maybeToList (getObjConst ft)
        category2 = isConstCategory2 c
        loadCode
          | category2 = IT.op OP.ldc2_w
                     <> IT.ix c
          | otherwise = Instr $ do
              cp <- ask
              let index = CP.ix (CP.unsafeIndex "gldc" c cp)
              if index <= 255 then
                do IT.op' OP.ldc
                   IT.writeBytes (BS.singleton $ fromIntegral index)
              else
                do IT.op' OP.ldc_w
                   IT.writeBytes (packI16 $ fromIntegral index)

gconv :: FieldType -> FieldType -> Code
gconv ft1 ft2
  | Just opCode <- convOpcode
  = mkCode (cs ft2) $ opCode <> modifyStack (CF.push ft2 . CF.pop ft1)
  | otherwise = mempty
  where convOpcode = case (ft1, ft2) of
          (BaseType bt1, BaseType bt2) ->
            case (bt1, bt2) of
              (JBool, JInt)      -> Nothing
              (JByte, JInt)      -> Nothing
              (JShort, JInt)     -> Nothing
              (JChar, JInt)      -> Nothing
              (JInt, JByte)      -> Just $ IT.op OP.i2b
              (JInt, JShort)     -> Just $ IT.op OP.i2s
              (JInt, JChar)      -> Just $ IT.op OP.i2c
              (JInt, JBool)      -> Nothing
              (JInt, JInt)       -> Nothing
              (JInt, JLong)      -> Just $ IT.op OP.i2l
              (JInt, JFloat)     -> Just $ IT.op OP.i2f
              (JInt, JDouble)    -> Just $ IT.op OP.i2d
              (JLong, JInt)      -> Just $ IT.op OP.l2i
              (JLong, JFloat)    -> Just $ IT.op OP.l2f
              (JLong, JDouble)   -> Just $ IT.op OP.l2d
              (JLong, JLong)     -> Nothing
              (JFloat, JDouble)  -> Just $ IT.op OP.f2d
              (JFloat, JInt)     -> Just $ IT.op OP.f2i
              (JFloat, JLong)    -> Just $ IT.op OP.f2l
              (JFloat, JFloat)   -> Nothing
              (JDouble, JLong)   -> Just $ IT.op OP.d2l
              (JDouble, JInt)    -> Just $ IT.op OP.d2i
              (JDouble, JFloat)  -> Just $ IT.op OP.d2f
              (JDouble, JDouble) -> Nothing
              other -> error $ "Implement the other JVM primitive conversions. "
                            ++ show other
          (ObjectType iclass', ft@(ObjectType iclass))
            | ft == jobject || iclass' == iclass -> Nothing
            | otherwise     -> Just $ checkCast iclass
          (ObjectType _, ArrayType _) -> Just $ checkCast arrayIClass
          (ArrayType  ft, ArrayType ft')
            | ft == ft' -> Nothing
            | otherwise -> Just $ checkCast arrayIClass
          (ArrayType  _, ft@(ObjectType iclass))
            | ft == jobject -> Nothing
            | otherwise -> Just $ checkCast iclass
          other -> error $ "Cannot convert between primitive type and object type. "
                        ++ show other
        cs (ObjectType iclass) = [cclass iclass]
        cs (ArrayType _) = [cclass arrayIClass]
        cs _ = []
        arrayIClass = IClassName $ mkFieldDesc' ft2
        checkCast iclass = IT.op OP.checkcast
                        <> IT.ix (cclass iclass)


-- Heuristic taken from https://ghc.haskell.org/trac/ghc/ticket/9159
gswitch :: Code -> [(Int, Code)] -> Maybe Code -> Code
gswitch _    []          (Just deflt) = deflt
gswitch _    [(_, code)] Nothing      = code
gswitch expr [(v, code)] (Just deflt) = expr <> bop code deflt
  where bop
          | v == 0 = ifeq
          | otherwise = \a b -> iconst jint (fromIntegral v) <> if_icmpeq a b

gswitch expr [(v1, code1), (v2, code2)] Nothing = expr <> bop code1 code2
  where bop
          | v1 == 0 = ifeq
          | v2 == 0 = ifne
          | otherwise = \a b -> iconst jint (fromIntegral minV) <> opV a b
        minV = min v1 v2
        opV = if minV == v1 then if_icmpeq else if_icmpne

gswitch expr branches maybeDefault = expr <>
  if nlabels > 0 &&
     tableSpaceCost + 3 * tableTimeCost <=
     lookupSpaceCost + 3 * lookupTimeCost then
    tableswitch branchMap maybeDefault
  else
    lookupswitch branchMap maybeDefault
  where branchMap = IntMap.fromList branches
        nlabels = IntMap.size branchMap
        lo = fst . IntMap.findMin $ branchMap
        hi = fst . IntMap.findMax $ branchMap
        tableSpaceCost = 4 + (hi - lo + 1)
        tableTimeCost = 3
        lookupSpaceCost = 3 + 2 * nlabels
        lookupTimeCost = nlabels

tableswitch :: IntMap Code -> Maybe Code -> Code
tableswitch branchMap maybeDefault =
  mkCode cs $ IT.tableswitch (fmap instr branchMap) (fmap instr maybeDefault)
  where cs = maybe [] consts maybeDefault
          ++ concatMap consts (IntMap.elems branchMap)

lookupswitch :: IntMap Code -> Maybe Code -> Code
lookupswitch branchMap maybeDefault =
  mkCode cs $ IT.lookupswitch (fmap instr branchMap) (fmap instr maybeDefault)
  where cs = maybe [] consts maybeDefault
          ++ concatMap consts (IntMap.elems branchMap)

startLabel :: Label -> Code
startLabel label = mkCode' (IT.putLabel label)

goto :: Label -> Code
goto = mkCode' . IT.gotoLabel NotSpecial

cgoto :: Label -> Code
cgoto = mkCode' . IT.condGoto NotSpecial

gaload :: FieldType -> Code
gaload ft = mkCode cs $ fold
  [ IT.op loadOp
  , modifyStack ( CF.push ft
                . CF.pop (jarray ft)
                . CF.pop jint) ]
  where loadOp = case ft of
          BaseType bt ->
            case bt of
              JBool   -> OP.baload
              JChar   -> OP.caload
              JFloat  -> OP.faload
              JDouble -> OP.daload
              JByte   -> OP.baload
              JShort  -> OP.saload
              JInt    -> OP.iaload
              JLong   -> OP.laload
          _ -> OP.aaload
        cs = maybeToList $ getObjConst ft

gastore :: FieldType -> Code
gastore ft = mkCode' $
     IT.op storeOp
  <> modifyStack ( CF.pop (jarray ft)
                 . CF.pop jint
                 . CF.pop ft)
  where storeOp = case ft of
          BaseType bt ->
            case bt of
              JBool   -> OP.bastore
              JChar   -> OP.castore
              JFloat  -> OP.fastore
              JDouble -> OP.dastore
              JByte   -> OP.bastore
              JShort  -> OP.sastore
              JInt    -> OP.iastore
              JLong   -> OP.lastore
          _ -> OP.aastore

defaultValue :: FieldType -> Code
defaultValue ft@(ObjectType _) = aconst_null ft
defaultValue ft@(ArrayType _)  = aconst_null ft
defaultValue (BaseType bt) =
  case bt of
    JBool   -> iconst jbool 0
    JChar   -> iconst jchar 0
    JFloat  -> fconst 0.0
    JDouble -> dconst 0.0
    JByte   -> iconst jbyte 0
    JShort  -> iconst jshort 0
    JInt    -> iconst jint 0
    JLong   -> lconst 0

swap :: FieldType -> FieldType -> Code
swap ft1 ft2 =
  mkCode' $
     IT.op OP.swap
  <> modifyStack ( CF.push ft1
                 . CF.push ft2
                 . CF.pop  ft1
                 . CF.pop  ft2)
dup_x1 :: FieldType -> FieldType -> Code
dup_x1 ft1 ft2 =
  mkCode' $
    IT.op OP.dup_x1
  <> modifyStack ( CF.push ft2
                 . CF.push ft1
                 . CF.push ft2
                 . CF.pop  ft1
                 . CF.pop  ft2)

dup_x2 :: FieldType -> FieldType -> FieldType -> Code
dup_x2 ft1 ft2 ft3 =
  mkCode' $
     IT.op OP.dup_x2
  <> modifyStack ( CF.push ft3
                 . CF.push ft2
                 . CF.push ft1
                 . CF.push ft3
                 . CF.pop  ft1
                 . CF.pop  ft2
                 . CF.pop  ft3 )

markStackMap :: Code
markStackMap = mkCode' IT.markStackMapFrame

arraylength :: Code
arraylength =
  mkCode' $
     IT.op OP.arraylength
  <> modifyStack ( CF.push jint . CF.pop jobject )

emitLineNumber :: LineNumber -> Code
emitLineNumber = mkCode' . IT.recordLineNumber

monitorenter :: FieldType -> Code
monitorenter ft =
  mkCode' $
     IT.op OP.monitorenter
  <> modifyStack (CF.pop ft)

monitorexit :: FieldType -> Code
monitorexit ft =
  mkCode' $
     IT.op OP.monitorexit
  <> modifyStack (CF.pop ft)

tryFinally :: Int -> Code -> Code -> Code
tryFinally loc tryCode finallyCode = mkCode cs $
  IT.tryFinally ( instr storeCode
                , instr loadCode
                , instr throwCode )
     (instr tryCode)
     (instr finallyCode)
  where cs        = concat $ map consts
          [tryCode, finallyCode, storeCode, loadCode, throwCode]
        storeCode = gstore IT.jthrowable loc
        loadCode  = gload  IT.jthrowable loc
        throwCode = gthrow IT.jthrowable

synchronized :: Int -> Int -> FieldType -> Code -> Code -> Code
synchronized exLoc monLoc monFt loadObjCode syncCode = mkCode cs $
  IT.synchronized ( instr storeCode
                  , instr loadCode
                  , instr throwCode
                  , instr monEnterCode
                  , instr monExitCode
                  )
     (instr syncCode)
  where cs           = concat $ map consts
          [storeCode, loadCode, throwCode, monEnterCode, monExitCode, syncCode]
        storeCode    = gstore IT.jthrowable exLoc
        loadCode     = gload  IT.jthrowable exLoc
        throwCode    = gthrow IT.jthrowable
        monEnterCode = loadObjCode
                    <> dup monFt
                    <> gstore monFt monLoc
                    <> monitorenter monFt
        monExitCode  = gload monFt monLoc <> monitorexit monFt
