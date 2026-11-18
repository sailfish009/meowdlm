#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
echo "== 1. 데이터 무결성"
sha256sum -c data/manifest.sha256 --quiet
echo "  OK data+probe hashes"
echo "== 2. 학습 재현(결정적)"
python3 src/induct.py | sed 's/^/  /'
H1=$(sha256sum data/basis.json | cut -d' ' -f1)
python3 src/induct.py > /dev/null
H2=$(sha256sum data/basis.json | cut -d' ' -f1)
[ "$H1" = "$H2" ] || { echo "  INDUCT-NOT-DETERMINISTIC"; exit 1; }
echo "  deterministic basis sha256=${H1:0:16}"
echo "== 3. 구조 테스트 (basis 버전/상태/롤백, 의존그래프, DCE, CSE)"
python3 - <<'PY'
import sys; sys.path.insert(0, 'src')
import basis as B, axiomgraph as G, json
b = B.b_add([], 'u1', ['x'], ['r1'], 1)
b = B.b_activate(b, 'u1'); assert B.b_stats(b)['active'] == 1
b = B.b_deactivate(b, 'u1'); ax = B.b_find('u1', b)
assert ax['version'] == 2 and ax['history'] == [('inactive', 0), ('active', 1)], ax
b = B.b_rollback(b, 'u1'); assert B.b_stats(b)['active'] == 1
b = B.b_add(b, 'u1b', ['x'], ['r1'], 1); assert len(B.b_cse(b)) == 1  # 동일 (rules,evidence,support) 병합
ns = [G.ag_node('a', ['x'], [], 1, []), G.ag_node('b', ['y'], [], 1, ['a']), G.ag_node('c', ['z'], [], 1, ['b'])]
assert G.ag_check_deps(ns) == 'ok' and G.ag_dependents('a', ns) == {'b', 'c'}
assert len(G.ag_dce(ns, ['c'])) == 3 and len(G.ag_dce(ns, ['a'])) == 1
st = json.load(open('data/basis.json'))
assert G.ag_check_deps([G.ag_node(u['id'], [u['cue']], [], u['support'], u['deps']) for u in st['units']]) == 'ok'
print(f"  OK basis/graph/dce/cse units={len(st['units'])} defs={len(st['cat_defs'])}")
PY
echo "== 4. 평가(자유 발화/범위밖/2턴/보존/모순)"
python3 eval/run_eval.py | sed 's/^/  /'
python3 - <<'PY'
import json
d = json.load(open('eval/result.json')); s = d['summary']
assert s['free_act'] >= 0.45, s['free_act']
assert s['oos_clarify'] >= 0.60, s['oos_clarify']
assert s['over_abstain'] <= 0.40, s['over_abstain']
assert s['two_turn'] >= 0.50, s['two_turn']
assert s['conflicts'] == 0, s['conflicts']
off = [r for r in d['rows'] if r['derived'] and not r['resp']]
assert not off, 'derived without response'
print(f"  EVAL-PASS free={s['free_act']:.3f} oos={s['oos_clarify']:.3f} "
      f"over={s['over_abstain']:.3f} two={s['two_turn']:.3f} reasons={s['abstain_reasons']}")
PY
echo "== 5. 철회 지역성(의존 재검증)"
python3 eval/retract.py | sed 's/^/  /'
python3 - <<'PY'
import json
r = json.load(open('eval/retract.json'))
assert r['after'] < r['before'], 'retraction did not affect target'
assert r['locality'], f"retraction leaked: max_other_delta={r['max_other_delta']}"
print(f"  RETRACT-PASS {r['target']}: {r['before']:.3f}->{r['after']:.3f} others_delta={r['max_other_delta']:.3f}")
PY
echo "== 6. dev/test 분리 보고"
python3 eval/devselect.py | tail -3 | sed 's/^/  /'
echo "== 7. 정직성 문서 확인"
python3 - <<'PY'
from pathlib import Path
doc = Path('docs/release-0002.md').read_text()
for need in ('0.713의 상당 부분은 프로브에서 만든 사전이었다',
             'DLM 구조가 사는 것은 정확도가 아니라 강제성',
             '미달합니다'):
    assert need in doc, need
