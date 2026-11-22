;;; agree_start.l — 자질 강제 문법 검사 (0.0049)
(load "data/syntax_grammar.l")
(load "data/syntax_lexicon.l")
(print "AGREE fix=" (a-len *fix*) " accept=" (a-count *fix* 0) "\n")
(a-emit *fix* 0)
;; 대조: 일반 33공리 CFG 로 같은 문장을 판정
(define-function w-rev (xs acc) (if (pair? xs) (w-rev (cdr xs) (cons (car xs) acc)) acc))
(define-function c-emit (ss i) (if (pair? ss) (begin (print "C" i "|" (if (syn-accepts (car ss) *rules* *lexicon*) "1" "0") "\n") (c-emit (cdr ss) (+ i 1))) ()))
(c-emit *fix* 0)
