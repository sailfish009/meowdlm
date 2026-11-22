;;; query.l — 질의 토큰화와 관계 판독 (meowdlm 0.0034/0.0039 read_relation 이관, 0.0041 재작성)
;;; 정규식 대신 문자 코드로 토큰화한다. 0.0041 에서 다중행 데이터 정의 손상(0.0040 결함 ①)과
;;; 부정·선언 질의 누락(결함 ⑥)을 함께 고친다.

(define *sp* 32)

(define *aux* (list "is" "are" "was" "were" "be" "been" "am" "do" "does" "did" "can" "will" "would" "should" "could" "may" "might" "must" "have" "has" "had"))

(define *det* (list "the" "a" "an" "my" "your" "his" "her" "its" "our" "their" "this" "that" "these" "those" "some" "any" "no" "every" "another" "each"))

(define *prep* (list "of" "in" "on" "at" "from" "to" "with" "for" "about" "under" "over" "into" "onto" "than" "like" "as" "by" "inside" "outside" "near" "behind" "above" "below" "within"))

(define *filler* (list "tell" "me" "if" "whether" "please" "guess" "know" "does" "do" "did"))

(define *not* (list "not" "never"))

(define *or* (list "or"))

(define-function q-alpha? (c) (or (and (<= 97 c) (<= c 122)) (and (<= 65 c) (<= c 90))))

(define-function q-digit? (c) (and (<= 48 c) (<= c 57)))

(define-function q-apos? (c) (= c 39))

(define-function q-alnum? (c) (or (q-alpha? c) (q-digit? c) (q-apos? c)))

(define-function q-lower (c) (if (and (<= 65 c) (<= c 90)) (+ c 32) c))

(define-function q-rev (xs acc) (if (pair? xs) (q-rev (cdr xs) (cons (car xs) acc)) acc))

(define-function q-tok-done (cur acc) (if (pair? cur) (cons (list->string (q-rev cur ())) acc) acc))

(define-function q-tok (s i n cur acc) (if (<= n i) (q-tok-done cur acc) (let ((c (string-at s i))) (if (q-alnum? c) (q-tok s (+ i 1) n (cons (q-lower c) cur) acc) (q-tok s (+ i 1) n () (q-tok-done cur acc))))))

(define-function q-tokens (s) (q-rev (q-tok s 0 (string-length s) () ()) ()))

(define-function q-mem? (x xs) (if (pair? xs) (if (equal x (car xs)) true (q-mem? x (cdr xs))) false))

(define-function q-nth (xs n) (if (= n 0) (car xs) (q-nth (cdr xs) (- n 1))))

(define-function q-len-acc (xs a) (if (pair? xs) (q-len-acc (cdr xs) (+ a 1)) a))

(define-function q-len (xs) (q-len-acc xs 0))

(define-function q-filter-not-acc (xs bad acc) (if (pair? xs) (q-filter-not-acc (cdr xs) bad (if (q-mem? (car xs) bad) acc (cons (car xs) acc))) (q-rev acc ())))

(define-function q-filter-not (xs bad) (q-filter-not-acc xs bad ()))

(define-function q-take (xs n) (if (= n 0) () (if (pair? xs) (cons (car xs) (q-take (cdr xs) (- n 1))) ())))

(define-function q-last (xs) (if (pair? xs) (if (pair? (cdr xs)) (q-last (cdr xs)) (car xs)) ()))

(define-function q-first (xs) (if (pair? xs) (car xs) ()))

(define-function q-chars-acc (s i n acc) (if (< i n) (q-chars-acc s (+ i 1) n (cons (string-at s i) acc)) acc))

(define-function q-join-acc (xs acc) (if (pair? xs) (q-join-acc (cdr xs) (q-chars-acc (car xs) 0 (string-length (car xs)) (if (pair? acc) (cons *sp* acc) acc))) (list->string (q-rev acc ()))))
(define-function q-join (xs) (q-join-acc xs ()))

(define-function q-drop-head (ts) (if (pair? ts) (if (or (q-mem? (car ts) *aux*) (q-mem? (car ts) *filler*)) (q-drop-head (cdr ts)) ts) ts))

(define-function q-drop-n (n xs) (if (= n 0) xs (if (pair? xs) (q-drop-n (- n 1) (cdr xs)) ())))

(define-function q-copula-aux? (b) (if (pair? (cdr b)) (if (pair? (cdr (cdr b))) (and (q-mem? (q-nth b 1) *aux*) (q-mem? (q-nth b 2) (list "a" "an"))) false) false))

(define-function q-copula? (b) (if (pair? (cdr b)) (q-mem? (q-nth b 1) (list "a" "an")) false))

(define-function q-scan-aux (left right) (let ((r (q-filter-not right *det*))) (if (not (pair? r)) () (if (q-mem? (q-first r) *prep*) (list "in" (q-join left) (q-join (q-filter-not (cdr r) *det*))) (list "in" (q-join left) (q-join r))))))

(define-function q-scan (body rest i) (if (pair? rest) (if (q-mem? (car rest) *aux*) (q-scan-aux (q-filter-not (q-take body i) *det*) (cdr rest)) (if (q-mem? (car rest) *prep*) (list "in" (q-last (q-filter-not (q-take body i) *det*)) (q-first (q-filter-not (cdr rest) *det*))) (q-scan body (cdr rest) (+ i 1)))) ()))

(define-function q-read-body (b) (if (not (pair? b)) () (if (q-copula-aux? b) (list "isa" (car b) (q-join (q-drop-n 3 b))) (if (q-copula? b) (list "isa" (car b) (q-join (q-drop-n 2 b))) (q-scan b b 0)))))

(define-function q-has? (w ts) (q-mem? w ts))

(define-function q-any? (ws ts) (if (pair? ws) (if (q-mem? (car ws) ts) true (q-any? (cdr ws) ts)) false))

(define-function q-or-split-acc (ts cur acc) (if (pair? ts) (if (equal (car ts) "or") (q-or-split-acc (cdr ts) () (cons (q-rev cur ()) acc)) (q-or-split-acc (cdr ts) (cons (car ts) cur) acc)) (q-rev (cons (q-rev cur ()) acc) ())))

(define-function q-read (s) (let* ((ts (q-tokens s)) (neg (if (q-any? *not* ts) true false)) (clean (q-filter-not ts *not*)) (body (q-drop-head clean))) (let ((r (q-read-body body))) (if (not (pair? r)) () (list (q-nth r 0) (q-nth r 1) (q-nth r 2) (if neg true false))))))

(define-function q-or-split (ts) (q-or-split-acc ts () ()))

;; ---- 0.0041 추가: 부정(not/never)과 선언(or) 질의
