;;; ana_start.l — S2 실행부. *an-arm*: 0 = 20케이스, 1.. = 코퍼스 청크.
(if (= *an-arm* 0)
  (begin
    (print "ANAFIX cases=" (an-len *an-cases*) "\n")
    (print "FIXOK " (an-cases *an-cases* 0) "/" (an-len *an-cases*) "\n"))
  (begin
    (print "ANACORP start=" *an-start* " limit=" *an-limit* "\n")
    (define *an-r* (an-corpus *an-start* (an-total) (list 0 0)))
    (print "PRON total=" (an-nth *an-r* 0) " resolved=" (an-nth *an-r* 1) "\n")))
(print "END\n")
