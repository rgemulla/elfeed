;;; elfeed-search-tests.el --- search tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'elfeed-search)

(defmacro test-search-parse-filter-duration (filter after-days &optional before-days)
  (let ((day (* 24 60 60)))
    `(should (equal ',(cl-concatenate 'list
                                      (when before-days
                                        (list :before (float (* day before-days))))
                                      (list :after (float (* day after-days))))
                    (elfeed-search-parse-filter ,filter)))))

(ert-deftest elfeed-parse-filter-time-durations ()
  (let ((test-time (encode-time 0 0 0 24 6 2019 t))
        (orig-float-time (symbol-function 'float-time)))
    (cl-letf (((symbol-function 'float-time)
               (lambda (&optional time)
                 (funcall orig-float-time (or time test-time)))))
      (test-search-parse-filter-duration "@5-days-ago--3-days-ago" 5 3)
      (test-search-parse-filter-duration "@3-days-ago--5-days-ago" 5 3)
      (test-search-parse-filter-duration "@2019-06-01" 23)
      (test-search-parse-filter-duration "@2019-06-20--2019-06-01" 23 4)
      (test-search-parse-filter-duration "@2019-06-01--2019-06-20" 23 4)
      (test-search-parse-filter-duration "@2019-06-01--4-days-ago" 23 4)
      (test-search-parse-filter-duration "@4-days-ago--2019-06-01" 23 4))))

(defmacro run-date-filter (filter entry-time-string test-time-string)
  "Creates an entry with ENTRY-TIME-STRING, sets the current time
to TEST-TIME-STRING and then tests the compiled filter function
by calling it with entry and FILTER. Returns t if the filter
matches, nil otherwise."
  `(let* ((test-time (seconds-to-time (elfeed-parse-simple-iso-8601 ,test-time-string)))
          (entry-time (seconds-to-time (elfeed-parse-simple-iso-8601 ,entry-time-string)))
          (orig-float-time (symbol-function 'float-time))
          (entry (elfeed-entry--create
                  :title "test-entry"
                  :date (float-time entry-time))))
     (cl-letf (((symbol-function 'current-time)
                (lambda () test-time))
               ((symbol-function 'float-time)
                (lambda (&optional time)
                  (funcall orig-float-time (or time test-time)))))
       (catch 'elfeed-db-done
         (let ((filter-fn (elfeed-search-compile-filter (elfeed-search-parse-filter ,filter))))
           (funcall filter-fn entry nil 0))))))

(ert-deftest elfeed-search-compile-filter ()
  (should (null (run-date-filter "@1-days-ago"               "2019-06-23" "2019-06-25")))
  (should       (run-date-filter "@3-days-ago"               "2019-06-23" "2019-06-25"))
  (should (null (run-date-filter "@30-days-ago--10-days-ago" "2019-06-23" "2019-06-25")))
  (should       (run-date-filter "@2019-06-01"               "2019-06-23" "2019-06-25"))
  (should (null (run-date-filter "@2019-06-01--2019-06-20"   "2019-06-23" "2019-06-25"))))

(ert-deftest elfeed-search-unparse-filter ()
  (should (string-equal "@5-minutes-ago" (elfeed-search-unparse-filter '(:after 300))))
  (should (string-equal "@5-minutes-ago--1-minute-ago" (elfeed-search-unparse-filter '(:after 300 :before 60)))))

(provide 'elfeed-search-tests)

;;; elfeed-search-tests.el ends here
