(in-package #:systemd)

(cffi:define-foreign-library libsystemd
  (:linux (:or "libsystemd.so.0" "libsystemd.so"))
  (t      (:default "libsystemd")))

(eval-when (:load-toplevel :execute)
  (handler-case (cffi:use-foreign-library libsystemd)
    (cffi:load-foreign-library-error (c)
      (warn "libsystemd not available: ~A. ~
             systemd: calls will signal until it can be loaded." c))))

(cffi:defcstruct iovec
  (iov-base :pointer)
  (iov-len  :size))

(cffi:defcfun ("sd_journal_sendv" %sd-journal-sendv) :int
  (iov :pointer)
  (n   :int))

(cffi:defcfun ("sd_notify" %sd-notify) :int
  (unset-environment :int)
  (state             :string))

(cffi:defcfun ("sd_listen_fds" %sd-listen-fds) :int
  (unset-environment :int))

(cffi:defcfun ("sd_watchdog_enabled" %sd-watchdog-enabled) :int
  (unset-environment :int)
  (usec              :pointer))

(define-condition libsystemd-error (error)
  ((function :initarg :function :reader libsystemd-error-function)
   (errno    :initarg :errno    :reader libsystemd-error-errno))
  (:report (lambda (c stream)
             (format stream "~A failed: errno ~D"
                     (libsystemd-error-function c)
                     (libsystemd-error-errno c)))))

(defun %check (rc fn-name)
  "If RC is negative, signal LIBSYSTEMD-ERROR; otherwise return RC."
  (if (minusp rc)
      (error 'libsystemd-error :function fn-name :errno (- rc))
      rc))
