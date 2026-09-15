module FnFunctor(main) where
main :: IO ()
main = print (fmap (+1) (*2) (3::Int))
