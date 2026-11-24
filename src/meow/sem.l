;;; sem.l — meowdlm 458어휘 33규칙 문법(syntax_grammar) 위 파스 트리 + sem + 노드 증명서
;;;
;;; meowdlm 의 syntax.l 은 인식기(boolean Earley)라 트리도 sem 도 남기지 않는다.
;;; 여기서는 span 팩킹 파서(세포당 CAP개)로 트리를 만들고, 규칙별 sem 조립표로 의미항을,
;;; 규칙·자식 범주·sem 재유도로 증명서를 만든다. 형식은 P-NAME-1 명명층이 그대로 먹는
;;; (clause <np…> <vp…>) 를 유지한다.
;;;
;;; 정의 순서 원칙: Maru 는 사용 전 정의를 요구한다.

;; ---------- 리스트 유틸 ----------
(define-function sm-nth (xs n) (if (= n 0) (car xs) (sm-nth (cdr xs) (- n 1))))
(define-function sm-len-a (xs a) (if (pair? xs) (sm-len-a (cdr xs) (+ a 1)) a))
(define-function sm-len (xs) (sm-len-a xs 0))
(define-function sm-app (a b) (if (pair? a) (cons (car a) (sm-app (cdr a) b)) b))
(define-function sm-rev-a (xs acc) (if (pair? xs) (sm-rev-a (cdr xs) (cons (car xs) acc)) acc))
(define-function sm-rev (xs) (sm-rev-a xs ()))
(define-function sm-last (xs) (if (pair? (cdr xs)) (sm-last (cdr xs)) (car xs)))
(define-function sm-assq (k al)
  (if (not (pair? al)) false (if (equal k (car (car al))) (car al) (sm-assq k (cdr al)))))

