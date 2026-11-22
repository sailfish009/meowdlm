#!/usr/bin/env python3
"""Maru 정의 순서 정리기 v2: 모든 최상위 S-식을 괄호 균형으로 파싱한다.

v1은 `define-function` 만 묶고 다중행 `(define ...)` 은 첫 줄만 다뤄 파일을 손상시켰다
(0.0040 결함 ①). v2는 **모든** 최상위 식을 괄호 균형 단위로 모은 뒤,

  데이터 식   (define *name* ...)  → 앞으로, 원래 순서 유지
  함수 식     (define-function ...) → 참조 의존성 위상 순서
  그 외        (load ...) / 주석    → 원래 위치 유지

순으로 재배치한다. 코드 배치 도구이며 모델 로직이 아니다.
"""
import re, sys
from pathlib import Path

TOK = re.compile(r'[A-Za-z*<>%=+_?!./-][A-Za-z0-9*<>%=+_?!./-]*')
OPEN, CLOSE = '(', ')'


def scan(text):
    """(header, [ (kind, name, text) ]) — kind ∈ data|function|other."""
    lines = text.split('\n')
    head, forms, i = [], [], 0
    buf, depth, kind, name = [], 0, None, None
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if depth == 0 and not stripped:
            if not forms:
                head.append(line)
            i += 1
            continue
        if depth == 0:
            if stripped.startswith(';'):
                (head if not forms else forms).append(('other', None, line)) if forms else head.append(line)
                i += 1
                continue
            if stripped.startswith('(define-function '):
                kind = 'function'
                name = stripped[len('(define-function '):].split()[0]
            elif stripped.startswith('(define '):
                kind = 'data'
                m = re.match(r'\(define (\*[^ ]*\*)', stripped)
                name = m.group(1) if m else None
            elif stripped.startswith('(') or stripped.startswith('(load'):
                kind = 'other'
                name = None
            else:
                kind = 'other'
                name = None
            buf, depth = [], 0
        buf.append(line)
        depth += line.count(OPEN) - line.count(CLOSE)
        i += 1
        if depth <= 0:
            forms.append((kind, name, '\n'.join(buf)))
            buf, depth, kind, name = [], 0, None, None
    if buf:
        forms.append((kind or 'other', name, '\n'.join(buf)))
    return head, forms


def order(head, forms):
    data = [f for f in forms if f[0] == 'data']
    funcs = [f for f in forms if f[0] == 'function']
    others = [f for f in forms if f[0] == 'other']
    defined = {f[1] for f in funcs if f[1]}
    deps = {f[1]: {t for t in TOK.findall(f[2]) if t in defined and t != f[1]} for f in funcs if f[1]}
    placed, out = set(), []
    pending = list(funcs)
    while pending:
        progress = False
        for f in list(pending):
            if f[1] and deps[f[1]] <= placed:
                out.append(f)
                placed.add(f[1])
                pending.remove(f)
                progress = True
        if not progress:
            out.extend(pending)
            break
    return data + out + others


if __name__ == '__main__':
    p = Path(sys.argv[1])
    head, forms = scan(p.read_text())
    kinds = {}
    for k, _, _ in forms:
        kinds[k] = kinds.get(k, 0) + 1
    new = order(head, forms)
    body = '\n\n'.join(f[2].rstrip('\n') for f in new if f[2].strip())
    out = '\n'.join(l for l in head if l.strip()) + '\n\n' + body + '\n'
    # 괄호 균형 확인(손상 방지)
    bal = sum(1 if c == OPEN else (-1 if c == CLOSE else 0) for c in out)
    if bal != 0:
        print(f"REFUSED {p}: parens unbalanced ({bal})", file=sys.stderr)
        sys.exit(2)
    p.write_text(out)
    print(f"reordered {p} data={kinds.get('data',0)} funcs={kinds.get('function',0)} "
          f"other={kinds.get('other',0)}")