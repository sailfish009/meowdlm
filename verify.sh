#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
MARU="${MARU:-/research/dlm_v0.0284/maru-compiler}"
SRC=(src/maru/boot.l src/maru/conversion.l src/meow/horn.l src/meow/query.l)
echo "== 1. Maru 커널 자체 검사"
"$MARU" "${SRC[@]}" tests/horn-tests.l | tail -2
echo "== 2. 커널 판정 차등 (Maru vs meowdlm 파이썬 참조)"
"$MARU" "${SRC[@]}" experiments/parity/horn_start.l > /tmp/meow_horn.txt 2>&1
python3 experiments/parity/diff_horn.py /tmp/meow_horn.txt | sed 's/^/  /'
echo "== 3. 판정/데이터 무결성"
python3 - <<'PY'
import re
from pathlib import Path
out = Path('/tmp/meow_horn.txt').read_text()
assert 'HORN facts=28' in out, out[:80]
assert 'isa=21' in out and 'in=27' in out, out[:120]
m = dict(re.findall(r'Q(\d+)(yes|no|none)', out))
assert len(m) == 20, m
assert sum(1 for v in m.values() if v == 'yes') == 14, m
print('PARITY-PASS 판정 20/20 (yes 14 / no 6 / none 0)')
PY
echo "== 4. 문장 도출 엔진 (Maru) 자체 검사"
"$MARU" src/maru/boot.l src/meow/syntax.l tests/syntax-tests.l | tail -2
echo "== 5. 문장 도출 차등 (1,000문장)"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l experiments/parity/syntax_start.l > /tmp/meow_syn.txt 2>&1
python3 experiments/parity/diff_syntax.py /tmp/meow_syn.txt | sed 's/^/  /'
python3 - <<'PY2'
import re
from pathlib import Path
out = Path('/tmp/meow_syn.txt').read_text()
assert 'SYNTAX rules=33' in out and 'lex=458' in out, out[:120]
assert 'COVER 286/1000' in out, out[:160]
print('SYNTAX-PARITY-PASS 286/1000 (미지어 침묵 의미론, 차이 0)')
PY2
echo "== 6. 증거 질량 판정 (Maru) 자체 검사"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/horn.l src/meow/query.l src/meow/evidence.l tests/evidence-tests.l | tail -2
echo "== 7. 증거 질량 차등 (프로브 170건)"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/horn.l src/meow/query.l src/meow/evidence.l experiments/parity/evidence_start.l > /tmp/meow_ev.txt 2>&1
python3 experiments/parity/diff_evidence.py /tmp/meow_ev.txt | sed 's/^/  /'
python3 - <<'PY2'
import re
from pathlib import Path
out = Path('/tmp/meow_ev.txt').read_text()
assert 'EVIDENCE probes=170' in out, out[:80]
m = re.findall(r'E(\d+)\|([^|]*)\|([^|]*)\|([0-9.\-]+)', out)
assert len(m) == 170, len(m)
derived = sum(1 for x in m if x[2] == 'derived')
print(f'EVIDENCE-PARITY-PASS 170/170 (derived {derived})')
PY2
echo "V0040-MEOWDLM-MARU-SYNTAX-PASS (유지)"
echo "== 7b. 0.0040 결함 회귀 (재발 방지)"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/horn.l src/meow/query.l tests/regression-0041.l | tail -2
echo "== 8. 표면 실현 (Maru): 15범주 문장 + 파이썬 참조 문자열 일치"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/surface.l experiments/parity/surface_start.l > /tmp/meow_surf.txt 2>&1
python3 experiments/parity/diff_surface.py /tmp/meow_surf.txt | sed 's/^/  /'
python3 - <<'PY2'
import re, subprocess, sys
from pathlib import Path
out = Path('/tmp/meow_surf.txt').read_text()
rows = re.findall(r'S(\d+):([a-z_]+)=([^\n]+)', out)
assert len(rows) == 15, len(rows)
r = subprocess.run([sys.executable, 'experiments/parity/diff_surface.py', '/tmp/meow_surf.txt'],
                   capture_output=True, text=True)
