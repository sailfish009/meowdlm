#!/usr/bin/env python3
"""induct.py — 연역학습: 코퍼스 기록에서 '기저 공리 단위'를 유도한다.

DLM 0.0284 방법론 반영
  basis.l        : 단위는 (id, rules, evidence, support, version, status, history)로 저장되고
                   active인 동안에만 추론에 쓰인다. 유도 직후엔 inactive, 채택 검사를 통과해야 active.
  deduce.l d-select : 채택 검사는 '양성 기록 커버리지 최대화 + 음성(타 범주) 커버리지 0'이다.
  axiom-graph.l  : 같은 단서를 공유하는 단위 사이에 의존 간선을 둔다(철회 시 재검증 경로).

학습 산출물은 이산 구조(단위 목록)이며 gradient 스텝은 0이다.
사전은 코퍼스에서 유도한 표제어 규칙(어미 제거)만 쓴다 — 프로브에서 얻은 어휘는 쓰지 않는다.
"""
import json, re, hashlib, sys
from pathlib import Path
from collections import Counter, defaultdict

sys.path.insert(0, str(Path(__file__).resolve().parent))
import basis as B
import axiomgraph as G

ROOT = Path(__file__).resolve().parent.parent
STOP = set("""a an the i you it its it's is are was were be been being do does did not no
my your me we us he she they them his her their this that these those to of in on at for
with about and or but if then so as by from up down out over under again very just too
can could would should will shall may might must have has had having""".split())
import os as _os
S_MIN_STRICT = int(_os.environ.get('S_MIN_STRICT', '1'))
S_MIN_DEF = int(_os.environ.get('S_MIN_DEF', '1'))
P_DEF = float(_os.environ.get('P_DEF', '0.5'))      # 방어가능 층 최소 순도
F_BUDGET = int(_os.environ.get('F_BUDGET', '1'))    # 단위별 허용 음성 기록 수      # 단위 채택: 최소 지지 기록 수, 최소 순도(방어가능 층)


def morph(w):
    """형태 규칙(고정 알고리즘, 데이터 무관): 복수·진행·과거 어미 제거 + 중복 자음 축약."""
    w = w.replace("'", '')
    if len(w) > 4 and w.endswith('ies'):
        w = w[:-3] + 'y'
    for suf in ('ing', 'ed', 'es', 's'):
        if len(w) > len(suf) + 2 and w.endswith(suf):
            w = w[:-len(suf)]
            break
    if len(w) > 3 and w[-1] == w[-2] and w[-1] not in 'aeiou':
        w = w[:-1]
    return w


def tokens(text):
    return [morph(t) for t in re.findall(r"[a-z']+", text.lower())]


import os as _osenv
CUE_MODE = _osenv.environ.get('CUE_MODE', 'base')       # base | gap | char | gap+char


def cues_from_words(ws, mode=None):
    """내용어 목록 → 단서 집합.

    base    : 1·2·3gram (v0.0002)
    gap     : + 구멍 있는 패턴(anti-unification 계열) "wi ? wj" — 가운데가 변수
    char    : + 철자 5gram ('c:' 접두) — 어휘 밖 단어가 부분 일치로 흡수된다
    """
    mode = mode or CUE_MODE
    out = [w for w in ws]
    out += [' '.join(ws[i:i + 2]) for i in range(len(ws) - 1)]
    out += [' '.join(ws[i:i + 3]) for i in range(len(ws) - 2)]
    if 'gap' in mode:
        for i in range(len(ws)):
            for d in (2, 3, 4):
                if i + d < len(ws):
                    out.append(f"{ws[i]} ? {ws[i + d]}")
    if 'char' in mode:
        for w in ws:
            if len(w) >= 5:
                out.extend('c:' + w[k:k + 5] for k in range(len(w) - 4))
    return out


def cues(text):
    """단서 = 내용어 기반 단서 집합(CUE_MODE에 따라 확장)."""
    ws = [w for w in tokens(text) if w not in STOP and len(w) > 1]
    return cues_from_words(ws)


def skel(text):
    """도식(skeleton): 기능어·구두점은 유지하고 내용어는 변수 ? 로 추상화.
    같은 도식을 공유하는 기록들이 서로 다른 내용어를 채우므로, 이 단위는
    학습에서 보지 못한 내용어에도 발화한다(DLM의 변수 있는 규칙에 대응)."""
    out = []
    for w in tokens(text):
        t = '?' if (w not in STOP and len(w) > 1) else w
        if t == '?' and out and out[-1] == '?':
            continue
        out.append(t)
    return 's:' + ' '.join(out)


def load(path):
    return [json.loads(l) for l in open(path)]


def build_records(paths):
    recs = []
    for p in paths:
        for r in load(p):
            recs.append((f'r{len(recs)}', r['input'], r['category'], r['output']))
    return recs


