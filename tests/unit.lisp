(in-package #:systemd/tests)

(def-suite systemd-unit
  :description "Pure unit tests; do not require libsystemd or journald.")

(in-suite systemd-unit)

(test normalize-field-name/keyword
  (is (string= "MESSAGE"   (systemd::%normalize-field-name :message)))
  (is (string= "CODE_FUNC" (systemd::%normalize-field-name :code-func)))
  (is (string= "MAIN_PID"  (systemd::%normalize-field-name :main-pid))))

(test normalize-field-name/symbol
  (is (string= "MAIN_PID"  (systemd::%normalize-field-name 'main-pid))))

(test normalize-field-name/string
  (is (string= "FOO_BAR"    (systemd::%normalize-field-name "foo-bar")))
  (is (string= "ALREADY_OK" (systemd::%normalize-field-name "ALREADY_OK"))))

(test normalize-field-name/bad-input
  (signals error (systemd::%normalize-field-name 42)))

(test field-string/basic
  (is (string= "MESSAGE=hello" (systemd::%field-string :message "hello")))
  (is (string= "PRIORITY=6"    (systemd::%field-string :priority 6))))

(test field-string/embedded-newline-passes-through
  ;; sd_journal_sendv handles embedded newlines transparently because each
  ;; iovec carries its own length; nothing in our code should mangle them.
  (is (string= (format nil "MESSAGE=line1~%line2")
               (systemd::%field-string :message (format nil "line1~%line2")))))

(test plist->state-string
  (is (string= "READY=1"
               (systemd::%plist->state-string '(:ready 1))))
  (is (string= (format nil "READY=1~%STATUS=running")
               (systemd::%plist->state-string '(:ready 1 :status "running"))))
  (is (string= "MAIN_PID=1234"
               (systemd::%plist->state-string '(:main-pid 1234)))))

(test journal-send/odd-args-signals
  (signals error (systemd:journal-send :message)))

(test notify*/odd-args-signals
  (signals error (systemd:notify* :ready)))

(test log-priority-constants-distinct
  (let ((vs (list systemd:+log-emerg+ systemd:+log-alert+ systemd:+log-crit+
                  systemd:+log-err+   systemd:+log-warning+ systemd:+log-notice+
                  systemd:+log-info+  systemd:+log-debug+)))
    (is (equal vs '(0 1 2 3 4 5 6 7)))))

;;;; ---------------------------------------------------- journal-log macro

(defun %expansion-string (form)
  (let ((*print-case* :upcase))
    (prin1-to-string (macroexpand-1 form))))

(test journal-log/auto-fills-code-file-when-compiling
  (let* ((*compile-file-pathname* #P"/tmp/foo.lisp")
         (s (%expansion-string
             '(systemd:journal-log systemd:+log-info+ "msg" :user 1))))
    (is (search ":CODE-FILE" s))
    (is (search "/tmp/foo.lisp" s))))

(test journal-log/no-code-file-at-repl
  (let* ((*compile-file-pathname* nil)
         (s (%expansion-string
             '(systemd:journal-log systemd:+log-info+ "msg"))))
    (is (not (search ":CODE-FILE" s)))))

(test journal-log/explicit-code-file-suppresses-auto
  (let* ((*compile-file-pathname* #P"/tmp/foo.lisp")
         (s (%expansion-string
             '(systemd:journal-log systemd:+log-info+ "msg"
                                   :code-file "/other.lisp"))))
    (is (search "/other.lisp" s))
    (is (not (search "/tmp/foo.lisp" s)))))