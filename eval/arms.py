#!/usr/bin/env python3
"""3-arm 비교: base / +gap(변수 패턴) / +char(부분일치). dev(A) 선택 → test(B) 보고 + McNemar."""
import json, hashlib, subprocess, sys, os
from pathlib import Path
R = Path(__file__).resolve().parent.parent
BASE = {'FALLBACK': '0', 'COMPOSE': '0', 'ANSWER_ALL': '0', 'LAST_RESORT': '0'}  # 0.0005 이전 구성 고정

free = [json.loads(l) for l in open(R / 'probe' / 'free_text.jsonl')]
A = {r['input'] for r in free if int(hashlib.sha256(r['input'].encode()).hexdigest(), 16) % 2 == 0}
ARMS = ['base', 'gap', 'char', 'gap+char']
res = {}
for arm in ARMS:
    subprocess.run([sys.executable, 'src/induct.py'], cwd=R, capture_output=True,
                   env=dict(os.environ, **BASE, CUE_MODE=arm))
    subprocess.run([sys.executable, 'eval/run_eval.py'], cwd=R, capture_output=True,
                   env=dict(os.environ, **BASE, CUE_MODE=arm))
    d = json.load(open(R / 'eval' / 'result.json'))
    rows = d['rows']
    ins = [r for r in rows if r['kind'] == 'ins']
    oos = [r for r in rows if r['kind'] == 'oos']
    def acc(rs): return sum(1 for r in rs if r['derived'] == r['gold']) / max(1, len(rs))
    res[arm] = {'summary': d['summary'],
                'a_free': acc([r for r in ins if r['input'] in A]),
                'b_free': acc([r for r in ins if r['input'] not in A]),
                'a_oos': sum(1 for r in oos if r['input'] in A and r['derived'] is None) / max(1, sum(1 for r in oos if r['input'] in A)),
                'b_oos': sum(1 for r in oos if r['input'] not in A and r['derived'] is None) / max(1, sum(1 for r in oos if r['input'] not in A)),
                'correct': {r['input']: (r['derived'] == r['gold']) for r in ins},
                'oos_clarified': {r['input']: (r['derived'] is None) for r in oos}}

print("| arm | 단서 수 | 단위 | A_free | B_free | A_oos | B_oos | over_abstain | two_turn |")
print("|---|---|---|---|---|---|---|---|---|")
for arm in ARMS:
    r, s = res[arm], res[arm]['summary']
    print(f"| {arm} | {s.get('cues','-')} | {s['units_active']} | {r['a_free']:.3f} | {r['b_free']:.3f} | "
          f"{r['a_oos']:.3f} | {r['b_oos']:.3f} | {s['over_abstain']:.3f} | {s['two_turn']:.3f} |")

def mcnemar(x, y):
    """base(x) vs arm(y) 쌍대 비교: 불일치 항목만 센다."""
    b = c = 0
    for k in x:
        if x[k] and not y.get(k, False): b += 1
        elif not x[k] and y.get(k, False): c += 1
    n = b + c
    if n == 0: return b, c, 1.0
    # 정확 이항검정(양측)
    from math import comb
    k = min(b, c)
    p = sum(comb(n, i) for i in range(k + 1)) / (2 ** n) * 2
    return b, c, min(1.0, p)

print("\n쌍대 비교 (base 대비, in-scope 150):")
for arm in ARMS[1:]:
    b, c, p = mcnemar(res['base']['correct'], res[arm]['correct'])
    print(f"  base vs {arm:9s} base만맞음={b:3d} {arm}만맞음={c:3d} McNemar exact p={p:.4f} "
          f"{'유의' if p < 0.05 else '유의하지 않음'}")
best = max(ARMS, key=lambda a: res[a]['b_free'] + res[a]['b_oos'])
print(f"\nB(홀드아웃) 최고 arm = {best}  B_free={res[best]['b_free']:.3f} B_oos={res[best]['b_oos']:.3f}")
json.dump({a: {k: v for k, v in r.items() if k not in ('correct', 'oos_clarified')} | {
    'cues': r['summary'].get('cues', 0)} for a, r in res.items()}, open(R / 'eval' / 'arms.json', 'w'), indent=1)
json.dump({'best': best}, open(R / 'eval' / 'arms_best.json', 'w'))
