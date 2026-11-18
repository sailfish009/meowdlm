#!/usr/bin/env python3
"""두 정책 구성의 패리티 행렬을 함께 산출한다.
C: 항상 답한다(패리티)  B: 증거가 없으면 되묻는다(범위밖 탐지 유지)
"""
import json, subprocess, sys, os
from pathlib import Path
R = Path(__file__).resolve().parent.parent
CFG = {
 'C_always_answer': {'FALLBACK': '1', 'COMPOSE': '1', 'ANSWER_ALL': '1', 'LAST_RESORT': '1'},
 'B_clarify': {'FALLBACK': '1', 'COMPOSE': '1', 'ANSWER_ALL': '0', 'LAST_RESORT': '1'},
}
out = {}
for name, env in CFG.items():
    subprocess.run([sys.executable, 'eval/parity_matrix.py'], cwd=R, capture_output=True,
                   env=dict(os.environ, DECISION='priority', LGG='1', **env))
    out[name] = json.load(open(R / 'eval' / 'parity_matrix.json'))
axes = [v['axis'] for v in out['C_always_answer']['verdicts']]
print("| axis | original | C always-answer | verdict | B clarify | verdict |")
print("|---|---|---|---|---|---|")
for i, ax in enumerate(axes):
    c = out['C_always_answer']['verdicts'][i]; b = out['B_clarify']['verdicts'][i]
    fm = (lambda v: f"{v:,}") if isinstance(c['original'], int) and abs(c['original']) > 100 else (lambda v: f"{v:.3f}")
    print(f"| {ax} | {fm(c['original'])} | {fm(c['meowdlm'])} | {c['verdict']} | {fm(b['meowdlm'])} | {b['verdict']} |")
for name in CFG:
    behind = [v['axis'] for v in out[name]['verdicts'] if v['verdict'] == 'original']
    print(f"\n{name}: behind={behind if behind else 'none'} ({len(out[name]['verdicts'])-len(behind)}/{len(out[name]['verdicts'])} equal-or-better)")
json.dump(out, open(R / 'eval' / 'parity.json', 'w'), indent=1)