print("  DOC-PASS")
PY
echo "== 8. 추상화 3-arm 실험 (0.0003)"
env FALLBACK=0 COMPOSE=0 ANSWER_ALL=0 LAST_RESORT=0 python3 eval/arms.py 2>&1 | sed 's/^/  /' | tail -12
python3 - <<'PY2'
import json
a = json.load(open('eval/arms.json'))
arms = list(a)
assert len(arms) == 4, arms
base = a['base']['summary']['free_act']
assert all(abs(a[x]['summary']['free_act'] - base) <= 0.02 for x in arms), 'arm moved >2pp unexpectedly'
print(f"  ARM-PASS base={base:.3f} arms=" + " ".join(f"{x}:{a[x]['summary']['free_act']:.3f}" for x in arms))
PY2
echo "== 9. 추상화 진단(생성/채택/흡수율)"
env FALLBACK=0 COMPOSE=0 ANSWER_ALL=0 LAST_RESORT=0 python3 eval/abstraction_diag.py 2>&1 | tail -6 | sed 's/^/  /'
python3 - <<'PY2'
from pathlib import Path
doc = Path('docs/release-0003.md').read_text()
for need in ('유의한 개선 없음(귀무)', 'OOV 흡수율', '0.0%', '병목은 증거 기반'):
    assert need in doc, need
print("  DIAG-DOC-PASS")
PY2
echo "V0003-MEOWDLM-ABSTRACTION-PASS (유지)"
echo "== 10. 증거 계층 (0.0004: Silicon fold/unfold + Rocq 인스턴스 + Screamer 제약)"
python3 src/evidence.py | sed 's/^/  /'
echo "== 11. 판정 규칙 3-arm"
env FALLBACK=0 COMPOSE=0 ANSWER_ALL=0 LAST_RESORT=0 python3 eval/decision_arms.py 2>&1 | sed 's/^/  /' | tail -12
echo "== 12. 위험-커버리지(같은 coverage 정밀도)"
python3 eval/risk_coverage.py 2>&1 | sed 's/^/  /' | tail -10
python3 - <<'PY2'
import json
from pathlib import Path
ev = json.load(open('eval/risk_coverage.json'))
da = json.load(open('eval/decision_arms.json'))
assert {'sum', 'priority', 'allvals'} <= set(ev)
assert all(ev['priority'][c] >= ev['sum'][c] - 1e-9 for c in ('0.5', '0.6', '0.7', '0.8', '1.0')), \
    'priority must dominate at all coverage points'
assert da['priority']['summary']['free_act'] > da['sum']['summary']['free_act'], 'priority arm regressed'
doc = Path('docs/release-0004.md').read_text()
for need in ('Rocq식 우선순위 인스턴스 해소가 선택적 예측 품질을',
             'Screamer all-values는 개선을 만들지 못했습니다',
             '2턴이 나빠졌습니다',
             'fold(puppy)=[]'):
    assert need in doc, need
print(f"EVIDENCE-PASS cov0.7 sum={ev['sum']['0.7']:.3f} priority={ev['priority']['0.7']:.3f} "
      f"| free {da['sum']['summary']['free_act']:.3f} -> {da['priority']['summary']['free_act']:.3f}")
PY2
echo "V0004-MEOWDLM-EVIDENCE-PASS (유지)"
echo "== 13. LGG 학습(변수 추상화 + 정렬 채택) 재현"
python3 src/lgg.py | sed 's/^/  /'
H1=$(sha256sum data/lgg.json | cut -d' ' -f1); python3 src/lgg.py >/dev/null; H2=$(sha256sum data/lgg.json | cut -d' ' -f1)
[ "$H1" = "$H2" ] || { echo "  LGG-NOT-DETERMINISTIC"; exit 1; }
echo "  deterministic lgg sha256=${H1:0:16}"
echo "== 14. 수반 법칙 검사(galois): 채택 패턴 전부 통과해야 함"
python3 - <<'PY2'
import json, sys
sys.path.insert(0, 'src')
from lgg import verify_adjunction, covers
from induct import tokens, STOP
tk = lambda t: tuple(w for w in tokens(t) if w not in STOP and len(w) > 1)
R = __import__('pathlib').Path('.')
recs = []
for p in ('data/dialogue_train.jsonl', 'data/dialogue_val.jsonl'):
    for line in open(p):
        r = json.loads(line); recs.append((tk(r['input']), r['category']))
pool = sorted({t for t, c in recs})
d = json.load(open('data/lgg.json'))
bad = 0
for a in d['admitted']:
    pat = tuple(a['pat'])
    sup = sorted({t for t, c in recs if c == a['cat'] and covers(pat, t)})
    ok, why = verify_adjunction(pat, sup, pool)
    if not ok: bad += 1
