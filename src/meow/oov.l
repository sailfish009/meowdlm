;;; oov.l — 어휘 밖 단어의 문자 n-gram 근접 매핑 (0.0042/0.0043)
;;; 가설: OOV 흡수 벽이 사전의 성질이라면 문자 근접 매핑으로 깨진다.
;;; 자카드 = |A∩B| * 65536 / |A∪B| (Q16 정수)

(define *q16* 65536)

(define-function o-nth (xs n) (if (= n 0) (car xs) (o-nth (cdr xs) (- n 1))))

(define-function o-len-acc (xs a) (if (pair? xs) (o-len-acc (cdr xs) (+ a 1)) a))

(define-function o-len (xs) (o-len-acc xs 0))

(define-function o-member? (x xs) (if (pair? xs) (if (equal x (car xs)) true (o-member? x (cdr xs))) false))

(define-function o-rev-acc (xs acc) (if (pair? xs) (o-rev-acc (cdr xs) (cons (car xs) acc)) acc))

(define-function o-rev (xs) (o-rev-acc xs ()))

(define-function o-merge (as bs) (if (pair? as) (cons (car as) (o-merge (cdr as) bs)) bs))

(define-function o-chars (s i n) (if (< i n) (cons (string-at s i) (o-chars s (+ i 1) n)) ()))

(define-function o-cat (a b) (list->string (o-merge (o-chars a 0 (string-length a)) (o-chars b 0 (string-length b)))))

(define-function o-bucket (code buckets) (if (pair? buckets) (if (= code (o-nth (car buckets) 0)) (car buckets) (o-bucket code (cdr buckets))) ()))

(define-function o-vocab-member? (w its) (if (pair? its) (if (equal w (o-nth (car its) 0)) true (o-vocab-member? w (cdr its))) false))

(define-function o-known? (w buckets) (let ((b (o-bucket (string-at w 0) buckets))) (if (pair? b) (o-vocab-member? w (cdr b)) false)))

(define-function o-sub2 (s i) (list->string (list (string-at s i) (string-at s (+ i 1)))))

(define-function o-grams-acc (w i n acc) (if (< i n) (o-grams-acc w (+ i 1) n (cons (o-sub2 w i) acc)) (o-rev acc)))

(define-function o-grams (w) (cons (o-cat "#" w) (o-grams-acc w 0 (- (string-length w) 1) ())))

(define-function o-inter (as bs acc) (if (pair? as) (o-inter (cdr as) bs (if (o-member? (car as) bs) (+ acc 1) acc)) acc))

(define-function o-jaccard (as bs) (let* ((i (o-inter as bs 0)) (u (- (+ (o-len as) (o-len bs)) i))) (if (= u 0) 0 (/ (* i *q16*) u))))

(define-function o-best-it (gs its best bests)
  (if (pair? its) (let* ((cand (car its)) (sc (o-jaccard gs (o-nth cand 1))))
                     (if (> sc bests) (o-best-it gs (cdr its) (o-nth cand 0) sc)
                         (o-best-it gs (cdr its) best bests)))
    (list best bests)))

(define-function o-best-acc (w buckets rest best bests)
  (if (pair? rest) (let ((r (o-best-it (o-grams w) (cdr (car rest)) best bests)))
                     (o-best-acc w buckets (cdr rest) (o-nth r 0) (o-nth r 1)))
    (list best bests)))

(define-function o-best (w buckets) (o-best-acc w buckets buckets "" 0))

(define-function o-map (w buckets tau)
  (if (o-known? w buckets) (list w *q16*)
    (let* ((r (o-best w buckets)) (sc (o-nth r 1)))
      (if (>= sc tau) (list (o-nth r 0) sc) (list w sc)))))

(define-function o-map-tokens (ts buckets tau acc) (if (pair? ts) (o-map-tokens (cdr ts) buckets tau (cons (o-nth (o-map (car ts) buckets tau) 0) acc)) (o-rev acc)))

(define-function o-join (ts) (if (pair? ts) (if (pair? (cdr ts)) (o-cat (car ts) (o-cat " " (o-join (cdr ts)))) (car ts)) ""))

(define-function o-map-cue (cue buckets tau) (o-join (o-map-tokens (q-tokens cue) buckets tau ())))

(define-function o-map-cues (cues buckets tau acc) (if (pair? cues) (o-map-cues (cdr cues) buckets tau (cons (o-map-cue (car cues) buckets tau) acc)) (o-rev acc)))
