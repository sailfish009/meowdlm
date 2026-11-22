#!/usr/bin/env python3
"""커널 포트 차등: Maru 판정 vs meowdlm(파이썬) 판정."""
import re, sys
from pathlib import Path
M = Path('/research/meowdlm_v0.0039')
sys.path.insert(0, str(M / 'src'))
import kernel as K, syntax as S

Q = ["is z1 in z4", "z1 in z4?", "is z1 in z4?", "Is Z1 In Z4", "tell me if z1 is in z4",
     "is z4 in z1", "is z4 in z1?", "is miso a c13", "miso is a c13", "is miso a c13?",
     "is miso a plant", "is miso a plant?", "is z1 in z7", "is z7 in z1",
     "is miso a c9", "is miso a c5", "is miso an animal", "is miso a living thing",
     "is kuro a cat", "is the shelf in the street"]
K._load()
S.load()
closures = set(K._STATE['inn']) | set(K._STATE['isa']) | set(K._STATE.get('cau', {}))


def ref(q):
    dv = K.decide(q)
    if dv:
        return 'yes' if dv[0] == 'yes' else 'no'
    r = S.read_relation(q)
    if not r:
        return 'none'
    a, b = r[1], r[2]
    for name in ('inn', 'isa', 'cau'):
        if (a, b) in K._STATE.get(name, {}):
            return 'yes'
    syms = {x for x, _ in K._STATE['isa']} | {c for _, c in K._STATE['isa']} | \
           {x for x, _ in K._STATE['inn']} | {c for _, c in K._STATE['inn']} | \
           {c for c, _ in K._STATE['sub']} | {p for _, p in K._STATE['sub']}
    if a not in syms or b not in syms | set(K._CLASSES):
        return 'none'
    return 'no'


out = Path(sys.argv[1]).read_text()
m = dict(re.findall(r'Q(\d+)(yes|no|none)', out))
bad = []
for i, q in enumerate(Q):
    r = ref(q)
    g = m.get(str(i))
    if g != r:
        bad.append((i, q, r, g))
print(f"REF  yes/no/none = " + '/'.join(str(sum(1 for i in range(len(Q)) if ref(Q[i]) == k))
                                        for k in ('yes', 'no', 'none')))
print(f"MARU yes/no/none = " + '/'.join(str(sum(1 for v in m.values() if v == k)) for k in ('yes', 'no', 'none')))
print(f"차이 {len(bad)}건" + (f" {bad}" if bad else " — 일치"))
sys.exit(1 if bad else 0)
