{-# Language ImplicitParams #-}

module Fig.Bless.Builtins
  ( builtins
  ) where

import Fig.Prelude

import Control.Monad.State.Strict (execStateT, StateT)

import qualified Data.Map.Strict as Map
import qualified Data.Text as Text

import qualified Fig.Bless.Syntax as Syn
import Fig.Bless.Types
import Fig.Bless.Runtime

-- * Helper functions
stateful :: Running m t => [BType] -> [BType] -> StateT (VM m t) m a -> (BuiltinProgram m t, BProgType)
stateful inp out f = (execStateT f, BProgType {..})

push :: (Running m t, MonadState (VM m' t) m) => ValueF t -> m ()
push v = state \vm -> ((), vm { stack = v : vm.stack })

pop :: (Running m t, MonadState (VM m' t) m) => m (ValueF t)
pop = get >>= \case
  vm | x:xs <- vm.stack -> do
         put vm { stack = xs }
         pure x
     | otherwise -> throwM $ RuntimeErrorStackUnderflow ?term

effect :: (Running m t, MonadState (VM m' t) m) => EffectF t -> m ()
effect e = state \vm -> ((), vm { effects = e : vm.effects })

int :: Running m t => ValueF t -> m Integer
int (ValueInteger i) = pure i
int v = throwM $ RuntimeErrorSortMismatch ?term ValueSortInteger (valueSort v)

double :: Running m t => ValueF t -> m Double
double (ValueDouble d) = pure d
double v = throwM $ RuntimeErrorSortMismatch ?term ValueSortDouble (valueSort v)

string :: Running m t => ValueF t -> m Text
string (ValueString s) = pure s
string v = throwM $ RuntimeErrorSortMismatch ?term ValueSortString (valueSort v)

program :: Running m t => ValueF t -> m (Syn.ProgramF t)
program (ValueProgram p) = pure p
program v = throwM $ RuntimeErrorSortMismatch ?term ValueSortProgram (valueSort v)

array :: Running m t => ValueF t -> m [ValueF t]
array (ValueArray a) = pure a
array v = throwM $ RuntimeErrorSortMismatch ?term ValueSortProgram (valueSort v)

call :: (Running m t, MonadState (VM m t) m) => Syn.Extractor m t -> Syn.ProgramF t -> m ()
call ext p = get >>= void . runProgram ext p

-- * Stack operations
stackOps :: RunningTop m t => Builtins m t
stackOps t = let ?term = t in Map.fromList
  [ ( "x2", const $ stateful [BTypeVariable "a"] [BTypeVariable "a", BTypeVariable "a"] do
        x <- pop
        push x
        push x
    )
  , ( "xp", const $ stateful [BTypeVariable "a", BTypeVariable "b"] [BTypeVariable "b", BTypeVariable "a"] do
        x <- pop
        y <- pop
        push x
        push y
    )
  ]

-- * Arithmetic builtins
add :: Running m t => Builtin m t
add _ = stateful [BTypeInteger, BTypeInteger] [BTypeInteger] do
  y <- int =<< pop
  x <- int =<< pop
  push . ValueInteger $ x + y

mul :: Running m t => Builtin m t
mul _ = stateful [BTypeInteger, BTypeInteger] [BTypeInteger] do
  y <- int =<< pop
  x <- int =<< pop
  push . ValueInteger $ x * y

sub :: Running m t => Builtin m t
sub _ = stateful [BTypeInteger, BTypeInteger] [BTypeInteger] do
  y <- int =<< pop
  x <- int =<< pop
  push . ValueInteger $ x - y

div :: Running m t => Builtin m t
div _ = stateful [BTypeInteger, BTypeInteger] [BTypeInteger] do
  y <- int =<< pop
  x <- int =<< pop
  push . ValueInteger $ quot x y

arithmeticOps :: RunningTop m t => Builtins m t
arithmeticOps t = let ?term = t in Map.fromList
  [ ("+", add)
  , ("*", mul)
  , ("-", sub)
  , ("/", div)
  ]

-- * String builtins
stringOps :: RunningTop m t => Builtins m t
stringOps t = let ?term = t in Map.fromList
  [ ( "s+", const $ stateful [BTypeString, BTypeString] [BTypeString] do
        y <- string =<< pop
        x <- string =<< pop
        push . ValueString $ x <> y
    )
  , ( "s/", const $ stateful [BTypeString, BTypeString] [BTypeArray BTypeString] do
        sep <- string =<< pop
        s <- string =<< pop
        push . ValueArray $ ValueString <$> Text.splitOn sep s
    )
  ]

-- * Array builtins
arrayOps :: RunningTop m t => Builtins m t
arrayOps t = let ?term = t in Map.fromList
  [ ( "a+", const $ stateful [BTypeArray (BTypeVariable "a"), BTypeArray (BTypeVariable "a")] [BTypeArray (BTypeVariable "a")] do
        y <- array =<< pop
        x <- array =<< pop
        push . ValueArray $ x <> y
    )
  , ( "a", const $ stateful [BTypeInteger] [BTypeArray BTypeInteger] do
        n <- int =<< pop
        push . ValueArray $ ValueInteger <$> [0..n-1]
    )
  , ( "a:", const $ stateful [BTypeVariable "a", BTypeArray (BTypeVariable "a")] [BTypeArray (BTypeVariable "a")] do
        x <- pop
        xs <- array =<< pop
        push . ValueArray $ x:xs
    )
  , ( "a*", \ext -> stateful [BTypeProgram (BProgType [BTypeVariable "a"] []), BTypeArray (BTypeVariable "a")] [BTypeArray (BTypeVariable "a")] do
        f <- program =<< pop
        xs <- array =<< pop
        forM xs $ call ext f
    )
  ]

-- * Side effects
sideeffectOps :: RunningTop m t => Builtins m t
sideeffectOps t = let ?term = t in Map.fromList
  [ ( "pr", const $ stateful [BTypeVariable "a"] [] do
        x <- pop
        effect $ EffectPrint x
    )
  , ( "sb", const $ stateful [BTypeString] [] do
        x <- pop
        effect $ EffectSoundboard x
    )
  , ( "tm", const $ stateful [BTypeString] [] do
        x <- pop
        effect $ EffectModelToggle x
    )
  ]

-- * All builtins
builtins :: RunningTop m t => Builtins m t
builtins t = Map.unions @[]
  [ stackOps t
  , arithmeticOps t
  , stringOps t
  , arrayOps t
  , sideeffectOps t
  ]
