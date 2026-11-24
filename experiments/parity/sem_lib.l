;;; sem_lib.l — S1 하네스: 458어휘 코퍼스 문장들에 대해 트리+sem+증명서를 낸다.
;;; arm 은 실행 전에 (set *sm-limit* N) 으로 문장 수를 정한다(0 = 전체).

(load "data/syntax_grammar.l")
(load "data/syntax_lexicon.l")
(load "data/syntax_corpus.l")

(define *sm-rules* *rules*)
(define *sm-limit* 0)
(define *sm-start* 0)

;; *sm-limit* = 0 이면 끝까지, 아니면 start+limit 까지
(define-function sm-total (limit)
  (let ((n (sm-len *corpus*)) (u (+ *sm-start* limit)))
    (if (or (= limit 0) (> u n)) n u)))

(define-function sm-one (i)
  (let* ((toks (sm-nth *corpus* i)) (n (sm-len toks)))
    (sm-reset toks *lexicon*)
    (let ((nodes (if (= n 0) () (sm-cell "S" 0 n))))
      (if (pair? nodes)
        (let* ((t (car nodes)) (cert (sm-chk-tree t)) (nd (sm-nnode t)))
          (print "D" i "|1|" (sm-sem t) "|" nd "|" (if cert 1 0) "\n")
          (list 1 1 (if cert 1 0) nd))
        (begin (print "D" i "|0|-|0|0\n") (list 0 0 0 0))))))

;; Maru 는 꼬리 호출 최적화가 없어 1000문장을 한 프로세스에서 돌면 재귀 가드에 걸린다.
;; 따라서 구간을 받아 처리하고, 전체 실행은 verify.sh 가 청크로 나눠 호출한다.
(define-function sm-run (i upto acc)
  (if (>= i upto) acc
    (let ((r (sm-one i)))
      (sm-run (+ i 1) upto
        (list (+ (sm-nth acc 0) (sm-nth r 0)) (+ (sm-nth acc 1) (sm-nth r 1))
              (+ (sm-nth acc 2) (sm-nth r 2)) (+ (sm-nth acc 3) (sm-nth r 3)))))))
