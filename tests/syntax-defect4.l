;;; 0.0040 결함 ④ 반례: 비-nullable 완료가 대기 항목으로 전파되어야 한다
(define *rs* (list (list "S" (list "P" "Q")) (list "S" (list "D" "z")) (list "D" (list "R" "Q")) (list "R" (list "a")) (list "P" (list "P1")) (list "P1" (list "P2")) (list "P2" (list "P3")) (list "P3" (list "P4")) (list "P4" (list "P5")) (list "P5" (list "P6")) (list "P6" (list "a")) (list "Q" (list "b"))))
(define *lx* (list (list "x" (list "a")) (list "y" (list "b")) (list "z" (list "z")) (list "w" (list "a"))))
(print "defect4 " (syn-accepts (list "x" "y") *rs* *lx*) "\n")