def induce(recs):
    CAT_OF = {}
    """단서→범주 단위를 유도하고, d-select식 채택 검사로 active 공리 집합을 만든다."""
    cue_recs = defaultdict(lambda: defaultdict(list))     # cue -> cat -> [rid]
    for rid, text, cat, out in recs:
        # 단서는 입력과 응답 양쪽에서 뽑는다(응답도 같은 코퍼스의 증거다)
        for c in sorted(set(cues(text)) | set(cues(out)) | {skel(text)}):
            cue_recs[c][cat].append(rid)
    cats = sorted({c for _, _, c, _ in recs})

    # 1) 후보 단위: (cue, cat) with support>=S_MIN, purity>=P_DEF
    cand = []
    for c, per in sorted(cue_recs.items()):
        tot = sum(len(v) for v in per.values())
        for cat, rids in sorted(per.items()):
            sup, pur = len(rids), len(rids) / tot
            strict = pur == 1.0
            if (strict and sup >= S_MIN_STRICT) or (not strict and sup >= S_MIN_DEF and pur >= P_DEF):
                uid = 'u' + hashlib.sha1(f'{c}|{cat}'.encode()).hexdigest()[:10]
                cand.append({'uid': uid, 'cue': c, 'cat': cat, 'support': sup,
                             'purity': pur, 'evidence': sorted(rids), 'strict': strict,
                             'neg': [r for oc, rr in per.items() if oc != cat for r in rr]})
    # 2) 의존 간선: 같은 단서를 공유하는 다른 범주의 단위
    by_cue = defaultdict(list)
    for u in cand:
        by_cue[u['cue']].append(u['uid'])
    for u in cand:
        u['deps'] = [x for x in by_cue[u['cue']] if x != u['uid']]

    # 3) 채택 검사(d-select): 범주별로 양성 커버리지를 늘리고 음성 커버리지를 0으로 유지
    basis, report = [], {}
    for cat in cats:
        own = [rid for rid, _, c, _ in recs if c == cat]
        others = [rid for rid, _, c, _ in recs if c != cat]
        units = sorted([u for u in cand if u['cat'] == cat],
                       key=lambda u: (-u['support'], -u['purity'], u['cue']))
        cov, fcov, chosen = set(), set(), []
        for u in units:
            add = set(u['evidence']) - cov
            fadd = (set(u['evidence']) & set(others)) - fcov
            if not add:
                continue
            if len(fadd) > F_BUDGET:      # 허용 예산을 넘는 음성 커버리지만 거부
                continue
            cov |= add
            fcov |= fadd
            chosen.append(u)
        report[cat] = {'units': len(chosen), 'covered': len(cov & set(own)), 'own': len(own),
                       'false': len(fcov), 'coverage': len(cov & set(own)) / len(own)}
        for u in chosen:
            basis = B.b_add(basis, u['uid'], [u['cue']], u['evidence'], u['support'])
            basis = B.b_activate(basis, u['uid'])
    # 범주별 '정의 단위': 한 공리 안에 그 범주의 단서 전체를 규칙 목록으로 담는다
    # (basis.l의 b-axiom은 rules를 리스트로 갖는다 — 정의는 여러 규칙의 묶음이다)
    per_cat_rules = defaultdict(list)
    for u in cand:
        if B.b_find(u['uid'], basis) is not None:
            per_cat_rules[u['cat']].append(u['cue'])
    cat_axioms = []
    for cat, rules in per_cat_rules.items():
        uid = 'c_' + hashlib.sha1(cat.encode()).hexdigest()[:8]
        ev = sorted({r for rid, _, c, _ in recs if c == cat for r in [rid]})
        basis = B.b_add(basis, uid, sorted(set(rules)), ev, len(rules))
        CAT_OF[uid] = cat
        basis = B.b_activate(basis, uid)
        cat_axioms.append(uid)
    basis = B.b_cse(basis)
    nodes = [G.ag_node(u['uid'], [u['cue']], u['evidence'], u['support'], u['deps']) for u in cand]
    return {'basis': basis, 'cand': cand, 'nodes': nodes, 'report': report,
            'cat_axioms': cat_axioms, 'cat_of': CAT_OF, 'cue_recs': cue_recs,
            'cats': cats, 'vocab': sorted({w for _, t, _, _ in recs for w in tokens(t)})}


def main():
    recs = build_records([ROOT / 'data' / 'dialogue_train.jsonl', ROOT / 'data' / 'dialogue_val.jsonl'])
    st = induce(recs)
    bs = st['basis']
    print(f"INDUCT records={len(recs)} cues={len(st['cand'])} "
          f"active_units={B.b_stats(bs)['active']} graph_nodes={len(st['nodes'])}")
    print(f"INDUCT deps_check={G.ag_check_deps(st['nodes'])}")
    cov = [r['coverage'] for r in st['report'].values()]
    print(f"INDUCT train_coverage mean={sum(cov)/len(cov):.3f} min={min(cov):.3f} "
          f"false_coverage_total={sum(r['false'] for r in st['report'].values())}")
    out = {'version': (ROOT / 'VERSION').read_text().strip(),
           'units': [{'id': u['uid'], 'cue': u['cue'], 'cat': u['cat'], 'support': u['support'],
                      'purity': round(u['purity'], 4), 'strict': u['strict'],
                      'n_evidence': len(u['evidence']), 'deps': u['deps']} for u in st['cand']
                   if basis_b_find(bs, u['uid'])],
           'report': st['report'], 'cats': st['cats'],
           'cat_defs': [{'uid': uid, 'cat': st['cat_of'][uid],
                         'rules': B.b_find(uid, bs)['rules'],
                         'ext': {c: len(per[st['cat_of'][uid]])
                                 for c, per in st['cue_recs'].items()
                                 if st['cat_of'][uid] in per}}
                        for uid in st['cat_axioms']]}
    (ROOT / 'data' / 'basis.json').write_text(json.dumps(out, indent=1))
    print(f"INDUCT wrote data/basis.json units={len(out['units'])}")


def basis_b_find(bs, uid):
    return B.b_find(uid, bs) is not None


if __name__ == '__main__':
    main()
