;;; horn.l — DLM 커널: 사실 저장소, 폐쇄, 판정, 닫힌 세계 (meowdlm 0.0030–0.0033 이관)
;;;
;;; 파이썬은 웹 수집만 남기고 판정·도출은 Maru 에서 돈다.
;;; meowdlm kernel.py 의 결정 경로(관계 4종, 이행 폐쇄, isa×subclass 상속, 닫힌 세계)를 옮긴다.
;;;
;;; 표현
;;;   사실  (rel a b),  rel ∈ "isa" | "sub" | "in" | "cau"
;;;   폐쇄  (isa* in* cau*)  각각 (a b) 쌍 목록
;;;
;;; 정의 순서 원칙: Maru 는 사용 전 정의를 요구한다(유틸 → 접근자 → 확장 → 고정점 → 판정).

;; ---- 목록 유틸 (전부 꼬리 재귀 + 누적자: Maru 에서 비꼬리 이중 재귀는 결과가 조용히 누락된다)

(define-function h-nth (xs n) (if (= n 0) (car xs) (h-nth (cdr xs) (- n 1))))

(define-function h-len-acc (xs acc) (if (pair? xs) (h-len-acc (cdr xs) (+ acc 1)) acc))

(define-function h-len (xs) (h-len-acc xs 0))

(define-function h-member? (x xs)
  (if (pair? xs) (if (equal x (car xs)) true (h-member? x (cdr xs))) false))

(define-function h-append-acc (xs ys)   ; xs 를 ys 앞에 붙인다(역순 누적 후 뒤집기)
  (if (pair? xs) (h-append-acc (cdr xs) (cons (car xs) ys)) ys))

(define-function h-rev-acc (xs acc) (if (pair? xs) (h-rev-acc (cdr xs) (cons (car xs) acc)) acc))

(define-function h-rev (xs) (h-rev-acc xs ()))

(define-function h-append (xs ys) (h-append-acc (h-rev xs) ys))

(define-function h-filter-acc (f xs acc)
  (if (pair? xs)
    (h-filter-acc f (cdr xs) (if (f (car xs)) (cons (car xs) acc) acc))
    (h-rev acc)))

(define-function h-filter (f xs) (h-filter-acc f xs ()))

(define-function h-uniq-acc (xs acc)
  (if (pair? xs)
    (h-uniq-acc (cdr xs) (if (h-member? (car xs) acc) acc (cons (car xs) acc)))
    (h-rev acc)))

(define-function h-uniq (xs) (h-uniq-acc xs ()))

(define-function h-rel (f) (h-nth f 0))

(define-function h-a (f) (h-nth f 1))

(define-function h-b (f) (h-nth f 2))

(define-function h-pairs-acc (fs acc)
  (if (pair? fs) (h-pairs-acc (cdr fs) (cons (list (h-a (car fs)) (h-b (car fs))) acc))
    (h-rev acc)))

(define-function h-keys (rel facts)
  (h-pairs-acc (h-filter (lambda (f) (equal rel (h-rel f))) facts) ()))

(define-function h-supers (c sub) (h-filter (lambda (e) (equal (h-nth e 0) c)) sub))

(define-function h-pair-with-acc (x es acc)
  (if (pair? es) (h-pair-with-acc x (cdr es) (cons (list x (h-nth (car es) 1)) acc))
    (h-rev acc)))

(define-function h-isa-expand-acc (keys sub acc)
  (if (pair? keys)
    (let ((x (h-nth (car keys) 0)) (c (h-nth (car keys) 1)))
      (h-isa-expand-acc (cdr keys) sub
        (h-append-acc (h-pair-with-acc x (h-supers c sub) ()) acc)))
    (h-rev acc)))

(define-function h-isa-expand (keys sub) (h-isa-expand-acc keys sub ()))

(define-function h-chain-acc (k keys acc)
  (if (pair? keys)
    (if (and (equal (h-nth k 1) (h-nth (car keys) 0))
             (not (equal (h-nth k 0) (h-nth (car keys) 1))))
      (h-chain-acc k (cdr keys) (cons (list (h-nth k 0) (h-nth (car keys) 1)) acc))
      (h-chain-acc k (cdr keys) acc))
    (h-rev acc)))

(define-function h-chain (k keys) (h-chain-acc k keys ()))

(define-function h-trans-acc (keys all acc)
  (if (pair? keys)
    (h-trans-acc (cdr keys) all (h-append-acc (h-chain (car keys) all) acc))
    (h-rev acc)))

(define-function h-trans (keys) (h-trans-acc keys keys ()))

(define-function h-fix (keys f n)
  (if (= n 0) (list keys true)
    (let ((k2 (h-uniq (h-append keys (f keys)))))
      (if (= (h-len k2) (h-len keys)) (list keys false) (h-fix k2 f (- n 1))))))

(define-function h-closure (facts n)
  (let ((sub (h-keys "sub" facts))
        (isa (h-keys "isa" facts))
        (inn (h-keys "in" facts))
        (cau (h-keys "cau" facts)))
    (let* ((ri (h-fix isa (lambda (ks) (h-isa-expand ks sub)) n))
           (rn (h-fix inn h-trans n))
           (rc (h-fix cau h-trans n)))
      (list (h-nth ri 0) (h-nth rn 0) (h-nth rc 0)
            (if (or (h-nth ri 1) (h-nth rn 1) (h-nth rc 1)) true false)))))

(define-function h-holds? (kind a b closed)
  (h-member? (list a b)
             (if (equal kind "isa") (h-nth closed 0)
               (if (equal kind "in") (h-nth closed 1) (h-nth closed 2)))))

(define-function h-verdict (kind a b closed)
  (if (h-holds? kind a b closed) "yes" (if (h-nth closed 3) "unknown" "no")))















































































































































































;; ---- 사실 접근







;; ---- isa × subclass: (x c) 와 (c p) → (x p)







;; ---- 이행: (x y) 와 (y z) → (x z)







;; ---- 고정점







;; ---- 폐쇄







;; ---- 판정






