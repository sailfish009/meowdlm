#!/usr/bin/env python3
"""데이터 변환: 어휘 + 3-gram 집합(문자 n-gram) → Maru OOV 매핑용."""
import json, sys
from pathlib import Path
M = Path('/research/meowdlm_v0.0039')
sys.path.insert(0, str(M / 'src'))
import induct as I
from collections import Counter
q = lambda s: '"' + s + '"'
cnt = Counter()
for f in ('dialogue_train.jsonl', 'dialogue_val.jsonl'):
    for line in open(M / 'data' / f):
        r = json.loads(line)
        for k in ('input', 'output'):
            cnt.update(I.tokens(r.get(k, '')))
words = sorted(cnt)


def grams(w):
    return sorted({'#' + w} | {w[i:i + 2] for i in range(len(w) - 1)} if len(w) > 1 else {'#' + w})


buckets = {}
for w in words:
    buckets.setdefault(ord(w[0]), []).append((w, grams(w)))
lines = []
for i, (code, its) in enumerate(sorted(buckets.items())):
    for k, (w, gs) in enumerate(its):
        lines.append(f'(define *ow{i}-{k}* (list {q(w)} (list {" ".join(q(g) for g in gs)})))')
    lines.append(f'(define *oc{i}* (list {code} ' + ' '.join(f'*ow{i}-{k}*' for k in range(len(its))) + '))')
lines.append('(define *oov-vocab* (list ' + ' '.join(f'*oc{i}*' for i in range(len(buckets))) + '))')
Path('data/oov_vocab.l').write_text(';;; auto: tools/export_oov.py — 어휘 554 + 2-gram/접두 집합\n' + '\n'.join(lines) + '\n')
print(f"OOV-VOCAB words={len(words)} buckets={len(buckets)}")
