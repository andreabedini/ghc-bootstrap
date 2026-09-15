/* Trivial C driver: initialise and shut down GHC 6.2.2's RTS with no
 * Haskell code at all, to prove libHSrts.a is self-consistent. */
#include <stdio.h>
#include "HsFFI.h"
int main(int argc, char *argv[])
{
    hs_init(&argc, &argv);
    printf("hs_init ok\n");
    hs_exit();
    printf("hs_exit ok\n");
    return 0;
}
