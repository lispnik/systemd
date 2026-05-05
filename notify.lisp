(in-package #:systemd)

(defun notify (state &key unset-environment)
  "Send STATE to the service manager via sd_notify(3). STATE is a
newline-separated list of VARIABLE=VALUE assignments, e.g.
  (notify \"READY=1\")
  (notify (format nil \"STATUS=~A~%READY=1\" \"started\"))
Returns >0 on success, 0 if NOTIFY_SOCKET is unset, <0 on error."
  (%sd-notify (if unset-environment 1 0) state))

(defun %plist->state-string (pairs)
  (with-output-to-string (s)
    (loop for (k v) on pairs by #'cddr
          for first = t then nil
          unless first do (write-char #\Newline s)
          do (format s "~A=~A" (%normalize-field-name k) v))))

(defun notify* (&rest pairs)
  "NOTIFY with a plist instead of a pre-formatted string:
  (notify* :ready 1 :status \"running\")"
  (when (oddp (length pairs))
    (error "NOTIFY* requires an even number of arguments (plist)."))
  (notify (%plist->state-string pairs)))

(defun notify-ready    (&key status)
  (if status (notify* :ready 1 :status status) (notify "READY=1")))
(defun notify-stopping (&key status)
  (if status (notify* :stopping 1 :status status) (notify "STOPPING=1")))
(defun notify-status   (status) (notify* :status status))
(defun notify-watchdog ()        (notify "WATCHDOG=1"))
(defun notify-reloading ()       (notify "RELOADING=1"))
