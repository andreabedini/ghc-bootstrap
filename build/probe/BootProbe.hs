module BootProbe(main) where
import {-# SOURCE #-} IdInfo ( WorkerInfo(..), workerExists )
main :: IO ()
main = print (workerExists NoWorker)
