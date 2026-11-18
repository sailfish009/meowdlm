#!/usr/bin/env python3
"""임계값을 dev(A)에서만 선택하고 test(B)에서 보고한다."""
import json, hashlib, subprocess, sys, os, itertools
from pathlib import Path
R = Path(__file__).resolve().parent.parent
free = [json.loads(l) for l in open(R / 'probe' / 'free_text.jsonl')]
A = {r['input'] for r in free if int(hashlib.sha256(r['input'].encode()).hexdigest(), 16) % 2 == 0}
rows = []
for m, o in itertools.product((0.05, 0.15, 0.3, 0.45), (0.5, 0.6, 0.8)):
    subprocess.run([sys.executable, 'eval/run_eval.py'], cwd=R, capture_output=True,
                   env=dict(os.environ, M_MIN=str(m), OOV_MAX=str(o)))
    d = json.load(open(R / 'eval' / 'result.json'))
    rs = d['rows']
    def acc(sel, kind):
        sub = [r for r in rs if r['input'] in sel and r['kind'] == kind]
        return sum(1 for r in sub if r['derived'] == r['gold']) / max(1, len(sub)) if kind == 'ins' else \
               sum(1 for r in sub if r['derived'] is None) / max(1, len(sub))
    a_f, a_o = acc(A, 'ins'), acc(A, 'oos')
    b_f, b_o = acc({r['input'] for r in free} - A, 'ins'), acc({r['input'] for r in free} - A, 'oos')
    rows.append({'m': m, 'o': o, 'a_free': a_f, 'a_oos': a_o, 'b_free': b_f, 'b_oos': b_o})
best = max(rows, key=lambda r: (r['a_free'] + r['a_oos'] if r['a_oos'] >= 0.8 else -1, r['a_free']))
print("| M_MIN | OOV_MAX | A_free | A_oos | B_free | B_oos |")
print("|---|---|---|---|---|---|")
for r in rows:
    print(f"| {r['m']} | {r['o']} | {r['a_free']:.3f} | {r['a_oos']:.3f} | {r['b_free']:.3f} | {r['b_oos']:.3f} |")
print(f"\nDEV-BEST M_MIN={best['m']} OOV_MAX={best['o']} -> B_free={best['b_free']:.3f} B_oos={best['b_oos']:.3f}")
json.dump({'rows': rows, 'best': best}, open(R / 'eval' / 'devselect.json', 'w'), indent=1)
