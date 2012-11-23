{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE NoImplicitPrelude #-}

-- | An example implementation of the lovely continuation monad.

module Cont where

import Language.Fay.FFI
import Language.Fay.Prelude

--------------------------------------------------------------------------------
-- Entry point.

-- | Main entry point.
main :: Fay ()
main = runContT demo (const (return ()))

demo :: Deferred ()
demo = case contT of
  CC return (>>=) (>>) callCC lift -> do
    print "Hello!"
    sleep 500
    contents <- readFile "README.md"
    print ("File contents is: " ++ take 10 contents ++ "...")

--------------------------------------------------------------------------------
-- Deferred library.

-- | An example deferred monad.
type Deferred a = ContT () Fay a

-- | Sleep synchronously for n milliseconds.
sleep :: Int -> Deferred ()
sleep n = ContT $ \c -> setTimeout n (c ())

-- | Set an asynchronous timeout.
setTimeout :: Int -> Fay () -> Fay ()
setTimeout = ffi "global.setTimeout(%2,%1)"

-- | Read the given file synchronously.
readFile :: String -> Deferred String
readFile path = ContT $ \c -> readFile' path c

readFile' :: Foreign b => String -> (String -> Fay b) -> Fay b
readFile' = ffi "require('fs').readFile(%1,'utf-8',function(_,s){ %2(s); })"

-- | Print something in the deferred monad.
print :: String -> Deferred ()
print x = cc_lift contT (print' x)

-- | Print using console.log.
print' :: String -> Fay ()
print' = ffi "console.log(%1)"

--------------------------------------------------------------------------------
-- Continuation library.

-- | The continuation monad.
data ContT r m a = ContT { runContT :: (a -> m r) -> m r }
instance (Monad m) => Monad (ContT r m)

data CC = CC
  { cc_return :: forall a r. a -> ContT r Fay a
  , cc_bind :: forall a b r. ContT r Fay a -> (a -> ContT r Fay b) -> ContT r Fay b
  , cc_then :: forall a b r. ContT r Fay a -> ContT r Fay b -> ContT r Fay b
  , cc_callCC :: forall a b r. ((a -> ContT r Fay b) -> ContT r Fay a) -> ContT r Fay a
  , cc_lift :: forall a r. Fay a -> ContT r Fay a
  }

-- | The continuation monad module.
contT =
  let return a = ContT (\f -> f a)
      m >>= k = ContT $ \c -> runContT m (\a -> runContT (k a) c)
      m >> n = m >>= \_ -> n
      callCC f = ContT $ \c -> runContT (f (\a -> ContT $ \_ -> c a)) c
      lift m = ContT (\x -> m >>=* x)
  in CC return (>>=) (>>) callCC lift where (>>=*) = (>>=)

--------------------------------------------------------------------------------
-- Crap.

take 0 _ = []
take n (x:xs) = x : take (n-1) xs