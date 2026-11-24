;;; syn_lib.l — 인식기 대조팔 라이브러리(데이터 로드 + 구간 계산). 실행은 syn_accepts_start.l.
(load "data/syntax_grammar.l")
(load "data/syntax_lexicon.l")
(load "data/syntax_corpus.l")

(define *syn-start* 0)
(define *syn-limit* 0)

(define-function syn-total (limit)
  (let ((n (sm-len *corpus*)) (u (+ *syn-start* limit)))
    (if (or (= limit 0) (> u n)) n u)))
