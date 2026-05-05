# systemd

[![CI](https://github.com/lispnik/systemd/actions/workflows/ci.yml/badge.svg)](https://github.com/lispnik/systemd/actions/workflows/ci.yml)

Common Lisp bindings for two libsystemd entry points:

- `sd_journal_sendv(3)` — write structured records to the systemd journal.
- `sd_notify(3)` — talk to the service manager (`READY=1`, `STATUS=...`,
  `WATCHDOG=1`, etc.).

Linux only at runtime. The system loads on other platforms (the foreign
library load is best-effort) so you can compile and unit-test on macOS,
but the journal/notify calls obviously need a Linux host with libsystemd
installed.

## Requirements

- A Common Lisp with CFFI (tested on SBCL).
- `libsystemd.so.0` (Debian/Ubuntu: `libsystemd0`; build deps:
  `libsystemd-dev`).
- ASDF systems: `cffi`, `babel`, and `fiveam` for the test suite.

## Install

Drop the source tree somewhere ASDF can find it (e.g. a Quicklisp local
project, an ocicl workspace, or anywhere on
`asdf:*central-registry*`) and:

```lisp
(asdf:load-system :systemd)
```

## Examples

### Structured journal entry

```lisp
(systemd:journal-send :message   "user logged in"
                      :priority  systemd:+log-info+
                      :user-id   42
                      :code-func "login-handler")
;; => 0   ; 0 on success, negative errno on failure
```

Field names may be keywords, symbols, or strings. They are upcased and
`-` is mapped to `_` to match journald's accepted character set, so
`:code-func` becomes `CODE_FUNC`. Read it back with:

```sh
journalctl USER_ID=42 --output=verbose
```

### Simple message at a priority

```lisp
(systemd:journal-print systemd:+log-warning+
                       "disk usage is ~D% on ~A" 92 "/var")
```

### Service manager handshake

Inside a unit declared `Type=notify`:

```lisp
(systemd:notify-ready :status "accepting connections")
;; ... main loop ...
(loop (systemd:notify-watchdog) (do-work) (sleep 5))
;; ... shutting down ...
(systemd:notify-stopping :status "draining")
```

Or pass a plist directly:

```lisp
(systemd:notify* :ready    1
                 :status   "running"
                 :main-pid (sb-posix:getpid))
```

Outside a notify socket (e.g. running from a shell), `notify*` returns
`0` and is a no-op — handy for code that should work both interactively
and as a managed service.

### Raw newline-separated payload

```lisp
(systemd:notify (format nil "RELOADING=1~%MONOTONIC_USEC=~D" usec))
```

### Auto-attributed log entries

`journal-log` is a macro form of `journal-send` that fills in
`CODE_FILE` at compile time, so `journalctl --output=verbose` shows the
source file each entry came from:

```lisp
(systemd:journal-log systemd:+log-info+ "user logged in"
                     :user-id   42
                     :code-func "login-handler")
```

Pass `:code-file` explicitly to override, or pass `:code-line` /
`:code-func` for the rest of journald's source-attribution fields.

### Socket activation and the watchdog

```lisp
;; Receive sockets passed by systemd:
(let ((fds (systemd:listen-fds :unset-environment t)))
  (dolist (fd fds)
    ;; fd is a raw integer; wrap it with sb-bsd-sockets:make-inet-socket
    ;; or sb-sys:make-fd-stream, depending on what the unit declared.
    (handle-activated-socket fd)))

;; Pace the watchdog at half the configured interval:
(let ((usec (systemd:watchdog-interval)))
  (when usec
    (loop (sleep (/ usec 2.0 1000000))
          (systemd:notify-watchdog))))
```

Both functions return `NIL` when the relevant environment variables
aren't set, so the same code is safe to run interactively.

## Exported API

| Name                         | Purpose                                                       |
|------------------------------|---------------------------------------------------------------|
| `journal-send &rest plist`   | Structured entry via `sd_journal_sendv`.                      |
| `journal-print prio fmt …`   | One-line `MESSAGE` at `prio`; `format`-style args.            |
| `journal-log prio msg &rest plist` | Macro: `journal-send` with `CODE_FILE` auto-filled.     |
| `notify state &key unset-environment` | Send a pre-formatted `sd_notify` payload.            |
| `notify* &rest plist`        | `notify` with a plist (`:ready 1 :status "ok"`).              |
| `notify-ready &key status`   | `READY=1`, optionally with `STATUS=...`.                      |
| `notify-stopping &key status`| `STOPPING=1`, optionally with `STATUS=...`.                   |
| `notify-status status`       | `STATUS=<status>`.                                            |
| `notify-watchdog`            | `WATCHDOG=1`.                                                 |
| `notify-reloading`           | `RELOADING=1`.                                                |
| `listen-fds &key unset-environment` | List of fds from socket activation, or `NIL`.          |
| `watchdog-interval &key unset-environment` | Watchdog interval in µs, or `NIL`.              |
| `libsystemd-error`           | Condition signaled by `listen-fds` / `watchdog-interval` on failure. |
| `+log-emerg+` … `+log-debug+`| Standard syslog priority integers (0–7).                      |
| `+sd-listen-fds-start+`      | First fd index used by `sd_listen_fds` (`3`).                 |

## Tests

```lisp
(asdf:test-system :systemd)
```

The unit suite has no system dependencies. The integration suite
captures real `sd_notify` traffic on a private Unix datagram socket and
round-trips a journal entry through `journalctl`, so it requires SBCL,
a running journald, and `journalctl` on `PATH`.

## License

MIT.
