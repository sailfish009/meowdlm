#!/usr/bin/env python3
"""S2 독립 오라클(meowdlm 0.0071 tools/an_oracle.py): 규칙(recency+일치, 1·2인칭 기권)을 파이썬으로 재구현해 Maru 출력과 대조.

입력: state/sem_dump.txt (S1 sem 286), state/an_corpus.txt (Maru 가 낸 대명사 판정)
검사: (a) 판정 일치, (b) 기권 사유 정당성(후보가 있는데 기권한 경우 0).
"""
import re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRON = {'i', 'me', 'you', 'he', 'she', 'him', 'it', 'they', 'them', 'we', 'us'}
PERS = {'i': (1, 0), 'me': (1, 0), 'we': (1, 1), 'us': (1, 1), 'you': (2, 1),
        'he': (3, 0), 'him': (3, 0), 'she': (3, 0), 'it': (3, 0),
        'they': (3, 1), 'them': (3, 1)}


def num_of(w):
    if len(w) >= 4 and w.endswith('s') and not w.endswith('ss'):
        return 1
    return 0


def parse(s):
    toks = re.findall(r'\(|\)|[^\s()]+', s)

    def rd(i):
        i += 1
        out = []
        while toks[i] != ')':
            if toks[i] == '(':
                sub, i = rd(i)
                out.append(sub)
            else:
                out.append(toks[i])
                i += 1
        return out, i + 1
    return rd(0)[0]


def heads(sem):
    """절의 명사 후보(표면 순서: 주어, 목적어)."""
    out = []
    if not (isinstance(sem, list) and sem and sem[0] == 'clause'):
        return out
    subj = sem[1]
    if isinstance(subj, list) and subj and subj[0] == 'np':
        w = subj[-1]
        if w not in PRON:
            out.append(w)
    if len(sem) > 2 and isinstance(sem[2], list) and sem[2] and sem[2][0] == 'vp':
        vp = sem[2]
        if len(vp) > 2 and isinstance(vp[2], list) and vp[2] and vp[2][0] == 'np':
            w = vp[2][-1]
            if w not in PRON:
                out.append(w)
    return out


def resolve(w, prev):
    """prev: 최근 절이 앞. 반환 ('ok', c) | ('no', reason)."""
    person, num = PERS[w]
    if person < 3:
        return ('no', 'deictic')
    win = []
    for sem in prev:                     # 최근 절부터
        for w2 in reversed(heads(sem)):  # 절 안에서도 뒤쪽(목적어)이 가깝다
            win.append(w2)
    for c in win:
        if num_of(c) == num:
            return ('ok', c)
    return ('no', 'no-candidate')


def main():
    dump = [l.strip() for l in (ROOT / 'state/sem_dump.txt').read_text().split('\n')]
    sems = {}
    for l in dump:
        f = l.split('|')
        if len(f) > 2 and f[1] == '1':
            sems[int(f[0][1:])] = f[2]
    got = [l.strip() for l in (ROOT / 'state/an_corpus.txt').read_text().split('\n') if l.strip()]
    order = sorted(sems)
    prev = []
    expect = []
    for i in order:
        sem = sems[i]
        if sem.count('(') > 0 and sem.startswith('('):
            S = parse(sem)
            subj = S[1]
            if isinstance(subj, list) and subj and subj[0] == 'np' and subj[-1] in PRON:
                r = resolve(subj[-1], prev)
                expect.append(f'P{i}|{subj[-1]}|{r[0]}|{r[1]}')
            if len(S) > 2 and isinstance(S[2], list) and S[2][0] == 'vp' and len(S[2]) > 2 \
               and isinstance(S[2][2], list) and S[2][2][0] == 'np' and S[2][2][-1] in PRON:
                w = S[2][2][-1]
                s2 = heads(sem)
                if s2 and num_of(s2[0]) == PERS[w][1] and PERS[w][0] == 3:
                    r = ('ok', s2[0])
                else:
                    r = resolve(w, prev)
                expect.append(f'Q{i}|{w}|{r[0]}|{r[1]}')
            prev = [sem] + prev[:2]
    same = sum(1 for a, b in zip(got, expect) if a == b)
    print(f'oracle lines={len(expect)} maru lines={len(got)} match={same}')
    bad = [(a, b) for a, b in zip(got, expect) if a != b]
    for a, b in bad[:5]:
        print('  DIFF maru=', a, ' oracle=', b)
    unjust = [e for e in expect if e.split('|')[2] == 'no']
    print(f'abstain={len(unjust)} reasons={sorted(set(e.split("|")[3] for e in unjust))}')
    ok = same == len(expect) == len(got)
    print('V-S2-ORACLE-PASS' if ok else 'V-S2-ORACLE-FAIL')
    sys.exit(0 if ok else 4)


if __name__ == '__main__':
    main()