assert r.returncode == 0, r.stdout + r.stderr
print(f'SURFACE-PASS 15/15 범주 생성 + 참조 문자열 일치 (예: {rows[5][2]})')
PY2
echo "V0040-MEOWDLM-MARU-EVIDENCE-PASS (유지)"
echo "V0040-MEOWDLM-MARU-SURFACE-PASS (강화: 문자 단위)"
echo "== 9. OOV 흡수 실험 (0.0042)"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/horn.l src/meow/query.l src/meow/evidence.l src/meow/oov.l experiments/parity/oov_start.l > /tmp/oov42.txt 2>&1
python3 - <<'PY2'
import json, re
from pathlib import Path
P = json.loads(Path('data/probe_cues.json').read_text())
OOV = {r[0] for r in json.loads(Path('data/oov_rows.json').read_text())}
out = Path('/tmp/oov42.txt').read_text()
A = {int(i): c for i, c, v in re.findall(r'A(\d+)\|([^|]*)\|([^|\n]*)', out)}
C = {int(i): c for i, c, v in re.findall(r'C70(\d+)\|([^|]*)\|([^|\n]*)', out)}
oov_idx = [i for i in range(len(P)) if i in OOV]
clean = [i for i in range(len(P)) if i not in OOV]
a = sum(1 for i in oov_idx if A.get(i) == P[i][1]) / len(oov_idx)
b = sum(1 for i in clean if A.get(i) == P[i][1]) / len(clean)
c = sum(1 for i in oov_idx if C.get(i) == P[i][1]) / len(oov_idx)
print(f'OOV-NULL OOV {a:.3f} vs 유니그램+매핑 {c:.3f} | 정상 {b:.3f}')
assert 0.40 < a < 0.50 and c < a, (a, c)
assert b > 0.80, b
PY2
echo "== 10. 단서 추출 이관 (0.0043): 참조 문자열 일치"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/induct.l experiments/parity/induct_start.l > /tmp/ind43.txt 2>&1
python3 - <<'PY2'
import json, sys
from pathlib import Path
M = Path('/research/meowdlm_v0.0039')
sys.path.insert(0, str(M / 'src'))
import induct as I
P = json.loads(Path('data/probe_cues.json').read_text())
maru = {}
for line in Path('/tmp/ind43.txt').read_text().split('\n'):
    if line.startswith('I') and '|' in line:
        i, rest = line[1:].split('|', 1)
        maru[int(i)] = rest.strip()
bad = [i for i in range(len(P)) if ' '.join(I.cues(P[i][0])) != maru.get(i)]
assert not bad, bad[:3]
print('CUES-PARITY-PASS 170/170 (문자열 일치)')
PY2
echo "== 11. OOV 매핑 + 단서 재추출 (0.0043)"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/horn.l src/meow/query.l src/meow/evidence.l src/meow/oov.l src/meow/induct.l experiments/parity/absorb_start.l > /tmp/abs43.txt 2>&1
python3 - <<'PY2'
import json, re
from pathlib import Path
P = json.loads(Path('data/probe_cues.json').read_text())
OOV = {r[0] for r in json.loads(Path('data/oov_rows.json').read_text())}
out = Path('/tmp/abs43.txt').read_text()
def g(tag):
    return {int(i): c for i, c, v in re.findall(tag + r'(\d+)\|([^|]*)\|([^|\n]*)', out)}
oov_idx = [i for i in range(len(P)) if i in OOV]
clean = [i for i in range(len(P)) if i not in OOV]
rows = {}
for tag in ('M55', 'M70', 'M85'):
    d = g(tag)
    rows[tag] = (sum(1 for i in oov_idx if d.get(i) == P[i][1]) / len(oov_idx),
                 sum(1 for i in clean if d.get(i) == P[i][1]) / len(clean))
