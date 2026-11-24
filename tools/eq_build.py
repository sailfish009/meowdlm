#!/usr/bin/env python3
"""S3 데이터 준비: P-NAME-1 원자 덤프 → KB(단수만) + 질의 40문항(수 변이).

Maru 쪽(s3_lib.l)은 조회·정규화만 한다. KB·질의 생성은 여기서 결정적으로 만든다.
입력: stdin 또는 인자 = `ATOM|<sid>|<j>|<pred>|<args>|<toks>|fg|lf|rt` 줄들
출력: state/eq_kb.l, state/eq_q.l
"""
import re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PL = {'cat': 'cats', 'dog': 'dogs', 'box': 'boxes'}
SING = {v: k for k, v in PL.items()}
MAXQ = 40


def parse(lines):
    atoms = []
    for l in lines:
        if not l.startswith('ATOM|'):
            continue
        f = l.split('|')
        if len(f) < 5:
            continue
        atoms.append((f[3], f[4].split()))
    return atoms


def main():
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    lines = src.read_text().split('\n') if src else sys.stdin.read().split('\n')
    atoms = parse(lines)
    # 중복 제거(순서 유지) + 단수 상수만
    kb, seen = [], set()
    for pred, args in atoms:
        if any(a in SING for a in args):
            continue
        k = (pred, tuple(args))
        if k in seen:
            continue
        seen.add(k)
        kb.append((pred, args))
    queries, qi = [], 0
    for pred, args in kb:
        if len(queries) >= MAXQ:
            break
        idx = [i for i, a in enumerate(args) if a in PL]
        if not idx:
            continue
        i = idx[-1]
        qargs = list(args)
        qargs[i] = PL[qargs[i]]
        queries.append((pred, args, qargs))
    def sexp_atom(pred, args):
        return "(list '%s (list %s))" % (pred, ' '.join('"%s"' % a for a in args))
    kb_lines = '\n'.join('  %s' % sexp_atom(p, a) for p, a in kb)
    q_lines = '\n'.join('  (list %s %s)' % (sexp_atom(p, i), sexp_atom(p, q)) for p, i, q in queries)
    (ROOT / 'state/eq_kb.l').write_text(
        ';;; auto: eq_build.py — KB(단수 상수만, 중복 제거)\n(define *eq-kb* (list\n%s))\n' % kb_lines)
    (ROOT / 'state/eq_q.l').write_text(
        ';;; auto: eq_build.py — 질의 40 (pred, 의도 원자, 수 변이 질의)\n(define *eq-qq* (list\n%s))\n' % q_lines)
    print(f'EQBUILD atoms={len(atoms)} kb={len(kb)} queries={len(queries)}')


if __name__ == '__main__':
    main()