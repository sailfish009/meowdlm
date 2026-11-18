#!/usr/bin/env python3
"""추상화 진단: 생성된 단서 중 채택된 비율, 프로브 OOV 흡수율, 채택 완화 arm."""
import json, subprocess, sys, os
from pathlib import Path
R = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(R / 'src'))

def run(env_extra):
    subprocess.run([sys.executable, 'src/induct.py'], cwd=R, capture_output=True,
                   env=dict(os.environ, **env_extra))
    st = json.loads((R / 'data' / 'basis.json').read_text())
    def fam(c):
        if c.startswith('c:'): return 'char'
        if ' ? ' in c: return 'gap'
        if c.startswith('s:'): return 'skel'
        return 'lex'
    gen, adm = {}, {}
    # 생성 수는 induct 로그에서, 채택 수는 basis에서
    out = subprocess.run([sys.executable, 'src/induct.py'], cwd=R, capture_output=True,
                         env=dict(os.environ, **env_extra), text=True).stdout
    for line in out.splitlines():
        if line.startswith('INDUCT records'):
            gen['total_cues'] = int(line.split('cues=')[1].split()[0])
    for u in st['units']:
        f = fam(u['cue']); adm[f] = adm.get(f, 0) + 1
    # 프로브 OOV 흡수율
    sys.path.insert(0, str(R / 'src'))
    import importlib, induct
    importlib.reload(induct)
    import infer
    importlib.reload(infer)
    vocab = infer.S['vocab']
    cues = infer.S['by_cue']
    free = [json.loads(l) for l in open(R / 'probe' / 'free_text.jsonl')]
    tot = oov = absd = 0
    for r in free:
        ws = [w for w in induct.tokens(r['input']) if w not in induct.STOP and len(w) > 1]
        for w in ws:
            tot += 1
            if w in vocab:
                continue
            oov += 1
            if any(c in cues for c in induct.cues_from_words([w], induct.CUE_MODE)):
                absd += 1
    return {'gen_total': gen['total_cues'], 'admitted': adm, 'gen': gen,
            'probe_tokens': tot, 'oov_tokens': oov, 'absorbed': absd,
            'absorb_rate': absd / oov if oov else 0.0}

for arm in ('base', 'gap', 'char', 'gap+char'):
    d = run({'CUE_MODE': arm})
    print(f"{arm:9s} cues_generated={d['gen_total']:6d} admitted={d['admitted']} "
          f"probe_oov={d['oov_tokens']} absorbed={d['absorbed']} ({d['absorb_rate']:.1%})")
print("\n채택 완화 arm (P_DEF=0.4, F_BUDGET=2):")
for arm in ('base', 'gap+char'):
    subprocess.run([sys.executable, 'src/induct.py'], cwd=R, capture_output=True,
                   env=dict(os.environ, CUE_MODE=arm, P_DEF='0.4', F_BUDGET='2'))
    o = subprocess.run([sys.executable, 'eval/run_eval.py'], cwd=R, capture_output=True,
                       env=dict(os.environ, CUE_MODE=arm, P_DEF='0.4', F_BUDGET='2'), text=True).stdout
    first = [l for l in o.splitlines() if l.startswith('V0002')][0]
    print(f"  {arm:9s} {first}")
