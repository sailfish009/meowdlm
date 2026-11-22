#!/usr/bin/env python3
"""문장 도출 포트 차등: Maru 판정 vs meowdlm 파이썬 참조(P2: 미지어 침묵)."""
import re, sys
from pathlib import Path
M = Path('/research/meowdlm_v0.0039')
sys.path.insert(0, str(M / 'src'))
import syntax as S, lexfix as L, lexadd as A, declare as D

sents = S.load_corpus(); TR = sents[:9000]
G = S.Grammar()
lex0, _ = L.prune(S.induce_lexicon(TR), TR, G, floor=1)
fails = A.failures(lex0, TR[:1200], G)
flip = A.single_flip_candidates(lex0, fails[:500], G)
uni = []
for t in fails:
    for w in sorted(set(S.strip_punct(t))):
        for c in A.OPEN:
            if c not in lex0.get(w, set()) and (w, c) not in uni:
                uni.append((w, c))
order = [k for k, _ in flip.most_common() if k in set(uni)]
order += [k for k in uni if k not in {x for x, _ in flip.most_common()}]
LEX = {w: set(cs) for w, cs in lex0.items()}
for (w, c) in order[:200]:
    LEX.setdefault(w, set()).add(c)
LEX = D.strict(LEX)
sample = TR[:1000]


def ref(toks):
    if any(w not in LEX for w in toks):
        return '0'                       # P2: 미지어 침묵(기본값 N 금지)
    return '1' if G.accepts(toks, LEX) else '0'


refv = [ref(S.strip_punct(x)) for x in sample]
out = Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/meow_syn.txt').read_text()
maru = {int(i): v for i, v in re.findall(r'C(\d+)(\d)', out)}
bad = [(i, refv[i], maru.get(i)) for i in range(len(refv)) if maru.get(i) != refv[i]]
print(f"REF 수용 {refv.count('1')}/{len(refv)}   MARU 수용 {sum(1 for v in maru.values() if v=='1')}/{len(maru)}")
print(f"차이 {len(bad)}건" + (f" {bad[:6]}" if bad else " — 일치"))
sys.exit(1 if bad else 0)
