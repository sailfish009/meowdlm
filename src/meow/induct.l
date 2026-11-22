;;; induct.l — 원문 → 토큰/어간/단서 추출 (meowdlm induct.py 이관, 0.0043)
;;; 0.0042 진단: 증거 키가 정확 n-gram 문자열이라 단서 재추출 없이는 OOV 실험이 판정에 닿지 못한다.

(define *stop* (list "a" "an" "the" "i" "you" "it" "its" "is" "are" "was" "were" "be" "been" "being" "do" "does" "did" "not" "no" "my" "your" "me" "we" "us" "he" "she" "they" "them" "his" "her" "their" "this" "that" "these" "those" "to" "of" "in" "on" "at" "for" "with" "about" "and" "or" "but" "if" "then" "so" "as" "by" "from" "up" "down" "out" "over" "under" "again" "very" "just" "too" "can" "could" "would" "should" "will" "shall" "may" "might" "must" "have" "has" "had" "having"))

(define-function i-alpha? (c) (and (<= 97 c) (<= c 122)))

(define-function i-lower (c) (if (and (<= 65 c) (<= c 90)) (+ c 32) c))

(define-function i-rev (xs acc) (if (pair? xs) (i-rev (cdr xs) (cons (car xs) acc)) acc))

(define-function i-len-acc (xs a) (if (pair? xs) (i-len-acc (cdr xs) (+ a 1)) a))

(define-function i-len (xs) (i-len-acc xs 0))

(define-function i-member? (x xs) (if (pair? xs) (if (equal x (car xs)) true (i-member? x (cdr xs))) false))

(define-function i-chars (s i n) (if (< i n) (cons (string-at s i) (i-chars s (+ i 1) n)) ()))

(define-function i-str (cs) (list->string cs))

(define-function i-merge (as bs) (if (pair? as) (cons (car as) (i-merge (cdr as) bs)) bs))

(define-function i-cat (a b) (i-str (i-merge (i-chars a 0 (string-length a)) (i-chars b 0 (string-length b)))))

(define-function i-tokdone (cur acc) (if (pair? cur) (cons (i-str (i-rev cur ())) acc) acc))

(define-function i-tok (s i n cur acc) (if (<= n i) (i-tokdone cur acc) (let ((c (string-at s i))) (if (or (i-alpha? c) (= c 39)) (i-tok s (+ i 1) n (cons (i-lower c) cur) acc) (i-tok s (+ i 1) n () (i-tokdone cur acc))))))

(define-function i-init (cs) (if (pair? cs) (if (pair? (cdr cs)) (cons (car cs) (i-init (cdr cs))) ()) ()))

(define-function i-drop-last (cs n) (if (= n 0) cs (if (pair? cs) (i-drop-last (i-init cs) (- n 1)) cs)))

(define-function i-eq (a b) (if (pair? a) (if (pair? b) (if (equal (car a) (car b)) (i-eq (cdr a) (cdr b)) false) false) (if (pair? b) false true)))

(define-function i-vowel? (c) (i-member? c (list 97 101 105 111 117)))

(define-function i-strip-apos (cs acc) (if (pair? cs) (i-strip-apos (cdr cs) (if (= (car cs) 39) acc (cons (car cs) acc))) (i-rev acc ())))

(define-function i-last (cs) (if (pair? cs) (if (pair? (cdr cs)) (i-last (cdr cs)) (car cs)) ()))

(define-function i-second-last (cs) (if (pair? cs) (if (pair? (cdr cs)) (if (pair? (cdr (cdr cs))) (i-second-last (cdr cs)) (car cs)) ()) ()))

(define-function i-final (cs) (if (and (> (i-len cs) 3) (equal (i-last cs) (i-second-last cs)) (not (i-vowel? (i-last cs)))) (i-drop-last cs 1) cs))

(define-function i-strlen (w) (i-len (i-chars w 0 (string-length w))))

(define-function i-content (ts acc) (if (pair? ts) (i-content (cdr ts) (if (or (i-member? (car ts) *stop*) (<= (i-strlen (car ts)) 1)) acc (cons (car ts) acc))) (i-rev acc ())))

(define-function i-drop (ws i) (if (= i 0) ws (if (pair? ws) (i-drop (cdr ws) (- i 1)) ())))

(define-function i-take (ws n) (if (= n 0) () (if (pair? ws) (cons (car ws) (i-take (cdr ws) (- n 1))) ())))

(define-function i-join (ws) (if (pair? ws) (if (pair? (cdr ws)) (i-cat (car ws) (i-cat " " (i-join (cdr ws)))) (car ws)) ""))

(define-function i-ngrams-acc (ws n i acc) (if (<= (+ i n) (i-len ws)) (i-ngrams-acc ws n (+ i 1) (cons (i-join (i-take (i-drop ws i) n)) acc)) (i-rev acc ())))

(define-function i-ngrams (ws n) (i-ngrams-acc ws n 0 ()))

(define-function i-lastn (cs n) (i-drop cs (- (i-len cs) n)))

(define-function i-tail-eq? (cs suf) (i-eq (i-lastn cs (i-len suf)) suf))

(define-function i-suffix-ies (cs) (if (and (> (i-len cs) 4) (i-tail-eq? cs (list 105 101 115))) (i-merge (i-drop-last cs 3) (list 121)) cs))

(define-function i-strip-one? (cs suf) (and (> (i-len cs) (+ (i-len suf) 2)) (i-tail-eq? cs suf)))

(define-function i-strip-suffixes (cs) (if (i-strip-one? cs (list 105 110 103)) (i-drop-last cs 3) (if (i-strip-one? cs (list 101 100)) (i-drop-last cs 2) (if (i-strip-one? cs (list 101 115)) (i-drop-last cs 2) (if (i-strip-one? cs (list 115)) (i-drop-last cs 1) cs)))))

(define-function i-morph-chars (w) (let* ((cs (i-strip-apos (i-chars w 0 (string-length w)) ())) (c1 (i-suffix-ies cs))) (i-final (i-strip-suffixes c1))))

(define-function i-morph (w) (i-str (i-morph-chars w)))

(define-function i-morph-all (ws acc) (if (pair? ws) (i-morph-all (cdr ws) (cons (i-morph (car ws)) acc)) (i-rev acc ())))

(define-function i-tokens (s) (let ((ws (i-rev (i-tok s 0 (string-length s) () ()) ()))) (i-morph-all ws ())))

(define-function i-cues (text) (let* ((ws (i-content (i-tokens text) ()))) (i-merge (i-merge ws (i-ngrams ws 2)) (i-ngrams ws 3))))
