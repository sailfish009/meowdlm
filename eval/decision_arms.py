#!/usr/bin/env python3
"""판정 규칙 3-arm: sum(대조) / priority(Rocq) / allvals(Screamer). 증거는 동일."""
import json, hashlib, subprocess, sys, os
from pathlib import Path
R = Path(__file__).resolve().parent.parent
BASE = {'FALLBACK': '0', 'COMPOSE': '0', 'ANSWER_ALL': '0', 'LAST_RESORT': '0'}  # 0.0005 이전 구성 고정

free = [json.loads(l) for l in open(R / 'probe' / 'free_text.jsonl')]
A = {r['input'] for r in free if int(hashlib.sha256(r['input'].encode()).hexdigest(), 16) % 2 == 0}
ARMS = ['sum', 'priority', 'allvals']
res = {}
for arm in ARMS:
    subprocess.run([sys.executable, 'eval/run_eval.py'], cwd=R, capture_output=True,
                   env=dict(os.environ, **BASE, DECISION=arm))
    d = json.load(open(R / 'eval' / 'result.json'))
    rows = d['rows']
    ins = [r for r in rows if r['kind'] == 'ins']
    oos = [r for r in rows if r['kind'] == 'oos']
    der = [r for r in ins if r['derived'] is not None]
    amb = sum(1 for r in ins if r['reason'] == 'ambiguous')
    res[arm] = {'summary': d['summary'],
                'derived_cov': len(der) / len(ins),
                'derived_prec': (sum(1 for r in der if r['derived'] == r['gold']) / len(der)) if der else 0.0,
                'in_scope_acc': d['summary']['free_act'],
                'ambiguous': amb,
                'a_free': sum(1 for r in ins if r['input'] in A and r['derived'] == r['gold']) / max(1, sum(1 for r in ins if r['input'] in A)),
                'b_free': sum(1 for r in ins if r['input'] not in A and r['derived'] == r['gold']) / max(1, sum(1 for r in ins if r['input'] not in A)),
                'correct': {r['input']: (r['derived'] == r['gold']) for r in ins},
                'derived_set': {r['input']: (r['derived'] is not None) for r in ins}}

print("| arm | 방식 | derived_cov | derived_prec | free_act | oos | over_abst | 2턴 | 모호 |")
print("|---|---|---|---|---|---|---|---|---|")
print("|---|---|---|---|---|---|---|---|---|")
label = {'sum': '가중합+margin',
         'priority': 'Rocq 인스턴스 우선순위',
         'allvals': 'Screamer all-values(모호→되묻기)'}
for arm in ARMS:
    r, s = res[arm], res[arm]['summary']
    print(f"| {arm} | {label[arm]} | {r['derived_cov']:.3f} | {r['derived_prec']:.3f} | "
          f"{s['free_act']:.3f} | {s['oos_clarify']:.3f} | {s['over_abstain']:.3f} | "
          f"{s['two_turn']:.3f} | {r['ambiguous']} |")

def mcnemar(x, y):
    b = c = 0
    for k in x:
        if x[k] and not y.get(k, False): b += 1
        elif not x[k] and y.get(k, False): c += 1
    n = b + c
    if n == 0: return b, c, 1.0
    from math import comb
    k = min(b, c)
    return b, c, min(1.0, 2 * sum(comb(n, i) for i in range(k + 1)) / (2 ** n))

print("\n쌍대 비교 (sum 대비, in-scope 150):")
for arm in ARMS[1:]:
    b, c, p = mcnemar(res['sum']['correct'], res[arm]['correct'])
    print(f"  sum vs {arm:9s} sum만맞음={b:3d} {arm}만맞음={c:3d} p={p:.4f} "
          f"{'유의' if p < 0.05 else '유의하지 않음'}")
pd, pa, _ = mcnemar(res['priority']['derived_set'], res['allvals']['derived_set'])
print(f"\nderived 집합 비교 (priority vs allvals): priority만={pd} allvals만={pa}")
json.dump({a: {k: v for k, v in r.items() if k not in ('correct', 'derived_set')}
           for a, r in res.items()}, open(R / 'eval' / 'decision_arms.json', 'w'), indent=1)
