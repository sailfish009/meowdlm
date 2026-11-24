#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
MARU="${MARU:-/research/dlm_v0.0284/maru-compiler}"
export MARU
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
import json, os, sys
from pathlib import Path
M = Path(os.environ.get('MREF', '/research/BACKUP/meowdlm_v0.0039'))
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
echo "== 30. OOV 범주 가설(형태론·표제어) (0.0063)"
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l src/meow/morph.l experiments/parity/oov63.l > /tmp/oov63.txt 2>&1
python3 - <<'PY2'
import re
from pathlib import Path
out = Path('/tmp/oov63.txt').read_text()
a = re.search(r'A base\s+cov=(\d+) shuf=(\d+)', out)
b = re.search(r'B morph\s+cov=(\d+) shuf=(\d+)', out)
e = re.search(r'E one\s+cov=(\d+) shuf=(\d+)', out)
assert a and b and e, out[:300]
a = tuple(int(x) for x in a.groups()); b = tuple(int(x) for x in b.groups()); e = tuple(int(x) for x in e.groups())
assert b[0] >= 380, b
assert b[0] > a[0], (a, b)
assert e[1] >= b[1] - 1, (b, e)   # 예산 축소가 셔플을 줄이지 못함
print(f'OOV-HYPOTHESIS-PASS 도출 {a[0]}→{b[0]} (+{b[0]-a[0]}) | 셔플 {a[1]}→{b[1]} | 예산형 one={e[0]}/{e[1]} (대가 불변)')
PY2
echo "== 31. 단일 선언 → 인식기·생성기 (0.0064, 0.0067/0.0068 드라이버로 재측정)"
"$MARU" src/maru/boot.l src/maru/conversion.l data/lexfeat_data.l src/meow/lexfeat.l \
        src/meow/fgw.l src/meow/fgrammar.l experiments/parity/fgm68.l > /tmp/fgm68.txt 2>&1
python3 - <<'PY6'
import re
from pathlib import Path
out = Path('/tmp/fgm68.txt').read_text()
par = re.search(r'PARITY (\d+)/9', out)
gen = re.search(r'GEN all=(\d+) lf=(\d+) rt=(\d+)', out)
assert par and gen, out[:400]
g = [int(x) for x in gen.groups()]
assert int(par.group(1)) == 9, par.group(0)
assert g[0] >= 15 and g[1] == g[0] == g[2], gen.group(0)
print(f'FGRAMMAR-PASS(재측정) parity {par.group(1)}/9 gen {g[0]} lf {g[1]} rt {g[2]}')
PY6
echo "V0064-MEOWDLM-FGRAMMAR-PASS"

echo "== 32. 비단말 인터페이스 선언 (0.0065, 0.0068 드라이버)"
python3 - <<'PY6'
from pathlib import Path
decl = Path('experiments/parity/fgm68.l').read_text()
assert "'=>" in decl, 'no interface declaration'
assert "'bind" not in decl, 'bind hack still present'
print('IFACE-DECL => 인터페이스 사용 · bind 0건')
PY6
echo "V0065-MEOWDLM-INTERFACE-DECL-PASS"

echo "== 33. 인터페이스 기본값 값 대조 (0.0066, 0.0068 에서 실제 작동 확인)"
python3 - <<'PY6'
import re
from pathlib import Path
out = Path('/tmp/fgm68.txt').read_text()
m = re.search(r'TEETH-S-DEFAULT n=(\d+) accepted=(\d+) 3rd-accepted=(\d+) i-sleep=(true|false)', out)
assert m, out[:400]
assert int(m.group(3)) == 0, f'S-기본값 차분에서 3인칭이 수용됨 {m.group(0)}'
assert m.group(4) == 'true', '1인칭 양성 거부'
print(f'IFACE-CHECK-PASS S-차분 3인칭 {m.group(3)}/{m.group(1)} 수용 · i-sleep {m.group(4)}')
PY6
echo "V0066-MEOWDLM-INTERFACE-CHECK-PASS"

echo "== 34. 지역 치환표 · 알파 치환 · 중복 비단말 (0.0067)"
python3 - <<'PY6'
import re
from pathlib import Path
out = Path('/tmp/fgm68.txt').read_text()
alpha = re.search(r'ALPHA-BAD-AGR (true|false)', out).group(1)
dup1 = re.search(r'DUP-SAME-NUM (true|false)', out).group(1)
dup2 = re.search(r'DUP-DIFF-NUM (true|false)', out).group(1)
assert alpha == 'false', '알파 치환 악성 수용'
assert dup1 == 'true' and dup2 == 'true', '중복 비단말 충돌'
print(f'LOCAL-SCOPE-PASS alpha={alpha} dup-same={dup1} dup-diff={dup2}')
PY6
echo "V0067-MEOWDLM-LOCAL-SCOPE-PASS"

