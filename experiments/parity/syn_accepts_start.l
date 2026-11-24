;;; syn_accepts_start.l — meowdlm 인식기(syn-accepts) 수용 비트 출력. C<i>|<0|1>
(define-function syn-run (i upto)
  (if (>= i upto) 0
    (begin
      (print "C" i "|" (if (syn-accepts (sm-nth *corpus* i) *rules* *lexicon*) 1 0) "\n")
      (syn-run (+ i 1) upto))))

(syn-run *syn-start* (syn-total *syn-limit*))
(print "END\n")
