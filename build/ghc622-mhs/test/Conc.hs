module Main where
import Control.Concurrent
import Control.Concurrent.MVar
import Control.Monad
forM_ :: [a] -> (a -> IO ()) -> IO ()
forM_ = flip mapM_
forkIO_ :: IO () -> IO ()
forkIO_ a = forkIO a >> return ()
forever :: IO a -> IO ()
forever a = a >> forever a
main :: IO ()
main = do
  mv <- newEmptyMVar
  done <- newEmptyMVar
  forM_ [1 .. 5 :: Int] $ \i -> forkIO_ $ do
    forM_ [1 .. 100 :: Int] $ \j -> putMVar mv (i * 1000 + j)
    putMVar done ()
  total <- newMVar (0 :: Int)
  _ <- forkIO $ forever $ do
    v <- takeMVar mv
    modifyMVar_ total (return . (+ v))
  replicateM_ 5 (takeMVar done)
  threadDelay 100000
  readMVar total >>= print
  ch <- newChan
  _ <- forkIO (mapM_ (writeChan ch) [1 .. 1000 :: Int])
  xs <- replicateM 1000 (readChan ch)
  print (sum xs)
  putStrLn "conc done"
