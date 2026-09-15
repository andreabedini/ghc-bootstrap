/* The FFI table for the mhs-linked GHC 6.2.2 compiler.
 *
 * mhs emits this itself when asked for a .c; here it is written out because
 * the binary is built from the .comb (see comb2c.py). The four entries are
 * exactly the foreign imports of the closure that the MicroHs runtime's own
 * ffi_table does not already define (`rg -o '\^&?[A-Za-z_][A-Za-z_0-9]*'
 * ghc.comb` minus eval.c's table = these four), and each wrapper is verbatim
 * what mhs generates for its Haskell type (checked against t/ft.c):
 *
 *   SysTools.rawSystem   c_rawSystem :: Ptr CChar -> Ptr (Ptr CChar) -> IO Int
 *   DriverFlags          setHeapSize :: Int -> IO ()   (-H<size>)
 *   DriverFlags          enableTimingStats :: IO ()    (-Rghc-timing)
 *   Posix shim           c_getpid    :: IO CInt        (SysTools.newTempName)
 */
#include "mhsffi.h"
#include "stubs.h"

from_t mhs_rawSystem(int s) { return mhs_from_Int(s, 2, rawSystem(mhs_to_Ptr(s, 0), mhs_to_Ptr(s, 1))); }
from_t mhs_enableTimingStats(int s) { enableTimingStats(); return mhs_from_Unit(s, 0); }
from_t mhs_setHeapSize(int s) { setHeapSize(mhs_to_Int(s, 0)); return mhs_from_Unit(s, 1); }
from_t mhs_getpid(int s) { return mhs_from_Int(s, 0, getpid()); }

static const struct ffi_entry imp_table[] = {
{ "rawSystem", 2, mhs_rawSystem},
{ "enableTimingStats", 0, mhs_enableTimingStats},
{ "setHeapSize", 1, mhs_setHeapSize},
{ "getpid", 0, mhs_getpid},
{ 0,0 }
};
const struct ffi_entry *xffi_table = imp_table;
static struct ffe_entry exp_table[] = {
  { 0,0 }
};
struct ffe_entry *xffe_table = exp_table;
