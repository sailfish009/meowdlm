(load "experiments/parity/perf69_common.l")
(define-function p69-acc (toks) (if (fg-accept-gen toks (fg-decl11)) 1 0))
(print "INTERP " (p69-loop 3) "\n")
