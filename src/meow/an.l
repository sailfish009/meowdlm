;;; an.l — S2: 대명사 해소(recency + 일치)와 기권. 원자 수준에서 대명사 상수를 없앤다.
;;;
;;; 규칙(사전등록):
;;;   R1 목적어 대명사 + 같은 절 주어가 비대명사이고 수 일치 → 주어로 해소
;;;   R2 아니면 직전 W개 절의 명사를 최근 순으로 훑어 수 일치하는 첫 명사로 해소
;;;   R3 후보 0 또는 복수 후보(같은 절 안에서 하나로 정해지지 않음) → 기권 (var)
;;;
;;; 정의 순서 원칙: Maru 는 사용 전 정의를 요구한다.

;; 상호 재귀 대비 전방 선언(이후 define-function 으로 재정의된다).
(define an-app ())
(define an-args ())
(define an-atom-of ())
(define an-char ())
(define an-clause-noms ())
(define an-end-s? ())
(define an-end-ss? ())
(define an-find ())
(define an-find-n ())
(define an-head ())
(define an-last ())
(define an-len ())
(define an-len-a ())
(define an-mem? ())
(define an-nom ())
(define an-nth ())
(define an-num ())
(define an-obj-head ())
(define an-person ())
(define an-pn ())
(define an-pron? ())
(define an-resolve ())
(define an-resolve-obj ())
(define an-rev ())
(define an-rev-a ())
(define an-sem-clause ())
(define an-strlen ())
(define an-strlen-acc ())
(define an-subj ())
(define an-take ())
(define an-var? ())
(define an-w-num ())
(define an-window ())
(define an-window-n ())

(define *an-w* 3)
(define *an-prev* ())
(define *an-pron* (list "i" "me" "you" "he" "she" "him" "it" "they" "them" "we" "us"))

(define-function an-mem? (x xs) (if (not (pair? xs)) false (if (equal x (car xs)) true (an-mem? x (cdr xs)))))
(define-function an-pron? (w) (an-mem? w *an-pron*))
(define-function an-nth (xs n) (if (= n 0) (car xs) (an-nth (cdr xs) (- n 1))))
(define-function an-len-a (xs a) (if (pair? xs) (an-len-a (cdr xs) (+ a 1)) a))
(define-function an-len (xs) (an-len-a xs 0))
(define-function an-app (a b) (if (pair? a) (cons (car a) (an-app (cdr a) b)) b))
(define-function an-take (xs n) (if (or (= n 0) (not (pair? xs))) () (cons (car xs) (an-take (cdr xs) (- n 1)))))

;; 인칭·수: (person . number)  number: 0 단수, 1 복수
(define-function an-pn (w)
  (cond ((or (equal w "i") (equal w "me")) (list 1 0))
        ((or (equal w "we") (equal w "us")) (list 1 1))
        ((equal w "you") (list 2 1))
        ((or (equal w "he") (equal w "him") (equal w "she") (equal w "it")) (list 3 0))
        ((or (equal w "they") (equal w "them")) (list 3 1))
        (else (list 3 0))))
(define-function an-person (w) (car (an-pn w)))
(define-function an-num (w) (an-nth (an-pn w) 1))