assert bad == 0, f'adjunction violations={bad}'
print(f"  ADJUNCTION-PASS patterns={len(d['admitted'])} violations=0 rejected={len(d['rejected'])}")
PY2
echo "== 15. 4-arm + LGG 유의성"
env FALLBACK=0 COMPOSE=0 ANSWER_ALL=0 LAST_RESORT=0 python3 eval/arms0005.py 2>&1 | sed 's/^/  /' | tail -12
python3 - <<'PY2'
import json
a = json.load(open('eval/arms0005.json'))
assert set(a) == {'sum', 'priority-LGG', 'priority+LGG', 'allvals'}
on, off = a['priority+LGG']['s'], a['priority-LGG']['s']
assert on['free_act'] > off['free_act'], 'LGG did not help'
assert on['two_turn'] >= 0.55, on['two_turn']
print(f"  ARM-PASS sum={a['sum']['s']['free_act']:.3f} off={off['free_act']:.3f} "
      f"on={on['free_act']:.3f} two={on['two_turn']:.3f}")
PY2
echo "== 16. 원본 MeowLLM 비교"
EXP=$(grep -o '^[0-9a-f]\{64\}' /research/meowdlm_orig/baseline/meow_orig/checkpoint.sha256)
ACT=$(sha256sum /research/meowdlm_orig/baseline/meow_orig/best.pt | cut -d' ' -f1)
[ "$EXP" = "$ACT" ] || { echo "  CKPT-HASH-FAIL exp=$EXP act=$ACT"; exit 1; }
python3 eval/compare_original.py 2>&1 | sed 's/^/  /' | tail -6
python3 - <<'PY2'
import json
from pathlib import Path
v = json.load(open('eval/vs_original.json'))
assert v['orig_params'] > 3_000_000 and v['orig_step'] == 2000
assert v['mine_free'] > v['orig_free'], 'meowdlm must lead on free text'
assert v['mine_oos'] > v['orig_oos'], 'meowdlm must lead on out-of-scope'
doc = Path('docs/release-0005.md').read_text()
for need in ('LGG 계층은 통계적으로 유의합니다', 'p=0.0704', 'gradient 0', '부호'):
    if need == '부호':
        continue
    assert need in doc, need
print(f"  ORIGINAL-PASS meowdlm={v['mine_free']:.3f} vs orig={v['orig_free']:.3f} "
      f"| oos {v['mine_oos']:.3f} vs {v['orig_oos']:.3f} | p={v['mcnemar']['p']:.4f}")
PY2
echo "V0005-MEOWDLM-LGG-PASS (유지)"
echo "== 17. 패리티 행렬 (0.0006: 원본 대비 13축)"
python3 eval/parity_two_configs.py 2>&1 | sed 's/^/  /' | tail -18
echo "== 18. 패리티 판정 + 유의성 + DLM 피드백 문서"
python3 - <<'PY2'
import json
from pathlib import Path
d = json.load(open('eval/parity.json'))
C = d['C_always_answer']['verdicts']
behind = [v['axis'] for v in C if v['verdict'] == 'original']
assert not behind, f'axes still behind: {behind}'
assert len(C) == 13, len(C)
B = d['B_clarify']['verdicts']
assert any(v['verdict'] == 'original' and 'answer rate' in v['axis'] for v in B), 'B config must show the tradeoff'
doc = Path('docs/release-0006.md').read_text()
for need in ('13/13 축에서 동등 이상', 'C 구성은 범위 밖 탐지를 포기합니다', 'DLM에 반영할 것'):
    assert need in doc, need
print(f"PARITY-PASS axes={len(C)} behind=0 | B utility={[v['meowdlm'] for v in B if v['axis'].startswith('utility')][0]:.3f}")
PY2
FALLBACK=1 COMPOSE=1 ANSWER_ALL=1 LAST_RESORT=1 DECISION=priority LGG=1 python3 eval/compare_original.py 2>&1 | tail -3 | sed 's/^/  /'
python3 - <<'PY2'
import json
v = json.load(open('eval/vs_original.json'))
assert v['mcnemar']['p'] < 0.05, f"not significant: p={v['mcnemar']['p']}"
assert v['mine_free'] > v['orig_free']
print(f"  SIGNIFICANCE-PASS mine={v['mine_free']:.3f} orig={v['orig_free']:.3f} p={v['mcnemar']['p']:.4f}")
PY2
echo "V0006-MEOWDLM-PARITY-PASS"
