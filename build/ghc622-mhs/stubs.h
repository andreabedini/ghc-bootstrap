/* Prototypes for the C functions the mhs-emitted FFI wrappers in ghc.c call
   by name (gcc >= 14 rejects implicit declarations). See stubs.c. */
#include <unistd.h>
#include <time.h>
#include <stdint.h>
intptr_t rawSystem(const char *cmd, char **args);
void setHeapSize(intptr_t n);
void enableTimingStats(void);
