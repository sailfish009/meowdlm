#!/usr/bin/env python3
"""evidence.py — 증거 기반을 세 참조 시스템의 구조로 만든다.

Silicon (Viper)  술어 fold/unfold: 범주 술어의 몸체(표면형 집합)를 정의하고,
                 표면형을 술어로 fold, 필요하면 술어를 unfold 해 증거를 펼친다.
Rocq (Coq)       인스턴스/힌트 테이블: 표면형 → 술어 인스턴스를 **우선순위**로 정렬하고
                 결정적으로 해소한다. 해소 과정은 추적 가능(어떤 인스턴스 규칙이 발화했는지).
Screamer         변수·유한 도메인·제약: 입력마다 후보 술어 집합을 제약으로 좁히고,
                 일관된 값이 여럿이면 '모호'로 보고한다(all-values).

증거는 코퍼스에서만 나온다(프로브 어휘 사용 금지).
"""
import json, sys
from pathlib import Path
from collections import defaultdict, Counter

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'src'))
from induct import cues, tokens, STOP, skel, CUE_MODE

# 인스턴스 우선순위(Rocq hint priority): 낮을수록 강한 규칙
P_STRICT, P_DEFEAS, P_FRAME = 0, 1, 2


def load_corpus():
    rows = []
    for p in ('dialogue_train.jsonl', 'dialogue_val.jsonl'):
        for line in (ROOT / 'data' / p).read_text().strip().split('\n'):
            rows.append(json.loads(line))
    return rows


def build():
    rows = load_corpus()
    # --- 술어 몸체(Silicon unfold): 범주 술어의 표면형 집합
    body = defaultdict(dict)              # cat -> form -> {support, purity}
    form_cats = defaultdict(dict)         # form -> cat -> support
    for r in rows:
        cat = r['category']
        for c in sorted(set(cues(r['input'])) | set(cues(r['output']))):
            body[cat][c] = body[cat].get(c, 0) + 0
            form_cats[c][cat] = form_cats[c].get(cat, 0) + 1
    for c, per in form_cats.items():
        tot = sum(per.values())
        for cat, sup in per.items():
            body[cat][c] = {'support': sup, 'purity': sup / tot}

    # --- 인스턴스 테이블(Rocq): form -> [(priority, cat, support, purity)]
    inst = {}
    for c, per in form_cats.items():
        tot = sum(per.values())
        lst = []
        for cat, sup in sorted(per.items()):
            pur = sup / tot
            if pur == 1.0 and sup >= 2:
                pr = P_STRICT
            elif pur >= 0.5:
                pr = P_DEFEAS
            else:
                continue
            lst.append((pr, cat, sup, round(pur, 4)))
        if lst:
            inst[c] = sorted(lst, key=lambda x: (x[0], -x[2], x[1]))

    # --- 프레임 테이블: 도식 -> 범주 지지
    frame = defaultdict(Counter)
    for r in rows:
        frame[skel(r['input'])][r['category']] += 1

    vocab = set()
    for r in rows:
        vocab.update(tokens(r['input'])); vocab.update(tokens(r['output']))
    return {'body': {c: {f: v for f, v in d.items()} for c, d in body.items()},
            'inst': inst,
            'frame': {k: dict(v) for k, v in frame.items()},
            'vocab': vocab, 'n_rows': len(rows)}


S = build()

# --- LGG 패턴 계층(BACKUP dlm_v0.0110 + v0.0017): 최상위 인스턴스, 우선순위 -1
P_LGG = -1
_LGG = {'on': {}, 'stats': {'patterns': 0, 'fired': 0}}


def load_lgg(path=None, enabled=True):
    global _LGG
    p = path or (ROOT / 'data' / 'lgg.json')
    _LGG = {'on': {}, 'stats': {'patterns': 0, 'fired': 0}}
    if not enabled or not p.exists():
        return _LGG
    d = json.loads(p.read_text())
    for a in d['admitted']:
        _LGG['on'].setdefault(a['cat'], []).append((tuple(a['pat']), a['support']))
    _LGG['stats']['patterns'] = sum(len(v) for v in _LGG['on'].values())
    return _LGG


def lgg_fold(seq):
    """LGG 패턴에 발화하는 범주 → 최대 지지도(우선순위 -1 인스턴스)."""
    from lgg import covers
    out = {}
    for cat, pats in _LGG['on'].items():
        for pat, sup in pats:
            if covers(pat, tuple(seq)):
                out[cat] = max(out.get(cat, 0), sup)
    if out:
        _LGG['stats']['fired'] += 1
    return out


def unfold(cat):
    """술어를 펼쳐 몸체(표면형 집합)를 얻는다(Silicon unfold)."""
    return S['body'].get(cat, {})


def fold(form):
    """표면형을 술어로 접는다(Silicon fold). 반환: 우선순위 정렬된 인스턴스 목록."""
    return S['inst'].get(form, [])


def resolve(form):
    """Rocq식 결정적 해소: 최상위 인스턴스 하나와 그 추적을 돌려준다."""
    lst = fold(form)
    if not lst:
        return None, None
    pr, cat, sup, pur = lst[0]
    return cat, {'form': form, 'cat': cat, 'priority': pr, 'support': sup, 'purity': pur,
                 'alternatives': [(c, s) for p, c, s, u in lst[1:]]}


def frame_cats(text, f_min=1):
    """도식 인스턴스가 지지하는 범주 집합(프레임 힌트)."""
    d = S['frame'].get(skel(text), {})
    return {c for c, n in d.items() if n >= f_min}, d


if __name__ == '__main__':
    print(f"EVIDENCE rows={S['n_rows']} predicates={len(S['body'])} "
          f"instances={len(S['inst'])} frames={len(S['frame'])} vocab={len(S['vocab'])}")
    tot = sum(len(v) for v in S['inst'].values())
    strict = sum(1 for v in S['inst'].values() for x in v if x[0] == P_STRICT)
    print(f"EVIDENCE instances_total={tot} strict={strict} defeasible={tot-strict}")
    for q in ('puppy', 'bark', 'couch', 'box'):
        print(f"  fold({q})={fold(q)[:2]}")
