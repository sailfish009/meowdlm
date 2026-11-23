;;; featgate.l — 자질을 도출 판정에 결합 (0.0062)
;;; syn-accepts(구조 도출) AND 자질 검사(lf-check) 를 하나의 수용 판정으로 묶는다.
;;; 미지어 정책: "gate" = 자질 미상이면 구조 판정만 사용, "strict" = 미상이면 자질 검사 생략 불가(구조만)
(define-function fg-nth (xs n) (if (= n 0) (car xs) (fg-nth (cdr xs) (- n 1))))
(define-function fg-len-acc (xs a) (if (pair? xs) (fg-len-acc (cdr xs) (+ a 1)) a))
(define-function fg-len (xs) (fg-len-acc xs 0))
(define-function fg-assoc (k xs) (if (pair? xs) (if (equal k (car (car xs))) (car xs) (fg-assoc k (cdr xs))) ()))
(define-function fg-known (toks lex) (if (not (pair? toks)) true (if (pair? (fg-assoc (car toks) lex)) (fg-known (cdr toks) lex) false)))
;; mode: "struct" (구조만) | "gate" (자질 알면 결합)
(define-function fg-accept (toks lex rules mode)
  (if (not (syn-accepts toks rules lex)) false
    (if (equal mode "struct") true
      (if (fg-known toks *lf-lex*) (if (car (lf-check toks)) true false) true))))