;; ---------- 노드 ----------
(define-function sm-nd (cat sem kids) (list 'nd cat sem kids))
(define-function sm-lf (cat w) (list 'lf cat w))
(define-function sm-nd? (x) (and (pair? x) (equal (car x) 'nd)))
(define-function sm-lf? (x) (and (pair? x) (equal (car x) 'lf)))
(define-function sm-cat (x) (sm-nth x 1))
(define-function sm-sem (x) (if (sm-lf? x) (sm-nth x 2) (sm-nth x 2)))
(define-function sm-kids (x) (if (sm-nd? x) (sm-nth x 3) ()))

(define *sm-term* (list "DET" "N" "A" "PRON" "CONJ" "V" "NEG" "ADV" "AUX" "PREP" "INTJ"))
(define-function sm-mem* (s xs) (if (not (pair? xs)) false (if (equal s (car xs)) true (sm-mem* s (cdr xs)))))
(define-function sm-term? (s) (sm-mem* s *sm-term*))

;; ---------- sem 조립 ----------
(define-function sm-pick (sym rhs sems)
  (if (not (pair? rhs)) 'none
    (if (equal (car rhs) sym) (car sems) (sm-pick sym (cdr rhs) (cdr sems)))))
(define-function sm-head (sem)
  (if (string? sem) sem
    (if (not (pair? sem)) "none"
      (let ((tag (car sem)))
        (cond ((equal tag 'np) (if (pair? (cdr (cdr sem))) (sm-head (sm-nth sem 2)) (sm-head (sm-nth sem 1))))
              ((equal tag 'ng) (sm-head (sm-nth sem 1)))
              ((equal tag 'pp) (if (pair? (cdr (cdr sem))) (sm-head (sm-nth sem 2)) "none"))
              ((equal tag 'vp) (sm-head (sm-nth sem 1)))
              ((equal tag 'clause) (if (pair? (cdr (cdr sem)))
                                       (if (equal (sm-nth sem 2) 'none) (sm-head (sm-nth sem 1)) (sm-head (sm-nth sem 2)))
                                       "none"))
              (else (sm-last sem)))))))

(define-function sm-mk-sem (lhs rhs sems)
  (cond
    ((equal lhs "S") (if (= (sm-len sems) 1) (car sems)
                        (if (= (sm-len sems) 3) (list 's (car sems) (sm-nth sems 2)) (car sems))))
    ((equal lhs "CL")
     (if (= (sm-len sems) 1) (list 'clause 'none (car sems))
       (list 'clause (sm-pick "NP" rhs sems) (sm-pick "VP" rhs sems))))
    ((equal lhs "NP")
     (cond ((and (equal (sm-len rhs) 2) (equal (car rhs) "DET")) (list 'np (car sems) (sm-head (sm-nth sems 1))))
           ((equal (car rhs) "PRON") (list 'np (car sems)))
           (else (list 'np (sm-head (car sems))))))
    ((equal lhs "NG")
     (cond ((equal (car rhs) "A") (sm-nth sems 1))
           ((= (sm-len sems) 1) (list 'ng (car sems)))
           (else (list 'ng (car sems) (sm-nth sems 1)))))
    ((equal lhs "VP")
     (list 'vp (sm-head (car sems)) (sm-pick "NP" rhs sems)))
    ((equal lhs "VL") (sm-last sems))
    ((or (equal lhs "TRAIL") (equal lhs "MOD")) 'none)
    ((equal lhs "PP") (list 'pp (car sems) (sm-head (sm-nth sems 1))))
    (else (list 'other lhs))))

;; ---------- 차트(전역 상태: 문장마다 초기화) ----------
(define *sm-rules* ())
(define *sm-memo* ())
(define *sm-toks* ())
(define *sm-lex* ())
(define *sm-cats* ())
(define *sm-cap* 3)
(define *sm-nodes* 0)
(define *sm-i* 0)

(define-function sm-cats-of (w lex)
  (if (not (pair? lex)) ()
    (if (equal w (car (car lex))) (sm-nth (car lex) 1) (sm-cats-of w (cdr lex)))))
(define-function sm-cats-in (w tbl)
  (if (not (pair? tbl)) () (if (equal w (car (car tbl))) (sm-nth (car tbl) 1) (sm-cats-in w (cdr tbl)))))
(define-function sm-in-words (w acc)
  (if (not (pair? acc)) false (if (equal w (car (car acc))) true (sm-in-words w (cdr acc)))))
(define-function sm-cat-table (toks lex acc)
  (if (not (pair? toks)) acc
    (if (sm-in-words (car toks) acc)
      (sm-cat-table (cdr toks) lex acc)
      (sm-cat-table (cdr toks) lex (cons (list (car toks) (sm-cats-of (car toks) lex)) acc)))))

(define-function sm-reset (toks lex)
  (set *sm-memo* ()) (set *sm-toks* toks) (set *sm-lex* lex)
  (set *sm-nodes* 0)
  (set *sm-cats* (sm-cat-table toks lex ())))

;; ---------- 파싱(전역 상태 위, 지연 메모) ----------
;; 상호 재귀(cell ↔ rules ↔ match) 때문에 전방 선언을 둔다. Maru 는 이후 define-function 으로 재정의된다.
(define sm-cell ())
(define sm-cell-calc ())
(define sm-try-rules ())
(define sm-rules-of ())
(define sm-match ())
(define sm-match-non ())
(define sm-match-nodes ())
(define sm-memo-has ())
(define sm-memo-get ())
(define sm-memo-put ())
(define sm-rules-scan ())
(define sm-mk-nodes ())
(define sm-sems-of ())
(define sm-rhs-of ())
(define sm-wid-of ())
(define sm-wid ())

(define-function sm-memo-has (cat i j)
  (pair? (sm-assq (list cat i j) *sm-memo*)))
(define-function sm-memo-get (cat i j)
  (let ((e (sm-assq (list cat i j) *sm-memo*))) (if (pair? e) (car (cdr e)) ())))
(define-function sm-memo-put (cat i j nodes)
  (set *sm-memo* (cons (list (list cat i j) nodes) *sm-memo*)) nodes)

(define-function sm-cell (cat i j)
  (if (sm-memo-has cat i j) (sm-memo-get cat i j)
    (sm-memo-put cat i j (sm-cell-calc cat i j))))

(define-function sm-cell-calc (cat i j)
  (if (sm-term? cat)
    (if (= (+ i 1) j)
      (if (sm-mem* cat (sm-cats-in (sm-nth *sm-toks* i) *sm-cats*))
        (list (sm-lf cat (sm-nth *sm-toks* i))) ())
      ())
    (sm-try-rules cat (sm-rules-of cat) i j () )))

(define-function sm-rules-of (cat) (sm-rules-scan *sm-rules* cat ()))
(define-function sm-rules-scan (rs cat acc)
  (if (not (pair? rs)) (sm-rev acc)
    (sm-rules-scan (cdr rs) cat (if (equal (car (car rs)) cat) (cons (car rs) acc) acc))))

(define-function sm-try-rules (cat rs i j acc)
  (if (not (pair? rs)) (sm-rev acc)
    (if (>= (sm-len acc) *sm-cap*) (sm-rev acc)
      (let ((rhs (sm-rhs-of (car rs))))
        (sm-try-rules cat (cdr rs) i j
          (sm-app acc (sm-mk-nodes cat rhs (sm-match rhs i j ()))))))))

(define-function sm-rhs-of (r) (sm-nth r 1))
(define-function sm-mk-nodes (cat rhs kidlists)
  (if (not (pair? kidlists)) ()
    (cons (sm-nd cat (sm-mk-sem cat rhs (sm-sems-of (car kidlists))) (car kidlists))
          (sm-mk-nodes cat rhs (cdr kidlists)))))
(define-function sm-sems-of (kids)
  (if (not (pair? kids)) () (cons (sm-sem (car kids)) (sm-sems-of (cdr kids)))))

;; rhs 기호열을 pos..j 에 정확히 맞추는 자식열들(최대 CAP 개)
(define-function sm-match (rhs pos j kids)
  (if (not (pair? rhs)) (if (= pos j) (list (sm-rev kids)) ())
    (if (> pos j) ()
      (if (sm-term? (car rhs))
        (if (and (< pos j) (sm-mem* (car rhs) (sm-cats-in (sm-nth *sm-toks* pos) *sm-cats*)))
          (sm-match (cdr rhs) (+ pos 1) j (cons (sm-lf (car rhs) (sm-nth *sm-toks* pos)) kids))
          ())
        (sm-match-non (cdr rhs) (car rhs) pos j kids () (+ pos 1))))))

(define-function sm-match-non (rhs sym pos j kids acc e)
  (if (or (>= (sm-len acc) *sm-cap*) (> e j)) (sm-rev acc)
    (sm-match-non rhs sym pos j kids
      (sm-app acc (sm-match-nodes (sm-cell sym pos e) rhs pos j kids)) (+ e 1))))

(define-function sm-match-nodes (nodes rhs pos j kids)
  (if (not (pair? nodes)) ()
    (sm-app (sm-match rhs (+ pos (sm-wid (car nodes))) j (cons (car nodes) kids))
              (sm-match-nodes (cdr nodes) rhs pos j kids))))

;; 노드의 토큰 폭
(define-function sm-wid (t)
  (if (sm-lf? t) 1 (sm-wid-of (sm-kids t))))
(define-function sm-wid-of (ks) (if (not (pair? ks)) 0 (+ (sm-wid (car ks)) (sm-wid-of (cdr ks)))))

;; ---------- 트리 출력·집계 ----------
(define sm-nnodes ())
(define-function sm-nnode (t)
  (if (sm-lf? t) 1 (+ 1 (sm-nnodes (sm-kids t)))))
(define-function sm-nnodes (ts) (if (not (pair? ts)) 0 (+ (sm-nnode (car ts)) (sm-nnodes (cdr ts)))))

;; ---------- 증명서 재유도 검사 ----------
(define sm-chk-rules ())
(define sm-chk-rule ())
(define sm-chk-kids ())
(define sm-kid-cats ())
(define-function sm-chk-leaf (t)
  (sm-mem* (sm-cat t) (sm-cats-of (sm-sem t) *sm-lex*)))
(define-function sm-chk-tree (t)
  (if (sm-lf? t) (sm-chk-leaf t)
    (if (not (sm-nd? t)) false
      (if (sm-chk-rules (sm-cat t) (sm-rules-of (sm-cat t)) t) (sm-chk-kids (sm-kids t)) false))))
(define-function sm-chk-kids (ks)
  (if (not (pair? ks)) true
    (if (sm-chk-tree (car ks)) (sm-chk-kids (cdr ks)) false)))
(define-function sm-chk-rules (cat rs t)
  (if (not (pair? rs)) false
    (if (sm-chk-rule (car rs) t) true (sm-chk-rules cat (cdr rs) t))))
(define-function sm-chk-rule (r t)
  (let ((rhs (sm-rhs-of r)))
    (if (equal (sm-kid-cats (sm-kids t)) rhs)
      (if (equal (sm-mk-sem (car r) rhs (sm-sems-of (sm-kids t))) (sm-sem t)) true false)
      false)))
(define-function sm-kid-cats (ks)
  (if (not (pair? ks)) () (cons (sm-cat (car ks)) (sm-kid-cats (cdr ks)))))