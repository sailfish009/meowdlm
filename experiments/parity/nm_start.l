;;; nm_start.l — fixture 의미항 336개를 원자로 덤프한다(NM-ATOMS). 데이터 준비용.
(define *D* (fg-decl11))
(define-function when (c body) (if c body 0))
(define-function nm-take (xs n) (if (= n 0) () (cons (car xs) (nm-take (cdr xs) (- n 1)))))
;; VPred 규칙 계열별로 decl 을 쪼개 열거한다(전 계열을 빠짐없이 덮기 위해서).
(define-function nm-only (decl idx)
  (nm-app (nm-take decl 3) (cons (nm-nth (nm-drop decl 3) idx) (nm-drop decl 6))))
;; cop 계열은 Comp 하위 규칙(A/PREP/Obj)까지 분리해야 전부 덮인다.
(define-function nm-decl-cop (decl cidx)
  (nm-app (nm-take decl 3)
          (cons (nm-nth (nm-drop decl 3) 2)
                (nm-app (nm-take (nm-drop decl 6) 2) (list (nm-nth (nm-drop decl 8) cidx))))))
(define *LK* (fg-lk-decl *D*))
(define *SBJ* (fg-ntrees (fg-gcat *LK* 'Sbj () (fg-nilsub))))
(define-function nm-vps-of (idx acc)
  (if (> idx 2) acc
    (nm-vps-of (+ idx 1)
      (nm-app acc (fg-ntrees (fg-gcat (fg-lk-decl (nm-only *D* idx)) 'VPred () (fg-nilsub)))))))
(define-function nm-vps-cop (cidx acc)
  (if (> cidx 2) acc
    (nm-vps-cop (+ cidx 1)
      (nm-app acc (fg-ntrees (fg-gcat (fg-lk-decl (nm-decl-cop *D* cidx)) 'VPred () (fg-nilsub)))))))
(define *VPS* (nm-app (nm-vps-of 0 ()) (nm-vps-cop 0 ())))

(define-function nm-stride (xs k i acc)
  (if (not (pair? xs)) (nm-rev acc)
    (nm-stride (cdr xs) k (+ i 1) (if (= 0 (- i (* k (/ i k)))) (cons (car xs) acc) acc))))
(define-function nm-sems-vp (s vps acc)
  (if (not (pair? vps)) acc
    (nm-sems-vp s (cdr vps) (cons (list 'clause s (fg-sem-of (car vps))) acc))))
(define-function nm-sems-of (gs vps acc)
  (if (not (pair? gs)) acc
    (nm-sems-of (cdr gs) vps (nm-sems-vp (fg-sem-of (car gs)) vps acc))))
(define *SEM* (nm-sems-of (nm-stride *SBJ* 4 0 ()) (nm-stride *VPS* 3 0 () ) ()))

;; 어휘 확장(공개): 폐쇄 결과를 표면으로 되돌리기 위해 필요한 최소 2어만 넣는다.
(set *lf-lex* (nm-app (list (list "animal" "N" -1 0 -1 "noun")
                            (list "living" "N" -1 0 -1 "noun"))
                      *lf-lex*))


(define *SEM* (nm-sems-of (nm-stride *SBJ* 4 0 ()) (nm-stride *VPS* 3 0 ()) ()))

(define-function nm-dump-atoms (as sid j)
  (if (not (pair? as)) 0
    (begin
      (print "ATOM|" sid "|" j "|" (nm-pred (car as)) "|" (nm-join (nm-args (car as))) "||1|1|1\n")
      (+ 1 (nm-dump-atoms (cdr as) sid (+ j 1))))))
(define-function nm-dump (ss i n)
  (if (not (pair? ss)) n
    (let ((as (nm-atoms (car ss))))
      (nm-dump (cdr ss) (+ i 1) (+ n (nm-dump-atoms as i 0))))))
(define *nm-n* 0)
(define *nm-res* 0)
(define *nm-abs* 0)
(define *nm-prev* ())

;; 대명사 인자: an 으로 해소되면 상수, 아니면 "?" 기권. *nm-ana* = 1 일 때만.
(define-function nm-ana-one (w win)
  (if (and (= *nm-ana* 1) (an-pron? w))
    (let ((r (an-resolve w win)))
      (set *nm-n* (+ *nm-n* 1))
      (if (equal (car r) "ok")
        (begin (set *nm-res* (+ *nm-res* 1)) (print "ANARG " w "|" (an-nth r 1) "\n") (an-nth r 1))
        (begin (set *nm-abs* (+ *nm-abs* 1)) (print "ANARG " w "|?\n") "?")))
    w))
(define-function nm-ana-args (args win)
  (if (not (pair? args)) () (cons (nm-ana-one (car args) win) (nm-ana-args (cdr args) win))))
(define-function nm-ana-atoms (as win)
  (if (not (pair? as)) 0
    (begin (nm-ana-args (nm-args (car as)) win) (nm-ana-atoms (cdr as) win))))
(define-function nm-ana-walk (ss)
  (if (not (pair? ss)) 0
    (begin
      (let ((as (nm-atoms (car ss))))
        (nm-ana-atoms as (an-window *nm-prev*)))
      (set *nm-prev* (cons (car ss) (an-take *nm-prev* 2)))
      (nm-ana-walk (cdr ss)))))
(print "NM-ATOMS " (nm-dump *SEM* 0 0) "\n")
(when (= *nm-ana* 1)
  (begin (nm-ana-walk *SEM*)
         (print "PRONANA total=" *nm-n* " resolved=" *nm-res* " abstain=" *nm-abs* "\n")))
(print "END\n")