;; 절의 명사 후보: (const num) 목록, 표면 순서(주어 → 목적어)
(define-function an-last (xs) (if (pair? (cdr xs)) (an-last (cdr xs)) (car xs)))
(define-function an-head (np)
  (if (not (pair? np)) "none"
    (if (equal (car np) 'np) (an-last np) np)))
(define-function an-nom (w) (if (an-pron? w) false (list w 0)))
(define-function an-subj (sem)
  (if (not (pair? sem)) "none"
    (if (equal (car sem) 'clause) (an-head (an-nth sem 1)) "none")))
(define-function an-obj-head (sem)
  (if (not (pair? sem)) "none"
    (if (and (equal (car sem) 'clause) (pair? (cdr (cdr sem))) (pair? (an-nth sem 2)))
      (let ((vp (an-nth sem 2)))
        (if (and (pair? (cdr (cdr vp))) (pair? (an-nth vp 2)) (equal (car (an-nth vp 2)) 'np))
          (an-head (an-nth vp 2)) "none"))
      "none")))
;; 수는 어휘에서 오지 않으므로 표면형으로 판정한다(복수 = -s, 단 s/ss/us/is 로 끝나는 어형 제외)
(define-function an-char (w i) (if (>= i (string-length w)) 0 (string-at w i)))
(define-function an-strlen-acc (w i) (if (equal (an-char w i) 0) i (an-strlen-acc w (+ i 1))))
(define-function an-strlen (w) (an-strlen-acc w 0))
(define-function an-end-s? (w) (let ((n (an-strlen w))) (if (< n 4) false (equal (an-char w (- n 1)) 115))))
(define-function an-end-ss? (w) (let ((n (an-strlen w))) (if (< n 5) false (equal (an-char w (- n 2)) 115))))
(define-function an-w-num (w)
  (if (an-end-s? w) (if (an-end-ss? w) 0 1) 0))

(define-function an-clause-noms (sem)
  (let ((s (an-subj sem)) (o (an-obj-head sem)))
    (an-app (if (and (string? s) (not (equal s "none")) (not (an-pron? s))) (list (list s (an-w-num s))) ())
             (if (and (string? o) (not (equal o "none")) (not (an-pron? o))) (list (list o (an-w-num o))) ()))))

;; 창(window): 최근 절이 앞. 각 원소는 (list const num)
(define-function an-window-n (sems acc)
  (if (not (pair? sems)) acc
    (an-window-n (cdr sems) (an-app acc (an-rev (an-clause-noms (car sems)))))))
(define-function an-window (sems)
  (an-window-n (an-take sems *an-w*) ()))

;; 후보 찾기: 수 일치, 최근 우선(첫 일치)
(define-function an-find (w win) (an-find-n (an-num w) win))
(define-function an-find-n (want win)
  (if (not (pair? win)) ()
    (if (= (an-nth (car win) 1) want) (list (car (car win))) (an-find-n want (cdr win)))))
(define-function an-rev-a (xs acc) (if (pair? xs) (an-rev-a (cdr xs) (cons (car xs) acc)) acc))
(define-function an-rev (xs) (an-rev-a xs ()))

;; 해소: (list "ok" const) | (list "no" reason)
(define-function an-resolve (w win)
  ;; 1·2인칭은 담화 밖 지시 대상이므로 해소하지 않는다.
  (if (< (an-person w) 3) (list "no" "deictic")
    (let ((c (an-find w win)))
      (cond ((not (pair? c)) (list "no" "no-candidate"))
            (else (list "ok" (car c)))))))

;; 목적어 위치: 같은 절 주어 우선(R1)
(define-function an-resolve-obj (w sem win)
  (let ((s (an-subj sem)))
    (if (and (string? s) (not (equal s "none")) (not (an-pron? s)) (= (an-w-num s) (an-num w)))
      (list "ok" s)
      (an-resolve w win))))

;; 원자 생성: 술어 (인자...) — 대명사 인자는 해소되면 상수, 아니면 (var ?)
(define-function an-args (args win sem)
  (if (not (pair? args)) ()
    (cons (if (an-pron? (car args)) (an-resolve-obj (car args) sem win) (list "ok" (car args)))
          (an-args (cdr args) win sem))))

(define-function an-sem-clause (sem win)
  ;; (clause subj (vp verb obj|none)) → [(pred ok/var args...)]
  (if (not (and (pair? sem) (equal (car sem) 'clause))) ()
    (let* ((subj (an-subj sem)) (vp (an-nth sem 2)))
      (if (not (pair? vp)) ()
        (let ((verb (an-nth vp 1)) (obj (an-obj-head sem)))
          (an-atom-of verb subj obj win sem))))))
(define-function an-atom-of (verb subj obj win sem)
  (let ((a (if (an-pron? subj) (an-resolve subj win) (list "ok" subj))))
    (if (equal obj "none") (list (list verb a))
      (list (list verb a (if (an-pron? obj) (an-resolve-obj obj sem win) (list "ok" obj)))))))

;; 기권 사유별 집계용
(define-function an-var? (r) (equal (car r) "no"))