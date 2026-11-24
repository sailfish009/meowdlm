(load "experiments/parity/perf69_common.l")
(define-function p69-acc (toks) (if (fg-accept-idx toks IDX9) 1 0))
(print "IDX " (p69-loop 3) "\n")
