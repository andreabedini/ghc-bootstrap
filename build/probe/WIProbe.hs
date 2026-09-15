module WIProbe(main) where
import IdInfo ( IdInfo, WorkerInfo(..), workerExists )
main :: IO ()
main = print (workerExists NoWorker)
