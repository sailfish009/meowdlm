;;; sem_start.l — S1 실행부: arm 이 *sm-start* / *sm-limit* 을 정한 뒤 호출된다.
(print "SEM458 rules=" (sm-len *rules*) " lex=" (sm-len *lexicon*)
       " start=" *sm-start* " limit=" *sm-limit* "\n")
(define *S458-R* (sm-run *sm-start* (sm-total *sm-limit*) (list 0 0 0 0)))
(print "TOTAL derived=" (sm-nth *S458-R* 0) " sem=" (sm-nth *S458-R* 1)
       " cert=" (sm-nth *S458-R* 2) " nodes=" (sm-nth *S458-R* 3) "\n")
(print "END\n")
