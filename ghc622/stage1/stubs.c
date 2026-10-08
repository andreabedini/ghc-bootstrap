/* C support for the mhs-linked GHC 6.2.2 compiler.
 *
 * rawSystem: SysTools.lhs's private rawSystem (its __GLASGOW_HASKELL__ < 603
 *   branch) foreign-imports "rawSystem", which GHC ships in
 *   libraries/base/cbits/rawSystem.c. This is that file's Unix branch with
 *   HsInt/HsAddr spelled out (MicroHs has no HsFFI.h in the same shape).
 * setHeapSize, enableTimingStats: RTS hooks that DriverFlags.hs imports for
 *   -H<size> and -Rghc-timing. Under the MicroHs runtime they are no-ops.
 */
#include <stdint.h>
#include <errno.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/time.h>

intptr_t
rawSystem(const char *cmd, char **args)
{
    int pid;
    int wstat;

    switch(pid = fork()) {
    case -1:
        return -1;
    case 0:
      {
        struct timeval tv_null = { 0, 0 };
        struct itimerval itv;
        itv.it_interval = tv_null;
        itv.it_value = tv_null;
        setitimer(ITIMER_REAL, &itv, NULL);
        setitimer(ITIMER_VIRTUAL, &itv, NULL);
        setitimer(ITIMER_PROF, &itv, NULL);
        execvp(cmd, args);
        _exit(127);
      }
    }
    while (waitpid(pid, &wstat, 0) < 0) {
        if (errno != EINTR)
            return -1;
    }
    if (WIFEXITED(wstat))
        return WEXITSTATUS(wstat);
    else if (WIFSIGNALED(wstat))
        errno = EINTR;
    return -1;
}

void setHeapSize(intptr_t n) { (void)n; }
void enableTimingStats(void) { }