echo "== 35. 증명서 전노드 재유도 · 레이아웃 보존 변조 (0.0068→0.0070)"
"$MARU" src/maru/boot.l src/maru/conversion.l data/lexfeat_data.l src/meow/lexfeat.l \
        src/meow/fgw.l src/meow/fgrammar.l experiments/parity/fgm70.l > /tmp/fgm70.txt 2>&1
python3 - <<'PY7'
import re
from pathlib import Path
out = Path('/tmp/fgm70.txt').read_text()
def one(p, g=1):
    m = re.search(p, out)
    assert m, (p, out[:500])
    return m.group(g)
par, gen = one(r'PARITY (\d+)/9'), re.search(r'GEN all=(\d+) lf=(\d+) rt=(\d+)', out)
cert = re.search(r'CERT trees=(\d+) chk=(\d+) lin-ok=(\d+)', out)
neg = re.search(r'NEGMUT tag=\((\d+) (\d+)\) ifv=\((\d+) (\d+)\) none=\((\d+) (\d+)\) keydel=\((\d+) (\d+)\) sem=\((\d+) (\d+)\)', out)
deep = re.search(r'NEGDEEP leaf=\((\d+) (\d+)\) ungram=\((\d+) (\d+)\)', out)
assert gen and cert and neg and deep, out[:500]
g = [int(x) for x in gen.groups()]; c = [int(x) for x in cert.groups()]
n = [int(x) for x in neg.groups()]; d = [int(x) for x in deep.groups()]
assert int(par) == 9 and g[0] >= 15 and g[1] == g[0] == g[2], gen.group(0)
assert c[0] >= 15 and c[1] == c[0] == c[2], cert.group(0)
# 각 변조 팔: 변조가 실제로 일어났고(mut>0) 수용 0
assert all(n[k] == 0 and n[k+1] == c[0] for k in range(0, len(n), 2)), neg.group(0)
assert all(d[k] == 0 and d[k+1] == c[0] for k in range(0, len(d), 2)), deep.group(0)
print(f'CERT-ALLNODE-PASS cert {c[0]}/{c[1]}/{c[2]} | mut-arms all 0/{c[0]} (5+2 arms)')
PY7
echo "V0068-MEOWDLM-CERT-STRICT-PASS"

echo "== 36. 의미 슬롯 · 대조기 ablation · bind 순서 · fail-closed (0.0069→0.0070)"
python3 - <<'PY7'
import re
from pathlib import Path
out = Path('/tmp/fgm70.txt').read_text()
abl = re.search(r'ABLATION off=(\d+)/(\d+) on=(\d+)', out)
bind = re.search(r'BIND-ORDER u1-sing (\w+) u2-sing (\w+) u1-pl (\w+) u2-pl (\w+)', out)
gu = re.search(r'GUARD-UNREG (\w+)', out)
sem = re.search(r'COPSEM .*? => \(clause \(np [^)]*\) \(vp (\S+) \(comp (\S+)', out)
assert abl and bind and gu and sem, out[:500]
a = [int(x) for x in abl.groups()]
b = bind.groups()
assert a[0] == a[1] and a[2] == 0, f'ablation 판별력 없음 {abl.group(0)}'
assert b[0] == b[1] == 'false' and b[2] == b[3] == 'true', f'bind 순서 의존 {bind.group(0)}'
assert gu.group(1) == 'false', f'미등록 guard 가 통과 {gu.group(0)}'
assert sem.group(1) == 'was' and sem.group(2) != '()', f'COP 보어 의미 소실 {sem.group(0)}'
print(f'SEM-ABLATION-PASS ablation off {a[0]}/{a[1]} on {a[2]} | bind {b} | guard {gu.group(1)} | cop {sem.group(0)[:60]}')
PY7
echo "V0069-MEOWDLM-SEM-PERF-PASS"

echo "== 37. 규칙 인덱스 전문화 처리량 (0.0069, 3회 중앙값·시작 차감·\$MARU 사용) (0.0070)"
python3 - <<'PY7'
import os, subprocess, time, statistics
maru = os.environ.get('MARU', 'maru')
base = ("src/maru/boot.l src/maru/conversion.l data/lexfeat_data.l src/meow/lexfeat.l "
        "src/meow/fgw.l src/meow/fgrammar.l")
def run(f):
    t = []
    out = ''
    for _ in range(3):
        t0 = time.time()
        out = subprocess.run(f'{maru} {base} experiments/parity/perf69b_{f}.l',
                             shell=True, capture_output=True, text=True).stdout.strip()
        t.append(time.time() - t0)
    return out, statistics.median(t)
