#!/usr/bin/env python3
"""데이터 변환(도구): meowdlm basis.json → Maru 증거·IDF·어휘 사전(첫 글자 버킷).

0.0041: 선형 탐색 6,816행 → 첫 글자 버킷(27개)으로 바꿔 프로브당 비용을 낮춘다.
"""
import json, math, sys
from pathlib import Path
M = Path('/research/meowdlm_v0.0039')
sys.path.insert(0, str(M / 'src'))
import evidence as EV, induct
Q = 1 << 16
q = lambda s: '"' + str(s) + '"'
D = Path('data')


def bucket_of(s):
    c = s[0] if s else ''
    return ord(c) if c else 0


body = EV.S['body']
rows = []
for cat in sorted(body):
    for cue in sorted(body[cat]):
        r = body[cat][cue]
        rows.append((cue, cat, int(round(r['support'] * Q)), 1 if r['purity'] == 1.0 else 0))
n_cat = max(1, len(body))
df = {}
for c in {r[0] for r in rows}:
    df[c] = sum(1 for cat in body if c in body[cat])
idf = {c: int(round(math.log(1 + n_cat / max(1, df[c])) * Q)) for c in df}
import json
_B = json.loads(Path(M / 'data' / 'basis.json').read_text())
# induct.induce 의 vocab 과 동일하게: train+val 의 **입력과 출력** 토큰 전체
vocab = sorted({w
                for f in ('dialogue_train.jsonl', 'dialogue_val.jsonl')
                for line in open(M / 'data' / f)
                for k in ('input', 'output')
                for w in induct.tokens(json.loads(line).get(k, ''))})

def emit_buckets(name, items, rowfmt):
    buckets = {}
    for it in items:
        buckets.setdefault(bucket_of(it[0] if isinstance(it, tuple) else it), []).append(it)
    lines, names = [], []
    for i, (code, its) in enumerate(sorted(buckets.items())):
        for k, it in enumerate(its):
            lines.append(rowfmt(i, k, it))
        names.append(f'(define *{name}c{i}* (list {code} {" ".join(f"*{name}{i}-{k}*" for k in range(len(its)))}))')
        names.append(None)
    lines.append(f'(define *{name}-buckets* (list ' + ' '.join(
        f'*{name}c{i}*' for i in range(len(buckets))) + '))')
    return lines

lines = []
buckets = {}
for r in rows:
    buckets.setdefault(bucket_of(r[0]), []).append(r)
for i, (code, its) in enumerate(sorted(buckets.items())):
    for k, (c, cat, s, p) in enumerate(its):
        lines.append(f'(define *e{i}-{k}* (list {q(c)} {q(cat)} {s} {p}))')
    lines.append(f'(define *ec{i}* (list {code} ' + ' '.join(f'*e{i}-{k}*' for k in range(len(its))) + '))')
lines.append('(define *ev-buckets* (list ' + ' '.join(f'*ec{i}*' for i in range(len(buckets))) + '))')
D.joinpath('ev.l').write_text(';;; auto: tools/export_evidence.py — 첫 글자 버킷\n' + '\n'.join(lines) + '\n')

lines = []
buckets = {}
for c, v in sorted(idf.items()):
    buckets.setdefault(bucket_of(c), []).append((c, v))
for i, (code, its) in enumerate(sorted(buckets.items())):
    for k, (c, v) in enumerate(its):
        lines.append(f'(define *i{i}-{k}* (list {q(c)} {v}))')
    lines.append(f'(define *ic{i}* (list {code} ' + ' '.join(f'*i{i}-{k}*' for k in range(len(its))) + '))')
lines.append('(define *idf-buckets* (list ' + ' '.join(f'*ic{i}*' for i in range(len(buckets))) + '))')
D.joinpath('idf.l').write_text(';;; auto: tools/export_evidence.py\n' + '\n'.join(lines) + '\n')

lines = []
buckets = {}
for w in vocab:
    buckets.setdefault(bucket_of(w), []).append(w)
for i, (code, its) in enumerate(sorted(buckets.items())):
    lines.append(f'(define *v{i}* (list {code} (list {" ".join(q(w) for w in its)})))')
lines.append('(define *vocab-buckets* (list ' + ' '.join(f'*v{i}*' for i in range(len(buckets))) + '))')
D.joinpath('vocab.l').write_text(';;; auto: tools/export_evidence.py — OOV 게이트용 어휘\n' + '\n'.join(lines) + '\n')
print(f"EVIDENCE rows={len(rows)} buckets={len(buckets)} vocab={len(vocab)}")
