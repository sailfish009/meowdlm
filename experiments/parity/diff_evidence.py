#!/usr/bin/env python3
"""증거 질량 판정 차등: Maru vs meowdlm 파이썬 참조(MASS_MODE=idf)."""
import json, os, re, sys
import os
from pathlib import Path
M = Path(os.environ.get('MREF', '/research/BACKUP/meowdlm_v0.0039'))
sys.path.insert(0, str(M / 'src'))
import infer as I, induct
P = json.loads(Path('data/probe_cues.json').read_text())
VOCAB = {w for f in ('dialogue_train.jsonl', 'dialogue_val.jsonl')
         for line in open(M / 'data' / f) for k in ('input', 'output')
         for w in induct.tokens(json.loads(line).get(k, ''))}
out = Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/meow_ev.txt').read_text()
maru = {}
for i, cat, verdict, margin in re.findall(r'E(\d+)\|([^|]*)\|([^|]*)\|([0-9.\-]+)', out):
    maru[int(i)] = (cat, verdict, float(margin))
OOV_MAX = I.OOV_MAX
bad, dmax = [], 0.0
for i, (inp, cat, cues) in enumerate(P):
    # 출하 경로는 게이트 없음(e-decide). 게이트는 e-decide-gated 로 분리되어 있고
    # 아직 morph 매핑이 없어 과잉 기권하므로 참조도 게이트 없이 비교한다.
    top, why, tr = I.decide_from_cues(inp, cues)
    ref = (top or '', why, tr.get('margin', 0.0))
    got = maru.get(i)
    if got is None:
        bad.append((i, ref, None)); continue
    if got[0] != ref[0] or got[1] != ref[1]:
        bad.append((i, ref, got)); continue
    d = abs(got[2] - ref[2]); dmax = max(dmax, d)
print(f"참조 판정: {len(P)}건, 불일치 {len(bad)}건, 최대 마진 오차 {dmax:.4f}")
if bad[:4]:
    print(" 예:", bad[:4])
sys.exit(1 if (bad or dmax > 0.01) else 0)
