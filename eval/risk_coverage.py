#!/usr/bin/env python3
"""risk-coverage: 같은 coverage에서 정밀도를 비교(선택적 예측 품질).

각 arm의 신뢰도로 150 in-scope를 정렬하고, 상위 k개만 답한다고 가정해 정밀도를 잰다.
coverage를 고정하면 '얼마나 정확히 아는가'만 비교된다.
"""
import json, subprocess, sys, os
from pathlib import Path
R = Path(__file__).resolve().parent.parent
ARMS = [('sum', {'DECISION': 'sum'}), ('priority', {'DECISION': 'priority', 'LGG': '0'}),
        ('priority+LGG', {'DECISION': 'priority', 'LGG': '1'}), ('allvals', {'DECISION': 'allvals'})]
out = {}
BASE = {'FALLBACK': '0', 'COMPOSE': '0', 'ANSWER_ALL': '0', 'LAST_RESORT': '0'}  # 0.0004 시점 구성 고정
for arm, env in ARMS:
    subprocess.run([sys.executable, 'eval/run_eval.py'], cwd=R, capture_output=True,
                   env=dict(os.environ, **BASE, **env))
    d = json.load(open(R / 'eval' / 'result.json'))
    ins = [r for r in d['rows'] if r['kind'] == 'ins']
    rows = []
    for r in ins:
        conf = (r.get('trace') or {}).get('conf', 0) or 0
        ok = r['derived'] == r['gold']
        rows.append((conf, ok))
    rows.sort(key=lambda x: -x[0])
    out[arm] = {c: sum(1 for _, ok in rows[:int(150 * c)] if ok) / int(150 * c)
                for c in (0.5, 0.6, 0.7, 0.8, 1.0)}
print("| arm | cov 0.50 | 0.60 | 0.70 | 0.80 | 1.00 |")
print("|---|---|---|---|---|---|")
for arm, _ in ARMS:
    o = out[arm]
    print(f"| {arm} | " + " | ".join(f"{o[c]:.3f}" for c in (0.5, 0.6, 0.7, 0.8, 1.0)) + " |")
best = max((a for a, _ in ARMS), key=lambda a: out[a][0.7])
print(f"\n공정 비교(cov 0.70) 최고 arm = {best} precision={out[best][0.7]:.3f}")
COVS = (0.5, 0.6, 0.7, 0.8, 1.0)
for arm in [a for a, _ in ARMS][1:]:
    wins = sum(1 for c in COVS if out[arm][c] >= out['sum'][c])
    p_sign = min(1.0, 2 * sum(__import__('math').comb(len(COVS), i) for i in range(wins, len(COVS) + 1)) / 2 ** len(COVS))
    print(f"부호검정 sum vs {arm:9s} {wins}/{len(COVS)} 지점에서 우세  p={p_sign:.4f}")
json.dump(out, open(R / 'eval' / 'risk_coverage.json', 'w'), indent=1)
