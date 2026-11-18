#!/usr/bin/env python3
"""lgg.py — 변수 추상화와 정렬 채택 (BACKUP 재료 이식).

출처
  /research/BACKUP/dlm_v0.0110/src/dlm/d107-learn.l:22  p107-abstract-atoms
      "structure, not content: each distinct constant in a record becomes a variable"
  /research/BACKUP/dlm_v0.0110/src/dlm/d107-learn.l:30-64  p107-patterns2/3, p107-align-subset
      쌍/삼중 기록에서 패턴 생성, 채택은 점수가 아니라 **정렬 검사**, 지지는 서로 다른 기록 수
  /research/BACKUP/dlm_v0.0017/dlm/deductive.py:626  lgg_atoms
      열 단위 일반화: 같은 항 튜플은 같은 변수를 공유(대응 보존)
  /research/BACKUP/dlm_v0.0031/dlm/galois.py:1-40
      LGG ⊣ 폐쇄 수반: "p가 S를 덮음 ⟺ p가 LGG(S)보다 일반적"

meowdlm에서 기록 = 한 발화의 내용어 열. 패턴 = 같은 길이의 템플릿(상수 + 변수).
"""
import json, itertools
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parent.parent


def abstract(seq):
    """서로 다른 상수를 변수로 바꾼다(d107 p107-abstract-atoms)."""
    m, out = {}, []
    for w in seq:
        if w not in m:
            m[w] = f'V{len(m)}'
        out.append(m[w])
    return tuple(out)


def lgg_pair(a, b):
    """열 단위 LGG: 같은 토큰은 상수, 다른 토큰은 대응 보존 변수(v0.0017 lgg_atoms)."""
    mp, out = {}, []
    for x, y in zip(a, b):
        if x == y:
            out.append(x)
        else:
            k = (x, y)
            if k not in mp:
                mp[k] = f'V{len(mp)}'
            out.append(mp[k])
    return tuple(out)


def covers(pat, seq):
    """패턴이 열을 덮는가(변수는 일관된 치환)."""
    if len(pat) != len(seq):
        return False
    bind = {}
    for p, t in zip(pat, seq):
        if p.startswith('V'):
            if p in bind and bind[p] != t:
                return False
            bind[p] = t
        elif p != t:
            return False
    return True


def more_general(p, q):
    """p가 q보다 일반적인가(q의 상수는 p에서 상수이거나 변수)."""
    if len(p) != len(q):
        return False
    bind = {}
    for a, b in zip(p, q):
        if a.startswith('V'):
            if a in bind and bind[a] != b:
                return False
            bind[a] = b
        elif a != b:
            return False
    return True


def lgg_of(seqs):
    """집합의 LGG(열 단위)."""
    if not seqs:
        return ()
    cur = tuple(seqs[0])
    mp = {}
    for s in seqs[1:]:
        out = []
        for x, y in zip(cur, s):
            if x == y and not x.startswith('V'):
                out.append(x)
            else:
                k = (x, y)
                if k not in mp:
                    mp[k] = f'G{len(mp)}'
                out.append(mp[k])
        cur = tuple(out)
    return cur


def verify_adjunction(pat, support, pool):
    """수반 법칙 검사: pat이 support를 덮음 ⟺ pat ≥ LGG(support).
    반례가 있으면 (False, 반례)를 돌려준다(galois.py의 커널 판정 대응)."""
    if not all(covers(pat, s) for s in support):
        return False, 'pattern-does-not-cover-support'
    g = lgg_of(support)
    if not more_general(pat, g):
        return False, f'not-general-enough:{pat}!>={g}'
    # pool 안에서 pat이 덮는 집합이 곧 support여야 한다(과잉일반화 없음)
    over = [s for s in pool if covers(pat, s) and s not in support]
    if over:
        return False, f'over-general:{over[0]}'
    return True, 'ok'


def induce(records, min_support=2, max_records=4000):
    """records: [(tokens, category, rid)] → 채택 패턴 목록.
    쌍·삼중에서 생성하고, 지지도는 서로 다른 기록 수, 채택은 정렬·수반 검사."""
    by_len = defaultdict(list)
    for i, (t, c, r) in enumerate(records):
        if 2 <= len(t) <= 12:
            by_len[len(t)].append(i)
    cands = set()
    for L, idxs in sorted(by_len.items()):
        idxs = idxs[:max_records]
        for i, j in itertools.combinations(idxs, 2):
            if records[i][1] != records[j][1]:
                continue
            p = lgg_pair(records[i][0], records[j][0])
            if all(not x.startswith('V') for x in p):
                continue
            cands.add((p, records[i][1]))
    pool_by_cat = defaultdict(set)
    all_tok = set()
    for t, c, r in records:
        pool_by_cat[c].add(t)
        all_tok.add(t)
    admitted, rejected = [], []
    for pat, cat in sorted(cands):
        support = [t for t, c, r in records if c == cat and covers(pat, t)]
        sup = len({s for s in support})
        neg = [t for c2, ts in pool_by_cat.items() if c2 != cat for t in ts if covers(pat, t)]
        if sup < min_support:
            rejected.append((pat, cat, 'low-support')); continue
        if neg:
            rejected.append((pat, cat, f'negative-coverage:{len(neg)}')); continue
        ok, why = verify_adjunction(pat, sorted(set(support)), sorted(all_tok))
        if not ok:
            rejected.append((pat, cat, why)); continue
        admitted.append({'pat': list(pat), 'cat': cat, 'support': sup})
    return admitted, rejected


def load_records(paths, toks):
    recs = []
    for p in paths:
        for line in open(p):
            r = json.loads(line)
            recs.append((toks(r['input']), r['category'], r['output']))
    return recs


if __name__ == '__main__':
    import sys
    sys.path.insert(0, str(ROOT / 'src'))
    from induct import tokens, STOP
    tk = lambda t: tuple(w for w in tokens(t) if w not in STOP and len(w) > 1)
    recs = load_records([ROOT / 'data' / 'dialogue_train.jsonl', ROOT / 'data' / 'dialogue_val.jsonl'], tk)
    adm, rej = induce(recs)
    print(f"LGG records={len(recs)} admitted={len(adm)} rejected={len(rej)}")
    from collections import Counter
    print("  reject_reasons", Counter(w.split(':')[0] for _, _, w in rej).most_common())
    print("  by_cat", Counter(a['cat'] for a in adm).most_common())
    json.dump({'admitted': adm, 'rejected': [[list(p), c, w] for p, c, w in rej]},
              open(ROOT / 'data' / 'lgg.json', 'w'), indent=1)