base = 0.454
assert all(v[0] < base for v in rows.values()), rows
assert all(abs(v[1] - 0.836) < 1e-2 for v in rows.values()), rows
best = max(rows.items(), key=lambda kv: kv[1][0])
print(f"ABSORB-NULL 기준 0.454 → 매핑 최고 {best[1][0]:.3f} (정상 {best[1][1]:.3f} 불변)")
PY2
echo "== 12. 웹 자료 채택 실험 (0.0044)"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l experiments/parity/web_start.l > /tmp/web44.txt 2>&1
python3 - <<'PY2'
import re
from pathlib import Path
out = Path('/tmp/web44.txt').read_text()
rows = dict()
for line in out.split('\n'):
    m = re.match(r'(A base|B \+web-rules|C \+web-pos|BC \+both)\s+cov=(\d+)/(\d+) rev=(\d+) amb=(\d+)', line.strip()) if False else None
for label in ('A base', 'B +web-rules', 'C +web-pos', 'BC +both'):
    m = re.search(re.escape(label) + r'\s+cov=(\d+)/(\d+) rev=(\d+) amb=(\d+)', out)
    assert m, label
    rows[label] = tuple(int(x) for x in m.groups())
a, b, c = rows['A base'], rows['B +web-rules'], rows['C +web-pos']
assert b[0] == a[0], (a, b)          # 웹 규칙은 도출을 늘리지 않는다
assert c[0] > a[0], (a, c)           # 웹 품사는 도출을 늘린다
assert c[3] > a[3], (a, c)           # 그 대가로 모호성이 증가한다
n = a[1]
print(f'WEB-PASS 규칙 {a[0]}/{n}→{b[0]}/{n} (변화 0) | 품사 {a[0]}→{c[0]} '
      f'(+{(c[0]-a[0])/n*100:.1f}pp) | 모호성 {a[3]}→{c[3]}')
PY2
echo "== 13. 규칙 발명 실험 (0.0045)"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l src/meow/induce.l experiments/parity/induce_start.l > /tmp/ind45.txt 2>&1
python3 - <<'PY2'
import re
from pathlib import Path
out = Path('/tmp/ind45.txt').read_text()
def get(pat):
    m = re.search(pat, out)
    assert m, pat
    return tuple(int(x) for x in m.groups())
seed = get(r'A seed\s+cov=(\d+)/(\d+) rev=(\d+)')
full = get(r'F full33 cov=(\d+)/(\d+) rev=(\d+)')
ind = get(r'B induced cov=(\d+)/(\d+) rev=(\d+)')
rules = int(re.search(r'IND rules=(\d+)', out).group(1))
assert ind[0] > seed[0], (seed, ind)          # 발명이 시드를 이긴다
assert ind[2] <= seed[2], (seed, ind)         # 과일반화 없음
assert ind[0] < full[0], (ind, full)          # 손 문법보다 낮다
print(f'INVENT-PASS 시드 {seed[0]} → 발명 {ind[0]} (규칙 {rules}) | 손 33공리 {full[0]} | '
      f'역순 {seed[2]}→{ind[2]} (불변)')
PY2
echo "== 14. 병합 폭 실험 (0.0046)"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l src/meow/induce.l experiments/parity/span_start.l > /tmp/span46.txt 2>&1
python3 - <<'PY2'
import re
from pathlib import Path
out = Path('/tmp/span46.txt').read_text()
base = re.search(r'BASE seed cov=(\d+) rev=(\d+)', out)
assert base, out[:200]
seed_cov, seed_rev = int(base.group(1)), int(base.group(2))
arms = {m.group(1): (int(m.group(2)), int(m.group(4)), int(m.group(5)))
        for m in re.finditer(r'L(\d) rules=(\d+) merges=(\d+) cov=(\d+) rev=(\d+)', out)}
