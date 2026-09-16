/* LD_PRELOAD shim: make the RTS's heap alias the executable's static closures.
 *
 * GHC 6.2.2's 64-bit HEAP_ALLOCED (ghc/rts/MBlock.h) indexes a 4096-entry
 * map by the low 32 bits of an address. On Linux HEAP_BASE is 0, so the
 * first megablock comes from mmap(NULL, ...) and its low 32 bits are
 * whatever ASLR chose; when they fall on the executable's data segment
 * (0x1797dd8-0x1d0e668 in build/ghc622-stage2/ghc, map entries 23-29) the GC
 * takes static closures for heap objects and the program dies. This shim
 * gives every large anonymous unhinted mmap the hint ALIAS_HINT (default
 * 0x7f0001600000: gen_map_mblocks drops the first MB, so megablocks start at
 * 0x7f0001700000, entry 23), which makes the collision deterministic.
 *   gcc -shared -fPIC -o mmap-alias.so mmap-alias.c -ldl
 *   LD_PRELOAD=$PWD/mmap-alias.so ../ghc -B../topdir --show-iface X.hi
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <sys/mman.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>

void *mmap(void *addr, size_t len, int prot, int flags, int fd, off_t off)
{
    static void *(*real)(void *, size_t, int, int, int, off_t);
    if (!real) real = dlsym(RTLD_NEXT, "mmap");
    if (addr == NULL && (flags & MAP_ANONYMOUS) && len >= (1u << 20)) {
        const char *e = getenv("ALIAS_HINT");
        uintptr_t hint = e ? strtoull(e, NULL, 0) : 0x7f0001600000ULL;
        void *ret = real((void *)hint, len, prot, flags, fd, off);
        if (getenv("ALIAS_VERBOSE"))
            fprintf(stderr, "mmap-alias: mmap(%#lx, %zu) = %p\n", (unsigned long)hint, len, ret);
        return ret;
    }
    return real(addr, len, prot, flags, fd, off);
}
