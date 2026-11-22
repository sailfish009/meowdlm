#!/usr/bin/env python3
"""데이터 변환: meowdlm realize 도식·슬롯 → Maru 데이터(범주당 16도식, 슬롯 top-8)."""
import sys
from pathlib import Path
M = Path('/research/meowdlm_v0.0039')
sys.path.insert(0, str(M / 'src'))
import realize as R
Q = 1 << 16
q = lambda s: '"' + str(s) + '"'
S = R.load()
D = Path('data')
rows, slot_rows, frames_meta = [], [], []
n = 0
for cat in sorted(S['flen']):
    frs = [(fr, sum(S['flen'][cat][fr]) / len(S['flen'][cat][fr])) for fr in S['flen'][cat]]
    frs.sort(key=lambda t: (abs(t[1] - 40.0), t[0]))
    frs = frs[:16]
    for fr, mean in frs:
        rows.append(f'(define *fr{n}* (list {q(cat)} (list {" ".join(q(t) for t in fr)}) {int(round(mean * Q))}))')
        for i in sorted(S['slots'][cat][fr]):
            top = S['slots'][cat][fr][i].most_common(8)
            k = len(slot_rows)
            slot_rows.append(f'(define *sl{k}* (list {n} {i} (list {" ".join(q(w) for w, _ in top)})))')
        frames_meta.append(n)
        n += 1
D.joinpath('surface_frames.l').write_text(
    ';;; auto: tools/export_surface.py — 범주당 16도식\n' + '\n'.join(rows) + '\n'
    + '(define *frames* (list ' + ' '.join(f'*fr{i}*' for i in frames_meta) + '))\n')
D.joinpath('surface_slots.l').write_text(
    ';;; auto: tools/export_surface.py — 슬롯 top-8\n' + '\n'.join(slot_rows) + '\n'
    + '(define *slots* (list ' + ' '.join(f'*sl{i}*' for i in range(len(slot_rows))) + '))\n')
print(f"SURFACE frames={n} slots={len(slot_rows)}")
