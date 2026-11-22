#!/usr/bin/env python3
"""데이터 변환: 캐시(pos.json, rules.json) → Maru 데이터(.l)."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
q = lambda s: '"' + str(s) + '"'
pos = json.loads((ROOT / 'cache' / 'pos.json').read_text())
MAP = {'noun': 'N', 'verb': 'V', 'adjective': 'A', 'adverb': 'ADV', 'preposition': 'PREP',
       'determiner': 'DET', 'pronoun': 'PRON', 'conjunction': 'CONJ', 'interjection': 'INTJ',
       'exclamation': 'INTJ', 'auxiliary verb': 'AUX', 'article': 'DET', 'number': 'DET',
       'numeral': 'DET', 'particle': 'ADV'}
rows = []
for w, v in sorted(pos.items()):
    cats = sorted({MAP[p] for p in v.get('pos', []) if p in MAP})
    if cats:
        rows.append((w, cats))
lines = [f'(define *wp{i}* (list {q(w)} (list {" ".join(q(c) for c in cs)})))' for i, (w, cs) in enumerate(rows)]
lines.append('(define *web-pos* (list ' + ' '.join(f'*wp{i}*' for i in range(len(rows))) + '))')
(ROOT / 'data' / 'web_pos.l').write_text(';;; auto: tools/export_web.py — 사전 API 품사\n' + '\n'.join(lines) + '\n')
print(f"WEB-POS words={len(rows)}")
rules = json.loads((ROOT / 'cache' / 'rules.json').read_text())
RMAP = {'N1': 'NG', 'AP': 'A', 'Det': 'DET', 'N': 'N', 'NP': 'NP', 'VP': 'VP', 'PP': 'PP', 'S': 'S'}
out = []
for page, v in rules.items():
    for lhs, rhs in v['rules']:
        if lhs in RMAP and all(r in RMAP for r in rhs):
            out.append((RMAP[lhs], [RMAP[r] for r in rhs], page))
lines = [f'(define *wr{i}* (list {q(l)} (list {" ".join(q(x) for x in r)})))' for i, (l, r, _) in enumerate(out)]
lines.append('(define *web-rules* (list ' + ' '.join(f'*wr{i}*' for i in range(len(out))) + '))')
(ROOT / 'data' / 'web_rules.l').write_text(';;; auto: tools/export_web.py — Wikipedia 구문 규칙\n' + '\n'.join(lines) + '\n')
print(f"WEB-RULES mapped={len(out)}", [(l, r) for l, r, _ in out])
