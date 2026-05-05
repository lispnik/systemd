(in-package #:systemd/tests)

#+sbcl
(eval-when (:compile-toplevel :load-toplevel :execute)
  (require :sb-bsd-sockets)
  (require :sb-posix))

(def-suite systemd-integration
  :description "Roundtrip tests against real libsystemd: journald + sd_notify.")

(in-suite systemd-integration)

;;;; ---------------------------------------------------------------- helpers

(defun %journald-available-p ()
  (and (probe-file "/run/systemd/journal/socket")
       (handler-case
           (zerop (nth-value 2
                             (uiop:run-program '("journalctl" "--version")
                                               :ignore-error-status t
                                               :output nil
                                               :error-output nil)))
         (error () nil))))

(defun %journalctl-field (match field)
  "Return FIELD from the latest journal entry matching MATCH (a
\"FIELD=value\" string), trimmed of trailing whitespace."
  (string-trim
   '(#\Newline #\Space #\Return)
   (uiop:run-program
    (list "journalctl" match "-n" "1"
          (format nil "--output-fields=~A" field)
          "--output=cat" "--no-pager")
    :output :string :ignore-error-status t)))

#+sbcl
(defun %recv-datagram (sock)
  (multiple-value-bind (buf len)
      (sb-bsd-sockets:socket-receive sock nil 4096
                                     :element-type '(unsigned-byte 8))
    (babel:octets-to-string (subseq buf 0 len) :encoding :utf-8)))

#+sbcl
(defun %call-with-fake-notify-socket (thunk)
  "Bind a Unix datagram socket, point NOTIFY_SOCKET at it, run THUNK,
then return the first datagram received as a string."
  (let* ((path (format nil "/tmp/sdnotify-test-~D-~D.sock"
                       (sb-posix:getpid) (random 1000000000)))
         (sock (make-instance 'sb-bsd-sockets:local-socket :type :datagram)))
    (unwind-protect
         (progn
           (sb-bsd-sockets:socket-bind sock path)
           (sb-posix:setenv "NOTIFY_SOCKET" path 1)
           ;; sd_notify performs a synchronous send() before returning, so
           ;; on a local datagram socket the kernel has already queued the
           ;; payload by the time THUNK returns — recv won't block.
           (funcall thunk)
           (%recv-datagram sock))
      (ignore-errors (sb-bsd-sockets:socket-close sock))
      (ignore-errors (delete-file path))
      (ignore-errors (sb-posix:unsetenv "NOTIFY_SOCKET")))))

#+sbcl
(defmacro with-fake-notify-socket (&body body)
  "Evaluate BODY with NOTIFY_SOCKET pointing at a private datagram
socket, then return the first captured payload as a string."
  `(%call-with-fake-notify-socket (lambda () ,@body)))

;;;; ---------------------------------------------------------------- sd_notify

#+sbcl
(test notify/raw-string
  (is (string= "READY=1"
               (with-fake-notify-socket (systemd:notify "READY=1")))))

#+sbcl
(test notify/plist
  (is (string= (format nil "READY=1~%STATUS=ok")
               (with-fake-notify-socket
                 (systemd:notify* :ready 1 :status "ok")))))

#+sbcl
(test notify*/integer-coercion
  (is (string= "MAIN_PID=1234"
               (with-fake-notify-socket (systemd:notify* :main-pid 1234)))))

#+sbcl
(test notify-ready/plain
  (is (string= "READY=1"
               (with-fake-notify-socket (systemd:notify-ready)))))

#+sbcl
(test notify-ready/with-status
  (is (string= (format nil "READY=1~%STATUS=up")
               (with-fake-notify-socket (systemd:notify-ready :status "up")))))

#+sbcl
(test notify-stopping/plain
  (is (string= "STOPPING=1"
               (with-fake-notify-socket (systemd:notify-stopping)))))

#+sbcl
(test notify-stopping/with-status
  (is (string= (format nil "STOPPING=1~%STATUS=bye")
               (with-fake-notify-socket (systemd:notify-stopping :status "bye")))))

#+sbcl
(test notify-status
  (is (string= "STATUS=running"
               (with-fake-notify-socket (systemd:notify-status "running")))))

#+sbcl
(test notify-watchdog
  (is (string= "WATCHDOG=1"
               (with-fake-notify-socket (systemd:notify-watchdog)))))

#+sbcl
(test notify-reloading
  (is (string= "RELOADING=1"
               (with-fake-notify-socket (systemd:notify-reloading)))))

(test notify/no-socket-returns-zero
  ;; Without NOTIFY_SOCKET, sd_notify returns 0.
  #+sbcl (ignore-errors (sb-posix:unsetenv "NOTIFY_SOCKET"))
  (is (zerop (systemd:notify "READY=1"))))

;;;; -------------------------------------------------------- sd_journal_sendv

(test journal-send/roundtrip
  (unless (%journald-available-p)
    (skip "journald not running"))
  (let ((tag (format nil "lisp-test-~D-~D"
                     (get-universal-time) (random 1000000))))
    (is (zerop (systemd:journal-send :message       "hello from test"
                                     :priority      systemd:+log-info+
                                     :lisp-test-tag tag
                                     :code-func     "journal-send/roundtrip")))
    ;; journald is async; give it a beat before reading back.
    (sleep 0.3)
    (is (string= "hello from test"
                 (%journalctl-field
                  (format nil "LISP_TEST_TAG=~A" tag) "MESSAGE")))
    (is (string= "journal-send/roundtrip"
                 (%journalctl-field
                  (format nil "LISP_TEST_TAG=~A" tag) "CODE_FUNC")))))

(test journal-print/roundtrip
  (unless (%journald-available-p)
    (skip "journald not running"))
  (let* ((tag (format nil "print-~D" (random 1000000000)))
         (msg (format nil "msg ~A" tag)))
    (is (zerop (systemd:journal-print systemd:+log-info+ "msg ~A" tag)))
    (sleep 0.3)
    (is (string= msg
                 (%journalctl-field (format nil "MESSAGE=~A" msg) "MESSAGE")))))

;;;; ----------------------------------------------------------------- runner

(defun run-all ()
  (let ((u (run! 'systemd-unit))
        (i (run! 'systemd-integration)))
    (and u i)))
