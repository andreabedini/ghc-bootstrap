-- Unpacking C strings and byte arrays. Both representations are Strings here
-- (see PrelArr), so these are near-identities.
module PrelPack(unpackCStringBA, unpackNBytesST, unpackCString) where
import PrelArr(ByteArray(..))
import Control.Monad.ST(ST)
import GlaExts(Addr#)

unpackCStringBA :: ByteArray Int -> String
unpackCStringBA (ByteArray _ _ s) = s

unpackNBytesST :: ByteArray Int -> Int -> ST s String
unpackNBytesST (ByteArray _ _ s) n = return (take n s)

unpackCString :: ByteArray Int -> String
unpackCString = unpackCStringBA
