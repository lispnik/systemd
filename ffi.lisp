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
