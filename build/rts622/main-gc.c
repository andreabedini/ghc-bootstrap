/* Exercise the RTS with no Haskell code: init, allocate some heap,
 * run two major collections, shut down. GC.c is the most-patched file. */
#include <stdio.h>
#include "Rts.h"
#include "Storage.h"
int main(int argc, char *argv[])
{
    int i;
    hs_init(&argc, &argv);
    printf("hs_init ok\n");
    performMajorGC();
    printf("performMajorGC #1 ok\n");
    for (i = 0; i < 100000; i++) {
        StgPtr p = allocate(16);        /* 16 words of dead heap per turn */
        p[0] = 0;
    }
    printf("allocate x100000 ok (heap touched)\n");
    performMajorGC();
    printf("performMajorGC #2 ok\n");
    hs_exit();
    printf("hs_exit ok\n");
    return 0;
}
