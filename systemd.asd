(asdf:defsystem #:systemd
  :description "CFFI bindings for libsystemd's sd_journal_sendv and sd_notify."
  :license "MIT"
  :version "0.1.0"
  :author "Matthew Kennedy <burnsidemk@gmail.com>"
  :depends-on (#:cffi #:babel)
  :serial t
  :components ((:file "package")
               (:file "ffi")
               (:file "journal")
               (:file "notify")
               (:file "service"))
  :in-order-to ((asdf:test-op (asdf:test-op #:systemd/tests))))

(asdf:defsystem #:systemd/tests
  :description "Tests for #:systemd."
  :depends-on (#:systemd #:fiveam)
  :pathname "tests/"
  :serial t
  :components ((:file "package")
               (:file "unit")
               (:file "integration"))
  :perform (asdf:test-op (op c)
             (unless (uiop:symbol-call '#:systemd/tests '#:run-all)
               (error "systemd tests failed"))))