b_out, b_t = run('base')
i_out, i_t = run('interp')
x_out, x_t = run('idx')
assert int(b_out.split()[-1]) == 0
assert int(i_out.split()[-1]) == int(x_out.split()[-1]) == 800, (i_out, x_out)
i_parse = i_t - b_t
x_parse = x_t - b_t
assert x_parse < i_parse, (i_parse, x_parse)
print(f'PERF-SPEC-PASS parses 800 | base {b_t*1000:.0f}ms interp {i_parse*1000:.0f}ms idx {x_parse*1000:.0f}ms ({i_parse/x_parse:.2f}x)')
PY7
echo "V0070-MEOWDLM-ALLNODE-PASS"

echo "== 38. S1 sem-syntax: 458어휘 33규칙 문법의 트리+sem+증명서 (sem-loop-1 이관)"
mkdir -p state
: > state/sem_dump.txt
: > /tmp/mw_syn071.txt
for st in 0 200 400 600 800; do
  printf '(set *sm-start* %s)\n(set *sm-limit* 200)\n(define *arm-ready* 0)\n' "$st" > /tmp/mw_smarm.l
  "$MARU" src/maru/boot.l src/maru/conversion.l src/meow/sem.l experiments/parity/sem_lib.l \
          /tmp/mw_smarm.l experiments/parity/sem_start.l > /tmp/mw_sm$st.txt 2>&1 || true
  grep '^D' /tmp/mw_sm$st.txt >> state/sem_dump.txt
  printf '(set *syn-start* %s)\n(set *syn-limit* 200)\n(define *arm-ready* 0)\n' "$st" > /tmp/mw_synarm.l
  "$MARU" src/maru/boot.l src/maru/conversion.l src/meow/syntax.l src/meow/sem.l \
          experiments/parity/syn_lib.l /tmp/mw_synarm.l experiments/parity/syn_accepts_start.l \
          > /tmp/mw_syn$st.txt 2>&1 || true
  grep '^C' /tmp/mw_syn$st.txt >> /tmp/mw_syn071.txt
done
python3 - <<'PY8' || { echo SEM458-GATE-FAIL; exit 1; }
import re
D, C = {}, {}
for l in open('state/sem_dump.txt'):
    m = re.match(r'D(\d+)\|([01])\|', l)
    if m: D[int(m[1])] = int(m[2])
for l in open('/tmp/mw_syn071.txt'):
    m = re.match(r'C(\d+)\|([01])$', l.strip())
    if m: C[int(m[1])] = int(m[2])
assert len(D) == 1000 and len(C) == 1000, (len(D), len(C))
d, a = sum(D.values()), sum(C.values())
mism = [k for k in range(1000) if D.get(k) != C.get(k)]
print(f'  recognizer accepted={a}/1000 · parser derived={d}/1000 · parity mismatch={len(mism)}')
print(f'  G-S1a derived >= 250 : {d >= 250} ({d})')
print(f'  G-S1b parity 1000/1000 : {len(mism) == 0}')
assert d >= 250 and d == a and not mism
print('V0071-SEM458-PASS')
PY8
python3 tools/sem_oracle.py | sed 's/^/  /'
python3 - <<'PY8' || { echo SEM-ORACLE-FAIL; exit 1; }
import subprocess
out = subprocess.run(['python3', 'tools/sem_oracle.py'], capture_output=True, text=True).stdout
assert 'DERIVED 286/1000' in out and 'SEM 286/286' in out and 'CERT 286/286' in out, out[:200]
print('V0071-SEM-ORACLE-PASS')
PY8

echo "== 39. S2 대명사 해소: 고정 20케이스 + 상수 제거 + 코퍼스 감사"
printf '(set *an-arm* 0)\n(define *arm-ready* 0)\n' > /tmp/mw_anfix.l
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/sem.l experiments/parity/sem_lib.l \
        src/meow/an.l experiments/parity/an_lib.l /tmp/mw_anfix.l experiments/parity/an_start.l \
        > /tmp/mw_anfix.txt 2>&1 || true
grep -E '^FIXOK' /tmp/mw_anfix.txt | sed 's/^/  /'
printf '(set *nm-ana* 1)\n(define *arm-ready* 0)\n' > /tmp/mw_nmana.l
"$MARU" src/maru/boot.l src/maru/conversion.l data/lexfeat_data.l src/meow/lexfeat.l \
        src/meow/fgw.l src/meow/fgrammar.l experiments/parity/fgdecl70b.l src/meow/an.l src/meow/nm.l \
        /tmp/mw_nmana.l experiments/parity/nm_start.l > /tmp/mw_nmana.txt 2>&1 || true
