/* Reproduce configure's FPTOOLS_CHECK_HTYPE probes (aclocal.m4:726-822) and
 * print the #defines they should have produced.
 *
 * The 6.2.2 configure run in build/rts622 left every HTYPE_* as "#undef"
 * because the probe program it compiles has a K&R `main() {...}` with no
 * return type, which gcc >= 14 rejects outright -- the same 2026-toolchain
 * class as the pre-C99 probes in DECISIONS.md D31/D40. libraries/base needs
 * them: Foreign/Storable.hs:178 uses HTYPE_INT, Foreign/C/Types.hs and
 * System/Posix/Types.hs use one per C type.
 *
 * The logic below is the macro's, verbatim: an arithmetic type that survives
 * the round trip through (int) is an integer type, named Int/Word by its
 * signedness and its width in bits; otherwise it is a float of the matching
 * size. The OpenGL and OpenAL types are left out: they need those headers,
 * belong to other packages, and configure reports them "not supported" too.
 */
#include <stdio.h>
#include <stddef.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <signal.h>
#include <time.h>
#include <termios.h>
#include <string.h>
#include <ctype.h>
#include <sys/resource.h>
#include <wchar.h>   /* wint_t; the probe pulled it in via the HAVE_ headers */

#define HTYPE(cname, mname)                                             \
  do {                                                                  \
    typedef cname testing;                                              \
    if (((testing)((int)((testing)1.4))) == ((testing)1.4))             \
      printf("#undef HTYPE_%s\n#define HTYPE_%s %s%d\n", mname, mname,                          \
             ((testing)(-1) < (testing)0) ? "Int" : "Word",             \
             (int)(sizeof(testing) * 8));                               \
    else                                                                \
      printf("#undef HTYPE_%s\n#define HTYPE_%s %s\n", mname, mname,                            \
             (sizeof(testing) >  sizeof(double)) ? "LDouble" :          \
             (sizeof(testing) == sizeof(double)) ? "Double"  : "Float");\
  } while (0)

int main(void)
{
  printf("\n/* Haskell types for the C types, as FPTOOLS_CHECK_HTYPE would\n"
         "   have defined them; see build/ghc622-mhs/gen-htypes.c. */\n");
  HTYPE(char,               "CHAR");
  HTYPE(signed char,        "SIGNED_CHAR");
  HTYPE(unsigned char,      "UNSIGNED_CHAR");
  HTYPE(short,              "SHORT");
  HTYPE(unsigned short,     "UNSIGNED_SHORT");
  HTYPE(int,                "INT");
  HTYPE(unsigned int,       "UNSIGNED_INT");
  HTYPE(long,               "LONG");
  HTYPE(unsigned long,      "UNSIGNED_LONG");
  HTYPE(long long,          "LONG_LONG");
  HTYPE(unsigned long long, "UNSIGNED_LONG_LONG");
  HTYPE(float,              "FLOAT");
  HTYPE(double,             "DOUBLE");
  HTYPE(ptrdiff_t,          "PTRDIFF_T");
  HTYPE(size_t,             "SIZE_T");
  HTYPE(wchar_t,            "WCHAR_T");
  HTYPE(sig_atomic_t,       "SIG_ATOMIC_T");
  HTYPE(clock_t,            "CLOCK_T");
  HTYPE(time_t,             "TIME_T");
  HTYPE(dev_t,              "DEV_T");
  HTYPE(ino_t,              "INO_T");
  HTYPE(mode_t,             "MODE_T");
  HTYPE(off_t,              "OFF_T");
  HTYPE(pid_t,              "PID_T");
  HTYPE(gid_t,              "GID_T");
  HTYPE(uid_t,              "UID_T");
  HTYPE(cc_t,               "CC_T");
  HTYPE(speed_t,            "SPEED_T");
  HTYPE(tcflag_t,           "TCFLAG_T");
  HTYPE(blkcnt_t,           "BLKCNT_T");
  HTYPE(nlink_t,            "NLINK_T");
  HTYPE(ssize_t,            "SSIZE_T");
  HTYPE(rlim_t,             "RLIM_T");
  HTYPE(wint_t,             "WINT_T");
  return 0;
}
