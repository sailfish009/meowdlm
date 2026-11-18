#!/usr/bin/env python3
"""철회 실험: 한 범주의 증거 기록을 철회하면 그 범주만 무너지고 나머지는 유지되는가.

DLM 0.0284의 basis.l(active/inactive, version, history) + axiom-graph.l(의존 도달) 의미를 따른다.
철회 = 해당 범주의 정의 공리를 b_deactivate → 추론에서 제외(의존 단위도 도달 불가).
"""
import json, sys, copy
from pathlib import Path
R = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(R / 'src'))
import basis as B
import infer as F

free = [json.loads(l) for l in open(R / 'probe' / 'free_text.jsonl')]
ins = [r for r in free if r['category'] != 'out_of_scope']
st = json.loads((R / 'data' / 'basis.json').read_text())
basis = [B.b_axiom(u['id'], [u['cue']], [u['id']], u['support'], 1, 'active', ()) for u in st['units']]
for d in st['cat_defs']:
    basis = B.b_add(basis, d['uid'], d['rules'], [], len(d['rules']))
    basis = B.b_activate(basis, d['uid'])


def make(cat_of):
    """cat_of: uid -> cat 매핑(철회 대상 제외). 반환: (defs, by_cue)"""
    dead = {uid for uid, c in cat_of.items() if c is None}
    defs = [(d['cat'], set(d['ext'])) for d in st['cat_defs'] if d['uid'] not in dead]
    by_cue = {u['cue']: u for u in st['units'] if u['id'] not in dead}
    return defs, by_cue


def evaluate(defs, by_cue):
    F._DEFS, F.S['by_cue'] = defs, by_cue
    per = {}
    for r in ins:
        c, _, _ = F.derive(r['input'])
        ok = c == r['category']
        d = per.setdefault(r['category'], [0, 0])
        d[0] += ok
        d[1] += 1
    return {k: v[0] / v[1] for k, v in per.items()}


base_of = {}
for u in st['units']:
    base_of[u['id']] = u['cat']
for d in st['cat_defs']:
    base_of[d['uid']] = d['cat']

defs0, cue0 = make(base_of)
base = evaluate(defs0, cue0)
target = 'dogs'
of = {uid: (None if c == target else c) for uid, c in base_of.items()}
defs1, cue1 = make(of)
after = evaluate(defs1, cue1)
print(f"RETRACT target={target} deactivated_defs={sum(1 for v in of.values() if v is None)}")
print(f"  {target}: before={base.get(target,0):.3f} after={after.get(target,0):.3f}")
others = [k for k in base if k != target]
delta = [abs(after.get(k, 0) - base.get(k, 1)) for k in others]
print(f"  other_categories: n={len(others)} max_delta={max(delta):.3f} mean_delta={sum(delta)/len(delta):.3f}")
print(f"  locality={'PASS' if max(delta) <= 0.11 else 'FAIL'} target_drop={base.get(target,0)-after.get(target,0):.3f}")
json.dump({'target': target, 'before': base.get(target), 'after': after.get(target),
           'max_other_delta': max(delta), 'mean_other_delta': sum(delta) / len(delta),
           'locality': max(delta) <= 0.11}, open(R / 'eval' / 'retract.json', 'w'), indent=1)
