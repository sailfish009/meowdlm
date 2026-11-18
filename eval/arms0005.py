#!/usr/bin/env python3
"""v0.0005 4-arm: sum(대조) / priority+LGG off / priority+LGG on / allvals + LGG 계층 기여."""
import json, hashlib, subprocess, sys, os
from pathlib import Path
R = Path(__file__).resolve().parent.parent
BASE = {'FALLBACK': '0', 'COMPOSE': '0', 'ANSWER_ALL': '0', 'LAST_RESORT': '0'}  # 0.0005 이전 구성 고정

CONF = [('sum', {'DECISION': 'sum'}),
        ('priority-LGG', {'DECISION': 'priority', 'LGG': '0'}),
        ('priority+LGG', {'DECISION': 'priority', 'LGG': '1'}),
        ('allvals', {'DECISION': 'allvals'})]
free = [json.loads(l) for l in open(R / 'probe' / 'free_text.jsonl')]
A = {r['input'] for r in free if int(hashlib.sha256(r['input'].encode()).hexdigest(), 16) % 2 == 0}
res = {}
for name, env in CONF:
    subprocess.run([sys.executable, 'eval/run_eval.py'], cwd=R, capture_output=True,
                   env=dict(os.environ, **BASE, **env))
    d = json.load(open(R / 'eval' / 'result.json'))
    ins = [r for r in d['rows'] if r['kind'] == 'ins']
    der = [r for r in ins if r['derived'] is not None]
    res[name] = {'s': d['summary'],
                 'cov': len(der) / len(ins),
                 'prec': (sum(1 for r in der if r['derived'] == r['gold']) / len(der)) if der else 0,
                 'lgg': sum(1 for r in ins if r['reason'] == 'lgg'),
                 'a': sum(1 for r in ins if r['input'] in A and r['derived'] == r['gold']) / max(1, sum(1 for r in ins if r['input'] in A)),
                 'b': sum(1 for r in ins if r['input'] not in A and r['derived'] == r['gold']) / max(1, sum(1 for r in ins if r['input'] not in A)),
                 'correct': {r['input']: (r['derived'] == r['gold']) for r in ins}}
print("| arm | derived_cov | derived_prec | free_act | oos | over_abst | 2턴 | LGG 발화 |")
print("|---|---|---|---|---|---|---|---|")
for name, _ in CONF:
    r, s = res[name], res[name]['s']
    print(f"| {name} | {r['cov']:.3f} | {r['prec']:.3f} | {s['free_act']:.3f} | {s['oos_clarify']:.3f} | "
          f"{s['over_abstain']:.3f} | {s['two_turn']:.3f} | {r['lgg']} |")

def mcnemar(x, y):
    b = sum(1 for k in x if x[k] and not y.get(k)); c = sum(1 for k in x if not x[k] and y.get(k))
    n = b + c
    if n == 0: return b, c, 1.0
    from math import comb
    k = min(b, c)
    return b, c, min(1.0, 2 * sum(comb(n, i) for i in range(k + 1)) / 2 ** n)
print("\n쌍대 비교:")
for a_, b_ in (('sum', 'priority+LGG'), ('priority-LGG', 'priority+LGG'), ('sum', 'allvals')):
    x, y = res[a_]['correct'], res[b_]['correct']
    bb = sum(1 for k in x if x[k] and not y.get(k)); cc = sum(1 for k in x if not x[k] and y.get(k))
    _, _, p = mcnemar(x, y)
    print(f"  {a_:13s} vs {b_:13s} {a_}만={bb:3d} {b_}만={cc:3d} p={p:.4f} "
          f"{'유의' if p < 0.05 else '유의하지 않음'}")
json.dump({k: {kk: vv for kk, vv in v.items() if kk != 'correct'} for k, v in res.items()},
          open(R / 'eval' / 'arms0005.json', 'w'), indent=1)
