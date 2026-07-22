#include <stdlib.h>

int edgeless_exit_ensure_link;

// edgeless_go_ready is set once invokemain() (and thus the Go runtime) has started. Until then, it is not
// safe to call into Go (e.g. from a static initializer that runs before invokemain()).
int edgeless_go_ready;

void exit(int status) {
  void edgeless_exit();
  edgeless_exit(status);
  abort();  // unreachable; avoids "noreturn does return" warning
}

// abort() is called (directly or via std::terminate(), e.g. for an uncaught std::bad_alloc on OOM) all over
// MariaDB/RocksDB. Edgeless RT's abort() calls oe_abort() directly instead of raising SIGABRT through the
// normal POSIX signal-handler mechanism, so it would otherwise immediately tear down the whole enclave
// without ever going through edb's graceful shutdown path. Redirect to that same path here, like exit()
// above, so the error is logged and edb exits with a well-defined, non-crashing exit code.
void abort(void) {
  void edgeless_exit();
  if (edgeless_go_ready)
    edgeless_exit(134);  // 128 + SIGABRT(6), the conventional signal exit code
  __builtin_trap();  // too early to call into Go (Go runtime not started yet); fall back to a hard crash
}
