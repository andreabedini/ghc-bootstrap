/* Adjustor stubs for x86-64.
 *
 * ghc/rts/Adjustor.c implements createAdjThunk and freeHaskellFunctionPtr
 * only under
 *
 *     #if defined(i386_TARGET_ARCH) || defined(sparc_TARGET_ARCH)
 *
 * with the comment "Heavily arch-specific, I'm afraid..". They generate
 * machine code at runtime so a Haskell closure can be handed to C as a
 * function pointer -- the "foreign export dynamic" facility. x86-64 did not
 * exist in 1999, so 4.08.2 has no implementation for it and the whole file
 * compiles to nothing here.
 *
 * IOExts re-exports freeHaskellFunctionPtr, which is enough to leave it
 * undefined at link time. Nothing in the compiler's own operation creates a C
 * callback, so a stub that fails loudly is the honest representation: the
 * facility is genuinely absent on this platform rather than quietly broken.
 *
 * Writing a real x86-64 adjustor would mean inventing a piece of GHC that
 * never existed, which is well outside bootstrapping it.
 */
#include "Rts.h"

StgStablePtr createAdjThunk(StgStablePtr hptr, char *typeString);

StgStablePtr
createAdjThunk(StgStablePtr hptr, char *typeString)
{
  barf("createAdjThunk: foreign export dynamic is not implemented on x86-64 "
       "in GHC 4.08.2 (see ghc/rts/Adjustor.c)");
}

void
freeHaskellFunctionPtr(void* ptr)
{
  barf("freeHaskellFunctionPtr: foreign export dynamic is not implemented on "
       "x86-64 in GHC 4.08.2 (see ghc/rts/Adjustor.c)");
}