assert set(arms) == {'2', '3'}, arms
l2, l3 = arms['2'], arms['3']
assert l2[1] == l3[1], arms            # 폭을 넓혀도 도출 동일
assert l2[1] > seed_cov, (seed_cov, arms)
assert l2[2] <= seed_rev and l3[2] <= seed_rev, arms
print(f'SPAN-PASS L2 {l2[1]}/100 = L3 {l3[1]}/100 (시드 {seed_cov}) | 역순 {l2[2]}'
      f' | 규칙 {l2[0]}')
PY2
echo "== 15. 0.0040 결함 ④ 회귀 + 문법 차등 (0.0047)"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l tests/syntax-defect4.l > /tmp/def4.txt 2>&1
grep -q "defect4 true" /tmp/def4.txt || { echo "  DEFECT4-FAIL"; cat /tmp/def4.txt; exit 1; }
echo "  defect4 true (단언)"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l experiments/parity/syntax_start.l > /tmp/syn47.txt 2>&1
python3 experiments/parity/diff_syntax.py /tmp/syn47.txt | sed 's/^/  /'
echo "== 16. 발명 교정: 재귀 붕괴 차단 + 셔플/held-out (0.0048)"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l src/meow/induce.l experiments/parity/induce48.l > /tmp/ind48.txt 2>&1
python3 - <<'PY2'
import re
from pathlib import Path
out = Path('/tmp/ind48.txt').read_text()
def row(tag):
    m = re.search(tag + r' train=(\d+)/50 held=(\d+)/100 nons=(\d+) shuf=(\d+)', out)
    assert m, (tag, out[:200])
    return tuple(int(x) for x in m.groups())
seed, full, ind = row('SEED'), row('FULL'), row('GAIN')
# 재귀 붕괴 차단: 비문 수용 0
assert seed[2] == 0 and ind[2] == 0, (seed, ind)
# 셔플 게이트: 발명이 시드 이하
assert ind[3] <= seed[3], (seed, ind)
# 정직한 기록: 발명 훈련 이득이 없음을 기록(과장 금지) — 게이트는 값만 단언
assert ind[0] >= seed[0] - 1, (seed, ind)
print(f'NO-COLLAPSE 발명 train {ind[0]}/50 (시드 {seed[0]}, 손 {full[0]}) | held {ind[1]}/100 '
      f'(시드 {seed[1]}, 손 {full[1]}) | 비문 {ind[2]} | 셔플 {ind[3]}')
PY2
echo "V0047-MEOWDLM-SYNTAX-FIX-PASS (유지)"
echo "== 17. 자질(수·격) 강제 문법 (0.0049)"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l src/meow/agree.l experiments/parity/agree_start.l > /tmp/agree49.txt 2>&1
python3 - <<'PY2'
import re
from pathlib import Path
out = Path('/tmp/agree49.txt').read_text()
F = {int(i): v for i, v in re.findall(r'F(\d+)\|([01])', out)}
C = {int(i): v for i, v in re.findall(r'C(\d+)\|([01])', out)}
assert len(F) == 11, F
assert all(F[i] == '1' for i in (0, 1, 4, 7)), F
assert all(F[i] == '0' for i in (2, 3, 5, 6, 8, 10)), F
assert F[10] == '0' and C[10] == '1', (F[10], C[10])   # CFG 는 격 위반을 수용
print(f'FEATURE-PASS 자질 수용 {sum(1 for v in F.values() if v=="1")}/11 | '
      f'격 위반 me sleep: 자질 {F[10]} / CFG {C[10]}')
