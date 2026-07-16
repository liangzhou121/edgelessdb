/* Copyright (c) Edgeless Systems GmbH

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; version 2 of the License.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1335  USA */

#include <openenclave/ert_stubs.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Forward declare pthread types for pthread_cond_clockwait stub
typedef struct __pthread_cond_s pthread_cond_t;
typedef struct __pthread_mutex_s pthread_mutex_t;
typedef int clockid_t;
struct timespec;
int pthread_cond_timedwait(pthread_cond_t *, pthread_mutex_t *, const struct timespec *);

ERT_STUB(backtrace_symbols_fd, 0)
ERT_STUB_SILENT(fedisableexcept, -1)
ERT_STUB(getcontext, -1)
ERT_STUB_SILENT(gnu_dev_major, 0)
ERT_STUB_SILENT(gnu_dev_minor, 0)
ERT_STUB(makecontext, 0)
ERT_STUB(mallinfo, 0)
ERT_STUB(mallinfo2, 0)
ERT_STUB_SILENT(pthread_setname_np, 0)
ERT_STUB(pthread_yield, -1)
ERT_STUB(setcontext, -1)
ERT_STUB(__fdelt_chk, 0)

// glibc 2.34+ pthread_cond_clockwait is not in musl; delegate to pthread_cond_timedwait
int pthread_cond_clockwait(pthread_cond_t *cond, pthread_mutex_t *mutex,
                           clockid_t clockid, const struct timespec *abstime) {
  (void)clockid;
  return pthread_cond_timedwait(cond, mutex, abstime);
}

// glibc __xpg_strerror_r (POSIX version) is needed by host static libcrypto
int __xpg_strerror_r(int errnum, char *buf, size_t buflen) {
  return strerror_r(errnum, buf, buflen);
}

// glibc 2.38+ redirects standard functions to __isoc23_* variants.
// Provide compat stubs that delegate to the standard versions.
// (EdgelessRT provides strtoll/strtoul/strtoull variants)
int __isoc23_sscanf(const char *__restrict s, const char *__restrict fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  int ret = vsscanf(s, fmt, ap);
  va_end(ap);
  return ret;
}
long __isoc23_strtol(const char *__restrict nptr, char **__restrict endptr, int base) {
  return strtol(nptr, endptr, base);
}
