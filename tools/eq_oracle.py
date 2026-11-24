#!/usr/bin/env python3
"""S3(수 동치) 독립 오라클(meowdlm 0.0071 tools/eq_oracle.py): state/eq_kb.l·s3_q.l 을 읽어 세 팔의 조회를 파이썬으로 재계산한다.

Maru(s3_lib.l)와 코드를 공유하지 않는다. 출력은 Maru 와 같은 형식(EQARM ...)이라
verify.sh 가 줄 단위로 대조할 수 있다.
"""
import re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PL = {'cat': 'cat', 'cats': 'cat', 'dog': 'dog', 'dogs': 'dog', 'box': 'box', 'boxes': 'box'}


def parse_defs(text):
    """(define *name* (list ...)) 들을 name → 리스트로."""
    toks = re.findall(r"\(|\)|'[A-Za-z0-9_-]+|[^\s()]+", text)
    out = {}
    i = 0
    while i < len(toks):
        if toks[i] == '(' and i + 3 < len(toks) and toks[i + 1] == 'define':
            name = toks[i + 2]
            i += 3
            val, i = rd(toks, i)
            val = strip_list(val)
            out[name] = val
        else:
            i += 1
    return out


def strip_list(v):
    """(list ...) 호출형을 값으로 정규화한다."""
    if not isinstance(v, list):
        return v
    v = [strip_list(x) for x in v]
    if v and v[0] == 'list':
        return v[1:]
    return v


def rd(toks, i):
    """toks[i] == '(' 전제."""
    assert toks[i] == '(', (i, toks[i])
    i += 1
    out = []
    while toks[i] != ')':
        if toks[i] == '(':
            sub, i = rd(toks, i)
            out.append(sub)
        elif toks[i].startswith("'"):
            out.append('sym:' + toks[i][1:])
            i += 1
        elif toks[i].startswith('"'):
            out.append(toks[i][1:-1])
            i += 1
        else:
            out.append(toks[i])
            i += 1
    return out, i + 1


def norm(arm, w):
    if arm == 0:
        return w
    if arm == 1:
        return PL.get(w, w)
    return 'thing'


def run(arm, kb, qq):
    correct = hit = wrong = 0
    lines = []
    for idx, (iatom, qatom) in enumerate(qq):
        pred = iatom[0].replace('sym:', '')
        iargs = iatom[1]
        qargs = qatom[1]
        key = (pred, tuple(norm(arm, a) for a in qargs))
        found = None
        for kpred, kargs in kb:
            kp = kpred.replace('sym:', '')
            if (kp, tuple(norm(arm, a) for a in kargs)) == key:
                found = (kp, kargs)
                break
        h = 1 if found else 0
        c = 1 if found == (pred, iargs) else 0
        correct += c
        hit += h
        wrong += 1 if (h and not c) else 0
        lines.append(f'EQQ {idx}|{pred}|{" ".join(iargs)}|{" ".join(qargs)}|{c}|{h}')
    return lines, correct, hit, wrong


def main():
    kb_doc = (ROOT / 'state/eq_kb.l').read_text()
    q_doc = (ROOT / 'state/eq_q.l').read_text()
    kb = parse_defs(kb_doc)['*eq-kb*']
    qq = parse_defs(q_doc)['*eq-qq*']
    print(f'EQKB {len(kb)} queries={len(qq)}')
    res = {}
    for arm in (0, 1, 2):
        lines, c, h, w = run(arm, kb, qq)
        res[arm] = (c, h, w)
        for l in lines:
            print(l)
        print(f'EQARM {arm} correct={c} hit={h} wrong={w} of={len(qq)}')
    ok = res[1][0] / len(qq) >= 0.90 and res[0][0] / len(qq) <= 0.50 and res[2][0] / len(qq) <= 0.60
    print('V0071-EQ-ORACLE-PASS' if ok else 'V0071-EQ-ORACLE-FAIL')
    sys.exit(0 if ok else 5)


if __name__ == '__main__':
    main()