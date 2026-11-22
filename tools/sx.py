#!/usr/bin/env python3
"""sx.py — 문자열·주석 인식 S-표현 리더/라이터 + 통합 의존성 정렬 (도구, 0.0052).

0.0051 reorder.py 결함 2건 수정: ① 문자열/주석 안의 괄호를 세지 않는다 ② define 과
define-function 을 한 그래프에서 위상 정렬한다(데이터가 함수를 부르면 뒤로).
"""
import re, sys
from pathlib import Path


def tokenize(text):
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == ';':
            j = text.find('\n', i)
            i = n if j < 0 else j
            continue
        if c == '"':
            j = i + 1
            while j < n:
                if text[j] == '\\':
                    j += 2
                    continue
                if text[j] == '"':
                    j += 1
                    break
                j += 1
            yield ('atom', text[i:j]); i = j; continue
        if c in '()':
            yield (c, c); i += 1; continue
        if c.isspace():
            i += 1; continue
        j = i
        while j < n and not text[j].isspace() and text[j] not in '()";':
            j += 1
        yield ('atom', text[i:j]); i = j


def read_all(text):
    toks = list(tokenize(text))
    pos = 0
    def rd():
        nonlocal pos
        t, v = toks[pos]; pos += 1
        if t == '(':
            items = []
            while toks[pos][0] != ')':
                items.append(rd())
            pos += 1
            return items
        if t == ')':
            raise ValueError('unexpected )')
        return v
    out = []
    while pos < len(toks):
        out.append(rd())
    return out


def write(form):
    if isinstance(form, list):
        out, i = [], 0
        while i < len(form):
            x = form[i]
            if x == "'" and i + 1 < len(form):
                out.append("'" + write(form[i + 1]))
                i += 2
                continue
            out.append(write(x))
            i += 1
        return '(' + ' '.join(out) + ')'
    return form


def forms_of(text):
    return [f for f in read_all(text) if isinstance(f, list) and f]


def head_name(form):
    if len(form) >= 2 and form[0] == 'define-function' and isinstance(form[1], str):
        return 'function', form[1]
    if len(form) >= 2 and form[0] == 'define' and isinstance(form[1], str):
        return 'data', form[1]
    return 'other', None


def deps(form, names):
    toks = set(re.findall(r'[A-Za-z*<>%=+_?!./-][A-Za-z0-9*<>%=+_?!./-]*', write(form)))
    return toks & names


def toposort(forms):
    named = [(head_name(f), f) for f in forms]
    names = {n for (k, n), f in named if n}
    d = {n: deps(f, names) - {n} for (k, n), f in named if n}
    out, placed = [], set()
    pending = [f for (k, n), f in named if n]
    others = [f for (k, n), f in named if not n]
    while pending:
        prog = False
        for f in list(pending):
            k, n = head_name(f)
            if d[n] <= placed:
                out.append(f); placed.add(n); pending.remove(f); prog = True
        if not prog:
            out.extend(pending); break
    return others + out


def check_balance(text):
    depth = 0
    for t, v in tokenize(text):
        if t == '(':
            depth += 1
        elif t == ')':
            depth -= 1
            if depth < 0:
                return False
    return depth == 0


if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'sort':
        p = Path(sys.argv[2]); txt = p.read_text()
        assert check_balance(txt), f'unbalanced input: {p}'
        fs = forms_of(txt)
        out = '\n'.join(write(f) for f in toposort(fs)) + '\n'
        assert check_balance(out), 'unbalanced output'
        p.write_text(out)
        print(f'sorted {p} forms={len(fs)}')
    elif cmd == 'selftest':
        sample = (';; comment with ( parens\n'
                  '(define *a* (list "x(y" 1))\n'
                  '(define-function f (y) (g y))\n'
                  '(define-function g (y) (y))\n')
        fs = forms_of(sample)
        assert [head_name(f)[1] for f in fs] == ['*a*', 'f', 'g'], fs
        order = [head_name(f)[1] for f in toposort(fs)]
        assert order.index('g') < order.index('f'), order
        assert check_balance(sample)
        assert write(fs[0]) == "(define *a* (list \"x(y\" 1))", write(fs[0])
        q = forms_of("(define *b* '(1 2))")[0]
        assert write(q) == "(define *b* '(1 2))", write(q)
        print(f'SX-SELFTEST-PASS forms={len(fs)} order={",".join(order)}')
