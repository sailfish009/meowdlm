#!/usr/bin/env python3
"""도식 실현 차등: Maru vs 같은 FNV 규칙의 파이썬 참조(문자열 단위 일치 확인)."""
import re, sys
from collections import Counter
from pathlib import Path
M = Path('/research/meowdlm_v0.0039')
sys.path.insert(0, str(M / 'src'))
import realize as R

def fnv(s):
    h = 2166136261
    for ch in s.encode():
        h = ((h ^ ch) * 16777619) % 4294967296
    return h


def sep(a, b):
    return f"{a}|{b}"


S = R.load()


GLOBAL = {}
_n = 0
for _cat in sorted(S['flen']):
    _frs = [(fr, sum(S['flen'][_cat][fr]) / len(S['flen'][_cat][fr])) for fr in S['flen'][_cat]]
    _frs.sort(key=lambda t: (abs(t[1] - 40.0), t[0]))
    for _fr, _m in _frs[:16]:
        GLOBAL[( _cat, _fr)] = _n
        _n += 1


def realize_ref(cat, seed, target=40, tries=8):
    frs = [(fr, sum(S['flen'][cat][fr]) / len(S['flen'][cat][fr])) for fr in S['flen'][cat]]
    frs.sort(key=lambda t: (abs(t[1] - target), t[0]))
    frs = [(GLOBAL[(cat, fr)], fr) for fr, _ in frs[:16]]
    pool = sorted(frs, key=lambda e: abs(sum(S['flen'][cat][e[1]]) / len(S['flen'][cat][e[1]]) - target))
    for attempt in range(tries):
        k = fnv(sep(seed, sep(cat, str(attempt)))) % len(pool)
        _, fr = pool[k]
        words = []
        ok = True
        for i, tok in enumerate(fr):
            if tok != '*':
                words.append(tok)
                continue
            top = [w for w, _ in S['slots'][cat][fr][i].most_common(8)]
            if not top:
                ok = False
                break
            h = fnv(sep(seed, sep(str(i), str(attempt))))
            words.append(top[h % len(top)])
        if not ok or not words:
            continue
        out = ' '.join(words)
        out = out[0].upper() + out[1:] + '.'
        return out
    return None


def maru_parse(path):
    out = Path(path).read_text()
    got = {}
    for k, cat, line in re.findall(r'S(\d+):([a-z_]+)=([^\n]*)', out):
        got[int(k)] = (cat, line.strip())
    return got


if __name__ == '__main__':
    got = maru_parse(sys.argv[1] if len(sys.argv) > 1 else '/tmp/meow_surf.txt')
    bad = []
    for i, (cat, line) in sorted(got.items()):
        ref = realize_ref(cat, "probe")
        if ref != line:
            bad.append((cat, ref, line))
    print(f"참조 비교 {len(got)}건, 불일치 {len(bad)}건")
    for b in bad[:5]:
        print("  ", b)
    sys.exit(1 if bad else 0)