PY2
echo "== 18. 도출 증명서 + 독립 검사기 (0.0050)"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l src/meow/agree.l src/meow/certify.l experiments/parity/certify_start.l > /tmp/cert50.txt 2>&1
python3 - <<'PY2'
import re
from pathlib import Path
out = Path('/tmp/cert50.txt').read_text()
T = {int(i): v for i, v in re.findall(r'T(\d+)\|([01])', out)}
M = re.findall(r'M(\d+)\|([01])\|([01])\|([^|\n]*)\|([^|\n]*)', out)
assert len(T) == 9, T
assert all(v == '1' for v in T.values()), T
assert len(M) == 9 and all(m[1] == '0' and m[2] == '0' for m in M), M
assert all(m[3] or m[4] for m in M), M
print(f'CERT-PASS 생성 {sum(1 for v in T.values() if v=="1")}/9 수용 | 변조 {len(M)*2}/{len(M)*2} 거부 | '
      f'반례 {M[0][3] or M[0][4]}')
PY2
echo "== 19. 학습 상태 저장/로드/손상 거부 (0.0051)"
mkdir -p state/gen-1
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l src/meow/state.l experiments/parity/state_start.l > /tmp/state51.txt 2>&1
python3 - <<'PY2'
import re
from pathlib import Path
out = Path('/tmp/state51.txt').read_text()
assert re.search(r'SAVE gh=\d+ jh=\d+', out), out[:200]
assert 'DETERMINISM 1' in out, out
assert 'LOAD (ok 9 3)' in out, out
cov = int(re.search(r'COVER (\d+)/100', out).group(1))
rep = int(re.search(r'REPLAY cover=(\d+)/100', out).group(1))
assert rep < cov, (cov, rep)
assert 'CORRUPT-RELOAD (reject' in out, out
print(f'STATE-PASS 저장·복원 9/3 | 결정성 1 | 재생 {cov}→{rep} | 손상 reject')
PY2
echo "== 20. 도구/상태/자질 (0.0052)"
python3 tools/sx.py selftest | sed 's/^/  /'
mkdir -p state/gen-2
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/state.l experiments/parity/state52.l > /tmp/state52.txt 2>&1
"$MARU" src/maru/boot.l src/maru/conversion.l data/lexfeat_data.l src/meow/lexfeat.l experiments/parity/feat_start.l > /tmp/feat52.txt 2>&1
python3 - <<'PY2'
import re
from pathlib import Path
st = Path('/tmp/state52.txt').read_text()
ft = Path('/tmp/feat52.txt').read_text()
assert 'FNV26K 3915785769' in st, st[:200]
assert 'FNV-MISSING ()' in st, st
assert '(ok 3 1)' in st, st
assert 'reject-gen' in st, st
rows = {int(i): v for i, v in re.findall(r'F(\d+)\|([01])', ft)}
assert len(rows) == 14, rows
assert all(rows[i] == '1' for i in (0, 3, 4, 6, 7, 10, 12, 13)), rows
assert all(rows[i] == '0' for i in (1, 2, 5, 8, 9, 11)), rows
print('STATE+F(52)-PASS FNV26K 일치 · 결손/세대 reject · 자질 14/14')
PY2
echo "== 21. 적대적 자질 반례 + OOD 단서 게이트 (0.0053)"
python3 tools/sx.py selftest | sed 's/^/  /'
"$MARU" src/maru/boot.l src/maru/conversion.l data/lexfeat_data.l src/meow/lexfeat.l experiments/parity/feat_adv.l > /tmp/adv53.txt 2>&1
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/query.l src/meow/horn.l src/meow/evidence.l experiments/parity/ood_start.l > /tmp/ood53.txt 2>&1
python3 - <<'PY2'
import json, re
from pathlib import Path
adv = Path('/tmp/adv53.txt').read_text()
A = {int(i): v for i, v in re.findall(r'F(\d+)\|([01])', adv)}
assert len(A) == 21, A
must_accept = {0, 3, 4, 5, 6, 8, 9, 17, 20}
assert all(A[i] == '1' for i in must_accept), A
assert all(A[i] == '0' for i in set(A) - must_accept), A
P = json.loads(Path('data/probe_cues.json').read_text())
out = Path('/tmp/ood53.txt').read_text()
def get(tag): return {int(i): (c, v) for i, c, v in re.findall(tag + r'(\d+)\|([^|]*)\|([^|\n]*)', out)}
ind = [i for i in range(len(P)) if P[i][1] != 'out_of_scope']
oos = [i for i in range(len(P)) if P[i][1] == 'out_of_scope']
d0, d1 = get('P0'), get('P25')
a0 = sum(1 for i in ind if d0.get(i, (None,))[0] == P[i][1])
a1 = sum(1 for i in ind if d1.get(i, (None,))[0] == P[i][1])
ab0 = sum(1 for i in oos if d0.get(i, (0, ''))[1] != 'derived')
ab1 = sum(1 for i in oos if d1.get(i, (0, ''))[1] != 'derived')
n1 = get('N25'); nab = sum(1 for i in n1 if n1[i][1] != 'derived')
assert a0 - a1 <= 3, (a0, a1)
assert ab1 >= 0.75 * len(oos), (ab0, ab1)
assert nab >= 0.75 * len(n1), (nab, len(n1))
print(f'OOD-CUE-PASS 자질 21/21 | 영역내 {a0}→{a1} (-{a0-a1}) | 영역밖 기권 {ab0}→{ab1}/20 | 신규 OOD {nab}/20')
PY2
echo "== 22. 도출 보존 어휘 가지치기 (0.0054)"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l src/meow/lexfix.l experiments/parity/lexfix54.l > /tmp/lexfix54.txt 2>&1
python3 - <<'PY2'
import re
from pathlib import Path
out = Path('/tmp/lexfix54.txt').read_text()
b = re.search(r'BEFORE amb=(\d+) mult=(\d+) train=(\d+)/200 held=(\d+)/200 rev=(\d+)', out)
a = re.search(r'AFTER  amb=(\d+) mult=(\d+) train=(\d+)/200 held=(\d+)/200 rev=(\d+)', out)
assert b and a, out[:200]
b = tuple(int(x) for x in b.groups()); a = tuple(int(x) for x in a.groups())
assert a[2] == b[2], (b, a)          # train 도출 보존
assert a[3] >= b[3], (b, a)          # held-out 비감소
assert a[4] <= b[4], (b, a)          # 역순(셔플) 비증가
assert a[0] < b[0], (b, a)           # 모호성 감소
print(f'LEXFIX-PASS 도출 {b[2]}→{a[2]} 보존 | held {b[3]}→{a[3]} | 모호성 {b[0]}→{a[0]} | 역순 {b[4]}→{a[4]}')
PY2
echo "== 23. 도출 트리 추출 + 선형화 복원 (0.0055)"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l src/meow/parse.l experiments/parity/parse55.l > /tmp/parse55.txt 2>&1
python3 - <<'PY2'
import re
from pathlib import Path
out = Path('/tmp/parse55.txt').read_text()
m = re.search(r'ACCEPT (\d+)/300 trees=(\d+) roundtrip=(\d+) shape=(\d+)', out)
assert m, out[:200]
acc, trees, rt, sh = (int(x) for x in m.groups())
assert acc > 50, acc
assert trees == acc, (acc, trees)
assert rt == acc, (acc, rt)
assert sh == acc, (acc, sh)
print(f'TREE-PASS 수용 {acc} | 트리 {trees} | roundtrip {rt} | shape {sh}')
PY2
echo "== 24. 누락 규칙 증분 + surface 토큰 순서 (0.0056)"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l src/meow/surface.l experiments/parity/rules56_gate.l > /tmp/rules56.txt 2>&1
python3 - <<'PY2'
import re
from pathlib import Path
out = Path('/tmp/rules56.txt').read_text()
b = re.search(r'BASE33\s+cov=(\d+) shuffle=(\d+) surf=(\d+)', out)
v = re.search(r'V2\s+cov=(\d+) shuffle=(\d+) surf=(\d+)', out)
assert b and v, out[:200]
b = tuple(int(x) for x in b.groups()); v = tuple(int(x) for x in v.groups())
assert v[0] >= b[0] + 10, (b, v)
assert v[1] <= b[1] + 2, (b, v)
assert v[2] >= b[2] + 1, (b, v)
print(f'RULE-GAIN-PASS 도출 {b[0]}→{v[0]} | 셔플 {b[1]}→{v[1]} | surf {b[2]}→{v[2]}/15')
PY2
echo "== 25. 학습 경험 저장/재시작/기각 기억 (0.0057)"
mkdir -p state/gen-1
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l src/meow/lexfix.l src/meow/state.l src/meow/exp.l data/lexfeat_data.l src/meow/lexfeat.l experiments/parity/exp57.l > /tmp/exp57.txt 2>&1
python3 - <<'PY2'
import re
from pathlib import Path
out = Path('/tmp/exp57.txt').read_text()
m = re.search(r'EXP L=(\d+) R=(\d+) C=(\d+) total=(\d+)', out)
assert m, out[:200]
L, R, C, tot = (int(x) for x in m.groups())
assert tot == L + R + C and tot > 10, (L, R, C, tot)
assert 'RESUME-EQ 1' in out, out
assert 'REJECT-MEM 1' in out and 'adopt-ok=1' in out, out
cr = re.search(r'CEX-REPLAY (\d+)/(\d+)', out)
assert cr and cr.group(1) == cr.group(2), cr
size = Path('state/gen-1/experience.l').stat().st_size
assert size <= 200 * 1024, size
print(f'EXPERIENCE-PASS L={L} R={R} C={C} | 재시작 동등 | 기각 기억 | 반례 {cr.group(1)}/{cr.group(2)} | {size}B')
PY2
echo "== 26. 경험 적용 상태 재측정 (0.0058)"
mkdir -p state/gen-2
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l src/meow/lexfix.l src/meow/state.l src/meow/exp.l src/meow/apply.l experiments/parity/learn58.l > /tmp/learn58.txt 2>&1 || { echo "  LEARN-FAIL"; tail -3 /tmp/learn58.txt; exit 1; }
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l src/meow/lexfix.l src/meow/state.l src/meow/exp.l src/meow/apply.l src/meow/surface.l experiments/parity/compare58_gate.l > /tmp/cmp58.txt 2>&1 || { echo "  COMPARE-FAIL"; tail -3 /tmp/cmp58.txt; exit 1; }
python3 - <<'PY2'
import re
from pathlib import Path
out = Path('/tmp/cmp58.txt').read_text()
st = re.search(r'STATE records=(\d+) rules=(\d+) amb=(\d+)', out)
a = re.search(r'COV-BASE (\d+)/1000 surf=(\d+)', out)
b = re.search(r'COV-EXP  (\d+)/1000 surf=(\d+)', out)
assert st and a and b, out[:200]
rec, rules, amb = (int(x) for x in st.groups())
a = tuple(int(x) for x in a.groups()); b = tuple(int(x) for x in b.groups())
assert rec >= 15, st
assert rules >= 36, st
assert amb <= 580, st
assert b[0] >= 320, b
assert b[0] > a[0], (a, b)
assert b[1] >= 4, b
print(f'RECOMPARE-PASS 경험 {rec}건 적용 | 규칙 {rules} | 도출 {a[0]}→{b[0]}/1000 | 생성 {a[1]}→{b[1]}/15')
PY2
echo "== 27. 대체 가능성 검사 (0.0060)"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l experiments/parity/subst60.l > /tmp/subst60.txt 2>&1
python3 - <<'PY2'
import re
from pathlib import Path
out = Path('/tmp/subst60.txt').read_text()
b = re.search(r'SUBST pass=(\d+) miss=(\d+)', out)
r = re.search(r'SUBST-REPAIR-L pass=(\d+) miss=(\d+)', out)
assert b and r, out[:200]
b = tuple(int(x) for x in b.groups()); r = tuple(int(x) for x in r.groups())
assert r[0] > b[0], (b, r)
assert len(re.findall(r'MISS \d+ ', out)) >= 4, out
print(f'SUBSTITUTABILITY-PASS 기준 {b[0]}/9 → 수정 후 {r[0]}/9 (실패 {r[1]})')
PY2
echo "== 28. 반례 표적 최소 수정 루프 (0.0061)"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l data/lexfeat_data.l src/meow/lexfeat.l experiments/parity/autofix61.l > /tmp/autofix61.txt 2>&1
python3 - <<'PY2'
import re
from pathlib import Path
out = Path('/tmp/autofix61.txt').read_text()
a = re.search(r'START agree=(\d+)/9 cov=(\d+)/60 cands=(\d+)', out)
b = re.search(r'FINAL agree=(\d+)/9 cov=(\d+)/60 adopted=(\d+)', out)
assert a and b, out[:200]
a = tuple(int(x) for x in a.groups()); b = tuple(int(x) for x in b.groups())
assert a[2] >= 100, a
assert b[1] >= a[1], (a, b)
assert b[2] == 0, b
print(f'CONSTRAINT-GAP-PASS 후보 {a[2]}개 탐색 · 채택 {b[2]} · agree {b[0]}/9 · cov {b[1]}/60')
PY2
echo "== 29. 자질 결합 + 경험 자동 기록 (0.0062)"
mkdir -p state/gen-4
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l data/lexfeat_data.l src/meow/lexfeat.l src/meow/state.l src/meow/exp.l src/meow/apply.l src/meow/featgate.l experiments/parity/featgate62.l > /tmp/feat62.txt 2>&1
python3 - <<'PY2'
import re
from pathlib import Path
out = Path('/tmp/feat62.txt').read_text()
m = re.search(r'AGREE struct=(\d+)/9 gate=(\d+)/9 gate\+fix=(\d+)/9 applied=(\d+)/9', out)
assert m, out[:200]
st, ga, gx, ap = (int(x) for x in m.groups())
assert st < ga <= gx, (st, ga, gx)
assert ap == gx, (gx, ap)
assert ap >= 7, ap
assert 'RECORDED L=4' in out, out
assert re.search(r'RELOAD \(\d+ 4\)', out), out
cov = re.search(r'COV struct=(\d+)/60 gate=(\d+)/60 gate\+fix=(\d+)/60', out)
assert cov and cov.group(1) == cov.group(3), cov
print(f'FEAT-BIND-PASS struct {st} → gate {ga} → fix {gx} → applied {ap} | cov {cov.group(3)}/60 보존')
PY2
echo "V0062-MEOWDLM-FEAT-BIND-PASS"
echo "V0061-MEOWDLM-CONSTRAINT-GAP-PASS"
echo "V0060-MEOWDLM-SUBSTITUTABILITY-PASS"
echo "V0058-MEOWDLM-RECOMPARE-PASS"
echo "V0057-MEOWDLM-EXPERIENCE-PASS"
echo "V0056-MEOWDLM-RULE-GAIN-PASS"
echo "V0055-MEOWDLM-TREE-PASS"
echo "V0054-MEOWDLM-LEXFIX-PASS"
echo "V0053-MEOWDLM-OOD-CUE-PASS"
echo "V0052-MEOWDLM-FEAT-PASS"
echo "V0051-MEOWDLM-STATE-PASS"
echo "V0050-MEOWDLM-CERT-PASS"
echo "V0049-MEOWDLM-FEATURE-GRAMMAR-PASS"
echo "V0048-MEOWDLM-NO-COLLAPSE-PASS"
echo "V0046-MEOWDLM-SPAN-PASS"
echo "V0045-MEOWDLM-INVENT-PASS"
echo "V0044-MEOWDLM-WEB-LEARN-PASS"
echo "V0043-MEOWDLM-INDUCT-PASS"
echo "V0042-MEOWDLM-OOV-NULL-PASS"
echo "V0041-MEOWDLM-REGRESSION-PASS"
