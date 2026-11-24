;;; nm.l — 의미항 → 원자 명명층 (P-NAME-1 명명부 이관, meowdlm 0.0071)
;;;
;;; 형식: (atom pred (arg ...)). 술어 시드표 + cop 분기(isa/prop/loc)로 의미항을 원자로 옮긴다.
;;; 원자는 이 파일 안에서만 쓰는 최소 표현이며 dlm 커널 형식과 같다(교차 검증 목적).
;;; 정의 순서 원칙: Maru 는 사용 전 정의를 요구한다.

;; ---------- 유틸 ----------
(define-function nm-nth (xs n) (if (= n 0) (car xs) (nm-nth (cdr xs) (- n 1))))
(define-function nm-len-a (xs a) (if (pair? xs) (nm-len-a (cdr xs) (+ a 1)) a))
(define-function nm-len (xs) (nm-len-a xs 0))
(define-function nm-last (xs) (if (pair? (cdr xs)) (nm-last (cdr xs)) (car xs)))
(define-function nm-app (a b) (if (pair? a) (cons (car a) (nm-app (cdr a) b)) b))
(define-function nm-drop (xs n) (if (= n 0) xs (if (pair? xs) (nm-drop (cdr xs) (- n 1)) ())))
(define-function nm-rev-a (xs acc) (if (pair? xs) (nm-rev-a (cdr xs) (cons (car xs) acc)) acc))
(define-function nm-rev (xs) (nm-rev-a xs ()))
(define-function nm-join (ws)
  (if (not (pair? ws)) ""
    (if (pair? (cdr ws)) (concat-strings (car ws) (concat-strings " " (nm-join (cdr ws))))
      (car ws))))

;; ---------- 원자 ----------
(define-function nm-atom (p args) (list 'atom p args))
(define-function nm-pred (a) (car (cdr a)))
(define-function nm-args (a) (car (cdr (cdr a))))
(define-function nm-atom? (a) (and (pair? a) (equal (car a) 'atom)))

;; ---------- 표(시드) ----------
(define *nm-verb* (list
  (list "chases" 'chase "tr") (list "chase" 'chase "tr")
  (list "sleeps" 'sleep "intr") (list "sleep" 'sleep "intr")
  (list "eats" 'eat "tr") (list "eat" 'eat "tr")))
(define *nm-norm* (list (list "cats" "cat") (list "dogs" "dog") (list "boxes" "box")))
(define *nm-norm-on* 0)
(define *nm-ana* 0)   ; 1 = 대명사 인자를 an 으로 해소/기권

(define-function nm-assoc1 (k rows)
  (if (not (pair? rows)) () (if (equal k (car (car rows))) (car rows) (nm-assoc1 k (cdr rows)))))
(define-function nm-verb-row (w) (nm-assoc1 w *nm-verb*))
(define-function nm-norm (w)
  (if (= *nm-norm-on* 0) w
    (let ((r (nm-assoc1 w *nm-norm*))) (if (pair? r) (car (cdr r)) w))))

;; ---------- 의미항 → 원자 ----------
(define-function nm-head (np) (if (equal (car np) 'np) (nm-last np) np))
(define-function nm-const (w) (nm-norm w))
(define-function nm-cop-word (s w)
  (let ((e (lf-entry w)))
    (if (not (pair? e)) ()
      (if (equal (lf-cat e) "A") (list (nm-atom 'prop (list s w)))
        (if (equal (lf-cat e) "PREP") (list (nm-atom 'loc (list s w))) ())))))
(define-function nm-cop-atoms (s comp)
  (cond ((not (pair? comp)) (if (string? comp) (nm-cop-word s comp) ()))
        ((equal (car comp) 'comp) (nm-cop-atoms s (car (cdr comp))))
        ((equal (car comp) 'np) (list (nm-atom 'isa (list s (nm-const (nm-head comp))))))
        (else (nm-cop-word s (car comp)))))
(define-function nm-cop? (v) (let ((e (lf-entry v))) (if (pair? e) (equal (lf-cat e) "COP") false)))
(define-function nm-vp-atoms (s vp)
  (let ((v (car (cdr vp))) (rest (cdr (cdr vp))))
    (if (nm-cop? v) (if (pair? rest) (nm-cop-atoms s (car rest)) ())
      (let ((row (nm-verb-row v)))
        (if (not (pair? row)) ()
          (let ((p (nm-nth row 1)) (val (nm-nth row 2)))
            (if (equal val "tr")
              (if (pair? rest) (list (nm-atom p (list s (nm-const (nm-head (car rest)))))) ())
              (list (nm-atom p (list s))))))))))
(define-function nm-atoms (sem)
  (if (not (pair? sem)) ()
    (if (equal (car sem) 'clause)
      (let ((s (nm-const (nm-head (car (cdr sem))))) (vp (car (cdr (cdr sem)))))
        (nm-vp-atoms s vp))
      ())))