grep -E '^PRONANA' /tmp/mw_nmana.txt | sed 's/^/  /'
: > state/an_corpus.txt
for st in 0 200 400 600 800; do
  printf '(set *an-arm* 1)\n(set *an-start* %s)\n(set *an-limit* 200)\n(define *arm-ready* 0)\n' "$st" > /tmp/mw_anarm.l
  "$MARU" src/maru/boot.l src/maru/conversion.l src/meow/sem.l experiments/parity/sem_lib.l \
          src/meow/an.l experiments/parity/an_lib.l /tmp/mw_anarm.l experiments/parity/an_start.l \
          > /tmp/mw_anc$st.txt 2>&1 || true
  grep -E '^[PQ][0-9]' /tmp/mw_anc$st.txt >> state/an_corpus.txt
done
python3 tools/an_oracle.py | sed 's/^/  /' || { echo AN-ORACLE-FAIL; exit 1; }
python3 - <<'PY8' || { echo ANA-GATE-FAIL; exit 1; }
import re
fix = open('/tmp/mw_anfix.txt').read()
m = re.search(r'FIXOK (\d+)/(\d+)', fix)
assert m, fix[:200]
fx, ftot = int(m[1]), int(m[2])
ana = open('/tmp/mw_nmana.txt').read()
pm = re.search(r'PRONANA total=(\d+) resolved=(\d+) abstain=(\d+)', ana)
assert pm, ana[:200]
total, res, abst = (int(x) for x in pm.groups())
args = [l.strip() for l in ana.split('\n') if l.startswith('ANARG ')]
PRON = {'i','me','you','he','she','him','it','they','them','we','us'}
left = [a for a in args if a.split('|')[1] in PRON]
corp = [l.strip() for l in open('state/an_corpus.txt') if l.strip()]
print(f'  fixture {fx}/{ftot} | pron args total={total} resolved={res} abstain={abst} | 남은 상수={len(left)}')
print(f'  corpus pron={len(corp)} (해소 {sum(1 for c in corp if c.split("|")[2] == "ok")})')
print(f'  G-S2a 대명사 상수 0 : {len(left) == 0 and total > 0}')
print(f'  G-S2b 고정 20케이스 : {fx == ftot}')
print(f'  G-S2c 전건 분류 : {res + abst == total == len(args)}')
assert fx == ftot and not left and total == len(args) and res + abst == total
print('V0071-ANA-PASS')
PY8

echo "== 40. S3 수 동치 계층: KB 조회 3팔 (off/on/붕괴)"
"$MARU" src/maru/boot.l src/maru/conversion.l data/lexfeat_data.l src/meow/lexfeat.l \
        src/meow/fgw.l src/meow/fgrammar.l experiments/parity/fgdecl70b.l src/meow/an.l src/meow/nm.l \
        experiments/parity/nm_start.l > state/nm_atoms.txt 2>&1 || true
python3 tools/eq_build.py < state/nm_atoms.txt | sed 's/^/  /' || { echo EQBUILD-FAIL; exit 1; }
"$MARU" src/maru/boot.l src/maru/conversion.l src/meow/eq.l experiments/parity/eq_start.l \
        > /tmp/mw_eq.txt 2>&1 || true
grep '^EQARM' /tmp/mw_eq.txt | sed 's/^/  /'
python3 tools/eq_oracle.py > /tmp/mw_eq_oracle.txt 2>&1 || { echo EQ-ORACLE-FAIL; tail -3 /tmp/mw_eq_oracle.txt; exit 1; }
grep '^EQ' /tmp/mw_eq.txt > /tmp/mw_eq_m.txt
grep '^EQ' /tmp/mw_eq_oracle.txt > /tmp/mw_eq_o.txt
diff -q /tmp/mw_eq_m.txt /tmp/mw_eq_o.txt >/dev/null || { echo EQ-PARITY-FAIL; diff /tmp/mw_eq_m.txt /tmp/mw_eq_o.txt | head -5; exit 1; }
python3 - <<'PY8' || { echo EQUIV-GATE-FAIL; exit 1; }
import re
t = open('/tmp/mw_eq_m.txt').read()
arm = {int(m[1]): tuple(int(x) for x in m.groups()[1:])
       for m in re.finditer(r'EQARM (\d) correct=(\d+) hit=(\d+) wrong=(\d+) of=(\d+)', t)}
n = arm[1][3]
r = {k: v[0] / v[3] for k, v in arm.items()}
print(f'  rates: off={r[0]:.2f} on={r[1]:.2f} overmerge={r[2]:.2f} (n={n}) | Maru=oracle')
print(f'  G-S3a on >= 0.90 : {r[1] >= 0.90}')
print(f'  G-S3b off <= 0.50 : {r[0] <= 0.50}')
print(f'  G-S3c 오병합 <= 0.60 : {r[2] <= 0.60}')
assert r[1] >= 0.90 and r[0] <= 0.50 and r[2] <= 0.60
print('V0071-EQUIV-PASS')
PY8

echo "V0071-MEOWDLM-SEMLOOP-PASS"
