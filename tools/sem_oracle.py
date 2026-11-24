#!/usr/bin/env python3
"""S1 독립 오라클(meowdlm 0.0071 tools/sem_oracle.py): meowdlm 458어휘 33규칙 문법 위 span 파서 + sem + 노드 증명서 검사.

Maru 구현(src/meow/sem.l)과 코드를 공유하지 않는 두 번째 구현이다.
입력: data/syntax_grammar.l, data/syntax_lexicon.l, data/syntax_corpus.l (읽기 전용)
출력: 커버리지, sem 생성 수, 증명서 재유도 결과.
"""
import re, sys
from pathlib import Path

MEOW = Path(__file__).resolve().parent.parent
TERM = {'S', 'CL', 'NP', 'NG', 'VP', 'VL', 'TRAIL', 'MOD', 'PP', 'INTJ'}


def tokens(s):
    return re.findall(r'\(|\)|"[^"]*"|[^\s()]+', s)


def atom_text(t):
    return t[1:-1] if t.startswith('"') else t


def parse_forms(text):
    """(define *name* (list ...)) 들을 [(name, value)] 로."""
    out = []
    i = 0
    ks = tokens(text)
    while i < len(ks):
        if ks[i] == '(' and i + 1 < len(ks) and ks[i + 1] == 'define':
            name = ks[i + 2]
            assert ks[i + 3] == '(' and ks[i + 4] == 'list', (name, ks[i + 3:i + 6])
            i += 5
            vals, i = read_list(ks, i)
            out.append((name, vals))
        else:
            i += 1
    return out


def read_list(ks, i):
    """ks[i] 는 이미 '(' 다음. ')' 만나면 종료."""
    vals = []
    while ks[i] != ')':
        if ks[i] == '(':
            j = i + 1
            if ks[j] == 'list':
                j += 1
            sub, i = read_list(ks, j)
            vals.append(sub)
        else:
            vals.append(atom_text(ks[i]))
            i += 1
    return vals, i + 1


def resolve(v, env):
    if isinstance(v, list):
        return [resolve(x, env) for x in v]
    if isinstance(v, str) and v.startswith('*') and v in env:
        return resolve(env[v], env)
    return v


def load():
    env = {}
    for f in ('data/syntax_grammar.l', 'data/syntax_lexicon.l', 'data/syntax_corpus.l'):
        for n, v in parse_forms((MEOW / f).read_text()):
            env[n] = v
    rules = resolve(env['*rules*'], env)
    lex = resolve(env['*lexicon*'], env)
    corpus = [resolve(v, env) for n, v in env.items() if re.fullmatch(r'\*s\d+\*', n)]
    corpus.sort(key=lambda t: 0)  # 정의 순서 유지(아래에서 이름순 정렬)
    names = sorted([n for n in env if re.fullmatch(r'\*s\d+\*', n)], key=lambda n: int(n[2:-1]))
    corpus = [resolve(env[n], env) for n in names]
    return rules, lex, corpus


# ---------- sem 규칙 (규칙 lhs/rhs 별 의미 조립) ----------
def head_of(sem):
    """sem 에서 머리 단어를 꺼낸다(소문자 표면형)."""
    if isinstance(sem, str):
        return sem
    tag = sem[0]
    if tag in ('np', 'ng', 'pp', 'vp'):
        return sem[2] if tag == 'pp' else (sem[2] if len(sem) > 2 else sem[1])
    if tag == 'clause':
        return head_of(sem[2]) if len(sem) > 2 and sem[2] != 'none' else head_of(sem[1])
    return sem[-1] if len(sem) > 1 else tag


def make_node(lhs, rhs_cats, kids):
    """규칙 lhs ← kids 로 sem 을 조립한다."""
    k = kids
    if lhs == 'S':
        return k[-1] if len(k) == 1 else (['s', k[0], k[-1]] if len(k) == 3 else k[0])
    if lhs == 'CL':
        if len(k) == 1:
            return ['clause', 'none', k[0]]
        np = k[0] if rhs_cats[0] == 'NP' else 'none'
        vp = k[-1] if rhs_cats[-1] == 'VP' else 'none'
        return ['clause', np, vp]
    if lhs == 'NP':
        if rhs_cats == ['DET', 'NG']:
            return ['np', k[0], head_of(k[1])]
        if rhs_cats == ['PRON']:
            return ['np', k[0]]
        return ['np', head_of(k[0])]
    if lhs == 'NG':
        if rhs_cats == ['A', 'NG']:
            return k[1]
        if rhs_cats == ['N']:
            return ['ng', k[0]]
        if rhs_cats == ['N', 'PP']:
            return ['ng', k[0], k[1]]
        return ['ng', k[0]]
    if lhs == 'VP':
        verb = head_of(k[0])
        obj = k[1] if len(k) > 1 and rhs_cats[1] == 'NP' else 'none'
        return ['vp', verb, obj]
    if lhs == 'VL':
        return k[-1]
    if lhs in ('TRAIL', 'MOD'):
        return 'none'
    if lhs == 'PP':
        return ['pp', k[0], head_of(k[1])]
    return ['?', lhs]


def cats_of_tree(t):
    return t[1]


def parse(toks, rules, lex):
    """span 파서: (cat,i,j) → 노드 dict(sem, kids, rule). 각 칸은 첫 일치만."""
    n = len(toks)
    cat_of = {}
    for w in set(toks):
        cat_of[w] = lex.get(w, [])
    by_lhs = {}
    for r in rules:
        by_lhs.setdefault(r[0], []).append(r[1])
    chart = {}

    def get(cat, i, j):
        return chart.get((cat, i, j))

    for length in range(1, n + 1):
        for i in range(0, n - length + 1):
            j = i + length
            if length == 1:
                w = toks[i]
                for c in cat_of.get(w, []):
                    chart[(c, i, j)] = {'cat': c, 'kids': [], 'leaf': w, 'sem': w, 'rule': None}
            for lhs, rhss in by_lhs.items():
                if (lhs, i, j) in chart:
                    continue
                for rhs in rhss:
                    node = match_rhs(rhs, i, j, cat_of, toks, get)
                    if node is not None:
                        chart[(lhs, i, j)] = node
                        break
    return chart, get


