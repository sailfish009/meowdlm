#!/usr/bin/env python3
"""데이터 변환: cache/pos.json 의 lemma 를 Maru 데이터로 내보낸다 (0.0063)."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
pos = json.loads((ROOT / 'cache' / 'pos.json').read_text())
rows = [(w, v['lemma'][0]) for w, v in sorted(pos.items()) if v.get('lemma')]
q = lambda s: '"' + str(s) + '"'
lines = [f'(define *lm{i}* (list {q(w)} {q(l)}))' for i, (w, l) in enumerate(rows)]
lines.append('(define *lemma* (list ' + ' '.join(f'*lm{i}*' for i in range(len(rows))) + '))')
(ROOT / 'data' / 'lemma.l').write_text(';;; auto: tools/export_lemma.py\n' + '\n'.join(lines) + '\n')
print(f"LEMMA rows={len(rows)}")
