(in-package #:systemd)

(defconstant +log-emerg+   0)
(defconstant +log-alert+   1)
(defconstant +log-crit+    2)
(defconstant +log-err+     3)
(defconstant +log-warning+ 4)
(defconstant +log-notice+  5)
(defconstant +log-info+    6)
(defconstant +log-debug+   7)

(defun %normalize-field-name (name)
  (let ((s (etypecase name
             (string name)
             (symbol (symbol-name name)))))
    (string-upcase (substitute #\_ #\- s))))

(defun %field-string (name value)
  (format nil "~A=~A" (%normalize-field-name name) value))

(defun journal-send (&rest fields)
  "Send a structured entry to the systemd journal via sd_journal_sendv(3).
FIELDS is a plist of field/value pairs:
  (journal-send :message \"hello\" :priority 6 :code-func \"main\")
Field names may be symbols or strings; they are upcased and `-' is mapped
to `_'. Values are coerced via PRINC. Returns 0 on success, or a negative
errno from libsystemd."
  (when (oddp (length fields))
    (error "JOURNAL-SEND requires an even number of arguments (plist)."))
  (let* ((strings (loop for (k v) on fields by #'cddr
                        collect (%field-string k v)))
         (n       (length strings))
         (buffers (make-array n :initial-element nil)))
    (cffi:with-foreign-object (iov '(:struct iovec) n)
      (unwind-protect
           (progn
             (loop for i from 0
                   for s in strings
                   for size = (babel:string-size-in-octets s :encoding :utf-8)
                   for buf  = (cffi:foreign-string-alloc
                               s :encoding :utf-8 :null-terminated-p nil)
                   do (setf (aref buffers i) buf)
                      (let ((slot (cffi:mem-aptr iov '(:struct iovec) i)))
                        (setf (cffi:foreign-slot-value slot '(:struct iovec) 'iov-base) buf
                              (cffi:foreign-slot-value slot '(:struct iovec) 'iov-len)  size)))
             (%sd-journal-sendv iov n))
        (loop for b across buffers
              when b do (cffi:foreign-string-free b))))))

(defun journal-print (priority format-string &rest args)
  "Send a single MESSAGE entry at PRIORITY (0..7), formatting like FORMAT."
  (journal-send :message  (apply #'format nil format-string args)
                :priority priority))