def match_rhs(rhs, i, j, cat_of, toks, get):
    ln = len(rhs)

    def rec(ri, pos, kids):
        if ri == len(rhs):
            return kids if pos == j else None
        sym = rhs[ri]
        rest = len(rhs) - ri - 1
        if sym not in ('S', 'CL', 'NP', 'NG', 'VP', 'VL', 'TRAIL', 'MOD', 'PP', 'INTJ'):
            # 단말: 현재 토큰이 그 범주여야 한다
            if pos + rest > j:
                return None
            if pos + 1 + rest > j:
                return None
            if sym in cat_of.get(toks[pos], []):
                r = rec(ri + 1, pos + 1, kids + [toks[pos]])
                if r is not None:
                    return r
            return None
        for end in range(pos + 1, j + 1):
            nd = get(sym, pos, end)
            if nd is None:
                continue
            r = rec(ri + 1, end, kids + [nd])
            if r is not None:
                return r
        return None

    kids = rec(0, i, [])
    if kids is None:
        return None
    sem = make_node(rhs_lhs(rhs), rhs, kids) if False else None
    return kids


def rhs_lhs(rhs):
    return None


def build(toks, rules, lex, CAP=6):
    """팩킹 span 파서: 세포당 최대 CAP 개 트리. sem 은 자식 sem 으로 조립."""
    n = len(toks)
    by_lhs = {}
    for r in rules:
        by_lhs.setdefault(r[0], []).append(r[1])
    term = TERM
    lexcat = {w: lex.get(w, []) for w in set(toks)}
    chart = {}

    def get(cat, i, j):
        return chart.get((cat, i, j), [])

    def match(rhs, i, j, lhs):
        out = []

        def rec(ri, pos, kids):
            if len(out) >= CAP:
                return
            if ri == len(rhs):
                if pos == j:
                    sems = [k if isinstance(k, str) else k['sem'] for k in kids]
                    out.append({'cat': lhs, 'kids': kids, 'leaf': None,
                                'sem': make_node(lhs, rhs, sems), 'rule': [lhs, rhs]})
                return
            sym = rhs[ri]
            if sym not in term:
                if pos < j and sym in lexcat.get(toks[pos], []):
                    leaf = {'cat': sym, 'kids': [], 'leaf': toks[pos], 'sem': toks[pos], 'rule': None}
                    rec(ri + 1, pos + 1, kids + [leaf])
                return
            for end in range(pos + 1, j + 1):
                for nd in get(sym, pos, end):
                    rec(ri + 1, end, kids + [nd])
        rec(0, i, [])
        return out

    for length in range(1, n + 1):
        for i in range(0, n - length + 1):
            j = i + length
            if length == 1:
                w = toks[i]
                for c in lexcat.get(w, []):
                    chart.setdefault((c, i, j), []).append(
                        {'cat': c, 'kids': [], 'leaf': w, 'sem': w, 'rule': None})
            # 같은 (i,j) 안의 단항 사슬(NP→NG, VP→VL …)은 고정점까지 반복한다.
            for _ in range(24):
                added = 0
                for lhs, rhss in by_lhs.items():
                    cell = chart.setdefault((lhs, i, j), [])
                    if len(cell) >= CAP:
                        continue
                    for rhs in rhss:
                        if len(cell) >= CAP:
                            break
                        new = match(rhs, i, j, lhs)
                        if new:
                            cell.extend(new)
                            added += len(new)
                if not added:
                    break
    return chart.get(('S', 0, n), [])


# ---------- 증명서 재유도 검사 ----------

def check(node, rules, lex, depth=[0]):
    """노드마다 규칙과 자식 범주·sem 을 재유도해 대조."""
    if node['leaf'] is not None:
        return node['cat'] in lex.get(node['leaf'], [])
    kids = node['kids']
    kcats = [k if isinstance(k, str) else k['cat'] for k in kids]
    ok_rule = False
    for lhs, rhs in ((r[0], r[1]) for r in rules if r[0] == node['cat']):
        if rhs != kcats:
            continue
        if make_node(lhs, rhs, [k if isinstance(k, str) else k['sem'] for k in kids]) == node['sem']:
            ok_rule = True
            break
    if not ok_rule:
        return False
    for k in kids:
        if isinstance(k, dict) and not check(k, rules, lex):
            return False
    return True


def count_nodes(node):
    if node['leaf'] is not None:
        return 1
    return 1 + sum(count_nodes(k) for k in node['kids'] if isinstance(k, dict))


def main():
    rules, lex, corpus = load()
    lexmap = {e[0]: e[1] for e in lex}
    print(f'rules={len(rules)} lex={len(lexmap)} corpus={len(corpus)}')
    derived = sem_ok = cert_ok = 0
    fails = []
    for idx, toks in enumerate(corpus):
        trees = build(toks, rules, lexmap)
        if not trees:
            continue
        tree = trees[0]
        derived += 1
        if tree['sem'] not in (None, 'none'):
            sem_ok += 1
        if check(tree, rules, lexmap):
            cert_ok += 1
        else:
            fails.append(idx)
    print(f'DERIVED {derived}/{len(corpus)}')
    print(f'SEM {sem_ok}/{derived}')
    print(f'CERT {cert_ok}/{derived} fail={fails[:5]}')


if __name__ == '__main__':
    main()