;;; eq.l — 수 동치 계층 + KB 조회 (sem-loop-1 S3 이관, meowdlm 0.0071)
;;; KB·질의는 state/eq_kb.l·state/eq_q.l (tools/eq_build.py 산출물). 조회·정규화는 여기서 돈다.
;;; 팔: 0=정확일치 1=복수→단수 동치 2=모든 명사 "thing" 붕괴(오병합 대조).

(load "state/eq_kb.l")
(load "state/eq_q.l")

;; 상호 재귀 대비 전방 선언
(define eq-app ())
(define eq-find ())
(define eq-hit-intended ())
(define eq-join ())
(define eq-key ())
(define eq-len ())
(define eq-len-a ())
(define eq-nargs ())
(define eq-norm ())
(define eq-nth ())
(define eq-run ())
(define eq-shown ())
(define eq-sing ())
(define *eq-arm* 0)
(define *eq-pl* (list (list "cat" "cats") (list "dog" "dogs") (list "box" "boxes")))

(define-function eq-nth (xs n) (if (= n 0) (car xs) (eq-nth (cdr xs) (- n 1))))
(define-function eq-len-a (xs a) (if (pair? xs) (eq-len-a (cdr xs) (+ a 1)) a))
(define-function eq-len (xs) (eq-len-a xs 0))
(define-function eq-rev-a (xs acc) (if (pair? xs) (eq-rev-a (cdr xs) (cons (car xs) acc)) acc))
(define-function eq-rev (xs) (eq-rev-a xs ()))
(define-function eq-app (a b) (if (pair? a) (cons (car a) (eq-app (cdr a) b)) b))
(define-function eq-sing-a (w rows)
  (if (not (pair? rows)) w
    (if (equal w (eq-nth (car rows) 1)) (eq-nth (car rows) 0) (eq-sing-a w (cdr rows)))))
(define-function eq-sing (w) (eq-sing-a w *eq-pl*))
(define-function eq-norm (w)
  (cond ((= *eq-arm* 0) w) ((= *eq-arm* 1) (eq-sing w)) (else "thing")))
(define-function eq-nargs (args)
  (if (not (pair? args)) () (cons (eq-norm (car args)) (eq-nargs (cdr args)))))
(define-function eq-key (pred args) (cons pred (eq-nargs args)))

;; KB 조회: 정규화 키가 같은 첫 항목
(define-function eq-find (key kb)
  (if (not (pair? kb)) false
    (if (equal key (eq-key (car (car kb)) (eq-nth (car kb) 1)))
      (car kb) (eq-find key (cdr kb)))))

;; 의도 원자와 같은 항목인가
(define-function eq-hit-intended (intended found)
  (if (not (pair? found)) false
    (if (and (equal (car intended) (car found)) (equal (eq-nth intended 1) (eq-nth found 1))) true false)))

(define-function eq-run (qs i correct hit wrong)
  (if (not (pair? qs)) (list correct hit wrong)
    (let* ((q3 (car qs)) (iatom (eq-nth q3 0)) (qatom (eq-nth q3 1))
           (pred (car iatom)) (intended (eq-nth iatom 1)) (query (eq-nth qatom 1))
           (found (eq-find (eq-key pred query) *eq-kb*))
           (h (if (pair? found) 1 0)) (c (if (eq-hit-intended (list pred intended) found) 1 0)))
      (print "EQQ " i "|" pred "|" (eq-join intended) "|" (eq-join query) "|" c "|" h "\n")
      (eq-run (cdr qs) (+ i 1) (+ correct c) (+ hit h)
              (+ wrong (if (and (= h 1) (= c 0)) 1 0))))))
(define-function eq-join (xs)
  (if (not (pair? xs)) "" (let ((r (eq-join (cdr xs))))
                            (if (equal r "") (car xs) (concat-strings (car xs) (concat-strings " " r))))))

(define-function eq-print (r arm)
  (print "EQARM " arm " correct=" (eq-nth r 0) " hit=" (eq-nth r 1)
         " wrong=" (eq-nth r 2) " of=" (eq-len *eq-qq*) "\n") 0)
(define-function eq-shown (arm)
  (set *eq-arm* arm)
  (eq-print (eq-run *eq-qq* 0 0 0 0) arm))
(print "EQKB " (eq-len *eq-kb*) " queries=" (eq-len *eq-qq*) "\n")