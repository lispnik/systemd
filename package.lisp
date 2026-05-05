(defpackage #:systemd
  (:use #:cl)
  (:export #:journal-send
           #:journal-print
           #:notify
           #:notify*
           #:notify-ready
           #:notify-stopping
           #:notify-status
           #:notify-watchdog
           #:notify-reloading
           #:+log-emerg+ #:+log-alert+ #:+log-crit+   #:+log-err+
           #:+log-warning+ #:+log-notice+ #:+log-info+ #:+log-debug+))
