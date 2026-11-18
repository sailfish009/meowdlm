#!/usr/bin/env python3
"""eval/run_eval.py — meowdlm_v0.0002 프로브 평가 + 이전 버전/원본 대조."""
import json, sys, hashlib
from collections import Counter, defaultdict
from pathlib import Path
R = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(R / 'src'))
import infer as F

free = [json.loads(l) for l in open(R / 'probe' / 'free_text.jsonl')]
two = [json.loads(l) for l in open(R / 'probe' / 'two_turn.jsonl')]
ins = [r for r in free if r['category'] != 'out_of_scope']
oos = [r for r in free if r['category'] == 'out_of_scope']

rows, reasons = [], Counter()
for r in ins + oos:
    c, resp, why, tr = F.respond(r['input'])
    reasons[why] += 1
    rows.append({'input': r['input'], 'gold': r['category'], 'derived': c, 'reason': why,
                 'resp': resp, 'kind': 'oos' if r['category'] == 'out_of_scope' else 'ins',
                 'inpool': (resp in F.S['pool'].get(r['category'], [])) if resp else False,
                 'margin': tr.get('margin'), 'unknown_ratio': tr.get('unknown_ratio'),
                 'n_proof': len(tr.get('proof', [])), 'trace': tr})


def act(rs):
    return sum(1 for r in rs if r['derived'] == r['gold']) / max(1, len(rs))


def clar(rs):
    return sum(1 for r in rs if r['derived'] is None) / max(1, len(rs))


ins_rows = [r for r in rows if r['kind'] == 'ins']
oos_rows = [r for r in rows if r['kind'] == 'oos']
free_act, oos_clarify = act(ins_rows), clar(oos_rows)
over = clar(ins_rows)

# 2턴: 상태는 자기 출력에서만 (gold 폴백 금지)
t2_ok = 0
t2_rows = []
for r in two:
    c1, _, _ = F.derive(r["turn1"])
    st = {'last_category': c1} if c1 else None
    c2, why2, tr2 = F.derive(r['turn2'], st)
    ok = c2 == r['category']
    t2_ok += ok
    t2_rows.append({'turn1': r['turn1'], 'turn2': r['turn2'], 'gold': r['category'],
                    'c1': c1, 'c2': c2, 'ok': ok, 'reason': why2})

# 모순 0: 같은 입력 → 같은 범주
seen, conflicts = {}, 0
for r in rows:
    if r['input'] in seen and seen[r['input']] != r['derived']:
        conflicts += 1
    seen[r['input']] = r['derived']

inpool = sum(1 for r in ins_rows if r['inpool']) / len(ins_rows)
res = {'version': (R / 'VERSION').read_text().strip(), 'n_ins': len(ins_rows), 'n_oos': len(oos_rows),
       'free_act': round(free_act, 4), 'oos_clarify': round(oos_clarify, 4),
       'over_abstain': round(over, 4), 'two_turn': round(t2_ok / len(two), 4),
       'conflicts': conflicts, 'in_gold_pool': round(inpool, 4),
       'abstain_reasons': dict(reasons),
       'units_active': len(F.S['units']), 'm_min': F.M_MIN, 'oov_max': F.OOV_MAX,
       'fail_by_cat': dict(Counter(r['gold'] for r in ins_rows if r['derived'] != r['gold']).most_common(8))}
print(f"V0002 free_act={free_act:.3f} ({sum(1 for r in ins_rows if r['derived']==r['gold'])}/{len(ins_rows)}) "
      f"oos_clarify={oos_clarify:.3f} over_abstain={over:.3f}")
print(f"V0002 two_turn={res['two_turn']:.3f} conflicts={conflicts} in_gold_pool={inpool:.3f} "
      f"units={len(F.S['units'])}")
print(f"V0002 abstain_reasons {dict(reasons)}")
print(f"V0002 fail_by_cat {res['fail_by_cat']}")
json.dump({'summary': res, 'rows': rows, 'two_turn': t2_rows},
          open(R / 'eval' / 'result.json', 'w'), indent=1)

# --- 이전 버전(0.0292) / 원본 MeowLLM 대조
prev = json.load(open('/research/meowdlm/dialogue/probe_result.json'))
orig = json.load(open('/research/meowdlm/baseline/meow_orig.json'))
print("\n| 경로 | 학습 | free_act | oos_clarify | over_abstain | two_turn |")
print("|---|---|---|---|---|---|")
print(f"| 원본 MeowLLM (자기 ckpt) | gradient 2000 step | 0.453 | 0.000 | 0.000 | — |")
print(f"| meowdlm 0.0292 (n-gram) | 공리 771 | {prev['free_act']:.3f} | {prev['oos_clarify']:.3f} | "
      f"{prev['in_over_abstain']:.3f} | {prev['two_turn']:.3f} |")
print(f"| **meowdlm_v0.0002 (DLM 0.0284)** | 단위 {len(F.S['units'])} | {free_act:.3f} | {oos_clarify:.3f} | "
      f"{over:.3f} | {res['two_turn']:.3f} |")
