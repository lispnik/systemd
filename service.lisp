(in-package #:systemd)

(defconstant +sd-listen-fds-start+ 3
  "First file descriptor passed by systemd via socket activation;
later descriptors are at +SD-LISTEN-FDS-START+ + i.")

(defun listen-fds (&key unset-environment)
  "Return a list of file-descriptor integers passed by systemd via
socket activation, or NIL if none were passed. Each fd corresponds
to a Listen* directive in the unit, in declaration order. Pass
:UNSET-ENVIRONMENT T to clear LISTEN_FDS / LISTEN_PID after reading
so child processes don't inherit them.

Signals LIBSYSTEMD-ERROR if sd_listen_fds(3) returns a negative
errno (e.g. when LISTEN_PID does not match this process)."
  (let ((n (%check (%sd-listen-fds (if unset-environment 1 0))
                   "sd_listen_fds")))
    (loop for i from 0 below n
          collect (+ +sd-listen-fds-start+ i))))

(defun watchdog-interval (&key unset-environment)
  "If the systemd watchdog is enabled for this process (WATCHDOG_USEC
in environment, and WATCHDOG_PID — when set — matches this PID),
return the interval in microseconds. Otherwise return NIL.

Recommended ping cadence is half the returned interval, via
NOTIFY-WATCHDOG. Pass :UNSET-ENVIRONMENT T to clear the variables
after reading.

Signals LIBSYSTEMD-ERROR on failure."
  (cffi:with-foreign-object (usec :uint64)
    (let ((rc (%check (%sd-watchdog-enabled (if unset-environment 1 0) usec)
                      "sd_watchdog_enabled")))
      (when (plusp rc)
        (cffi:mem-ref usec :uint64)))))
