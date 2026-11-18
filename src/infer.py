#!/usr/bin/env python3
"""infer.py — 공리 위 커널 폐쇄 + 선택기(d-select) + 불완전 경계 + 답 보존.

DLM 0.0284 반영
  deduce.l  : 답은 active 공리 위 폐쇄로만 나온다. 선택기는 커버리지/음성커버리지를 본다.
  proof.l   : 도출은 증거 기록까지 추적 가능해야 한다(proof-carrying).
  basis.l   : active가 아닌 공리는 쓰이지 않는다.

불완전 경계(0.0288 incomplete107 계열): 입력 단서 중 학습 어휘 밖 비율을 함께 계산해
'abstain:no_evidence' / 'abstain:insufficient'(증거 충돌) / 'abstain:unknown'(영역 밖)을 구분한다.
"""
import json, hashlib, re, os
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parent.parent
import sys
sys.path.insert(0, str(ROOT / 'src'))
from induct import cues, cues_from_words, tokens, STOP, skel, CUE_MODE

W_STRICT, W_DEF = 2.0, 1.0
M_MIN = float(os.environ.get('M_MIN', '0.05'))      # 증거 우세 최소 비율
OOV_MAX = float(os.environ.get('OOV_MAX', '0.5'))  # 영역 밖 판정


def load_state():
    st = json.loads((ROOT / 'data' / 'basis.json').read_text())
    units = [u for u in st['units']]
    pool = defaultdict(list)
    for p in ('dialogue_train.jsonl', 'dialogue_val.jsonl'):
        for line in (ROOT / 'data' / p).read_text().strip().split('\n'):
            r = json.loads(line)
            pool[r['category']].append(r['output'])
    vocab = set()
    for p in ('dialogue_train.jsonl', 'dialogue_val.jsonl'):
        for line in (ROOT / 'data' / p).read_text().strip().split('\n'):
            r = json.loads(line)
            vocab.update(tokens(r['input']))
            vocab.update(tokens(r['output']))      # 응답 어휘도 학습 어휘에 포함
    lens = sorted(len(x) for v in pool.values() for x in v)
    return {'units': units, 'by_cue': {u['cue']: u for u in units}, 'pool': pool,
            'vocab': vocab, 'median_len': lens[len(lens) // 2] if lens else 0}


S = load_state()

# 범주 정의(외연): 각 정의 공리의 단서 전체와 IDF — 커널 폐쇄의 두 번째 층
import math
_DEFS = [(d['cat'], set(d['ext'])) for d in json.loads((ROOT / 'data' / 'basis.json').read_text())['cat_defs']]
_DF = defaultdict(int)
for _, ext in _DEFS:
    for c in ext:
        _DF[c] += 1
_IDF = {c: math.log(1 + len(_DEFS) / n) for c, n in _DF.items()}


def fire_proto(text):
    """정의(외연) 위 폐쇄: 입력 단서가 각 범주 정의에 얼마나 덮이는가."""
    raw = [w for w in tokens(text) if w not in STOP and len(w) > 1]
    cs = list(dict.fromkeys(cues_from_words(raw, CUE_MODE) + [skel(text)]))
    tot = sum(_IDF.get(c, 1.0) for c in cs) or 1.0
    out, proof = {}, {}
    for cat, ext in _DEFS:
        hit = [c for c in cs if c in ext]
        if hit:
            out[cat] = sum(_IDF.get(c, 1.0) for c in hit) / tot
            proof[cat] = [{'cue': c, 'idf': round(_IDF.get(c, 1.0), 3)} for c in hit]
    unknown = [w for w in raw if w not in S['vocab']]
    return {'score': out, 'proof': proof, 'unknown_ratio': len(unknown) / len(raw) if raw else 1.0,
            'unknown': unknown, 'n_content': len(raw)}


def _c3(w):
    return {w[i:i + 3] for i in range(len(w) - 2)} or {w}


# 어휘 밖 단어의 일반화: 철자 3gram 자카드 최근접(고정 알고리즘, 대상은 코퍼스 어휘)
_C3 = {w: _c3(w) for w in S['vocab'] if len(w) > 3}
GEN_TAU = float(os.environ.get('GEN_TAU', '1.01'))  # 기본 비활성(철자 근접은 비문법적 매핑을 만든다)


def map_word(w):
    if w in S['vocab']:
        return w
    a = _c3(w)
    best, bs = None, 0.0
    for v, b in _C3.items():
        inter = len(a & b)
        if not inter:
            continue
        j = inter / len(a | b)
        if j > bs:
            best, bs = v, j
    return best if bs >= GEN_TAU else None


def fire(text):
    """입력에 발화하는 active 단위를 모아 범주별 점수와 증거(proof)를 만든다."""
    raw = [w for w in tokens(text) if w not in STOP and len(w) > 1]
    mapped = [map_word(w) for w in raw]
    unknown = [w for w, m in zip(raw, mapped) if m is None]
    ws = [w for w in mapped if w]
    cs = cues_from_words(ws) + [skel(text)]
    cs = list(dict.fromkeys(cs))
    score, strict, proof = defaultdict(float), defaultdict(int), defaultdict(list)
    for c in cs:
        u = S['by_cue'].get(c)
        if not u:
            continue
        w = W_STRICT if u['strict'] else W_DEF
        score[u['cat']] += w
        strict[u['cat']] += 1 if u['strict'] else 0
        proof[u['cat']].append({'unit': u['id'], 'cue': c, 'support': u['support']})
    return {'score': score, 'strict': strict, 'proof': proof,
            'unknown_ratio': len(unknown) / len(ws) if ws else 1.0,
            'unknown': unknown, 'n_content': len(ws)}


FOLLOW = {'it', 'that', 'they', 'those', 'them', 'this', 'one'}


SCORER = os.environ.get('SCORER', 'proto')
LGG_ON = os.environ.get('LGG', '1') == '1'
FALLBACK = os.environ.get('FALLBACK', '1') == '1'     # 증거 부족 시 최선 후보로 답하기(영역밖은 되묻기 유지)
COMPOSE = os.environ.get('COMPOSE', '1') == '1'       # 입력 개체를 이용한 응답 재조합(새 문자열)
ANSWER_ALL = os.environ.get('ANSWER_ALL', '0') == '1' # 영역밖까지 답하기(되묻기 없음) — Pareto 반대편
LAST_RESORT = os.environ.get('LAST_RESORT', '0') == '1'  # 후보가 전혀 없을 때 기본 범주로 답하기
_MAJORITY = None
DECISION = os.environ.get('DECISION', 'sum')          # sum | priority | allvals
TAU_P = float(os.environ.get('TAU_P', '0.05'))       # proto 커버리지 하한
TAU_F = int(os.environ.get('TAU_F', '1'))            # 프레임 지지 하한


import evidence as _EV
_EV.load_lgg(enabled=LGG_ON)


def constrain(text):
    """입력에 대한 제약 집합(Screamer): 인스턴스 / 프레임 / 정의 커버리지."""
    import evidence as EV
    raw = [w for w in tokens(text) if w not in STOP and len(w) > 1]
    c_inst, trace = set(), []
    for w in raw:
        cat, tr = EV.resolve(w)
        if cat:
            c_inst.add(cat); trace.append(tr)
    f, fdist = EV.frame_cats(text, TAU_F)
    p = fire_proto(text)
    c_proto = {c for c, v in p['score'].items() if v >= TAU_P}
    return {'inst': c_inst, 'frame': f, 'proto': c_proto,
            'frame_dist': fdist, 'inst_trace': trace, 'proto_score': p['score'],
            'unknown_ratio': p['unknown_ratio']}


def derive_priority(text, st=None):
    global _MAJORITY
    """Rocq식: 인스턴스 우선순위로 결정. 모호성은 우선순위가 해소한다.
    계층 순서: 후속발화 상태 → LGG(검사된 정의) → 영역밖 가드 → 인스턴스 우선순위."""
    import evidence as EV
    ws = [w for w in tokens(text) if w not in STOP]
    follow = bool(st and st.get('last_category')) and (
        any(w in FOLLOW for w in tokens(text)) or len(ws) <= 3)
    if follow:
        return st['last_category'], 'state', {'follow': True}
    if LGG_ON:
        lm = _EV.lgg_fold([w for w in ws if len(w) > 1])
        if lm:
            win = max(lm, key=lm.get)
            return win, 'lgg', {'conf': lm[win], 'candidates': sorted(lm), 'layer': 'lgg'}
    if fire_proto(text)['unknown_ratio'] > OOV_MAX:
        if ANSWER_ALL:
            p = fire_proto(text)
            if p['score']:
                top = max(p['score'], key=p['score'].get)
                return top, 'forced', {'conf': p['score'][top], 'from': 'proto'}
            if LAST_RESORT:
                if _MAJORITY is None:
                    _MAJORITY = max(S['pool'], key=lambda k: len(S['pool'][k]))
                return _MAJORITY, 'default', {'from': 'majority'}
        return None, 'unknown', {'unknown_ratio': round(fire_proto(text)['unknown_ratio'], 3), 'conf': 0}
    c = constrain(text)
    if not c['inst']:
        if FALLBACK:
            p = fire_proto(text)
            if p['score']:
                top = max(p['score'], key=p['score'].get)
                return top, 'fallback', {'conf': p['score'][top], 'from': 'proto'}
        if LAST_RESORT:
            if _MAJORITY is None:
                _MAJORITY = max(S['pool'], key=lambda k: len(S['pool'][k]))
            return _MAJORITY, 'default', {'from': 'majority'}
        return None, 'no_evidence', {'constraint': {k: sorted(v) for k, v in c.items() if isinstance(v, set)}}
    best = {}
    for tr in c['inst_trace']:
        cat = tr['cat']
        k = (tr['priority'], -tr['support'], cat)
        if cat not in best or k < best[cat]:
            best[cat] = k
    winner = min(best, key=lambda cat: best[cat])
    conf = sum(tr['support'] for tr in c['inst_trace'] if tr['cat'] == winner)
    return winner, 'derived', {'winner': winner, 'prio': best[winner][0], 'conf': conf,
                               'candidates': sorted(best), 'n_inst': len(c['inst_trace'])}



def derive_allvals(text, st=None):
    """Screamer식: 제약에 일관된 값 전체를 열거. 여럿이면 모호 → 되묻기."""
    c = constrain(text)
    keep = set(c['proto']) if c['proto'] else None
    if c['inst']:
        keep = c['inst'] if keep is None else (keep & c['inst'])
    if c['frame']:
        both = (keep if keep is not None else set()) & c['frame']
        if both:
            keep = both
    keep = keep or set()
    if not keep:
        return None, ('no_evidence' if not c['inst'] else 'insufficient'), \
               {'constraint': {'inst': sorted(c['inst']), 'frame': sorted(c['frame'])},
                'n': 0}
    if c['unknown_ratio'] > OOV_MAX:
        return None, 'unknown', {'n': len(keep), 'values': sorted(keep)}
    if len(keep) > 1:
        return None, 'ambiguous', {'values': sorted(keep), 'n': len(keep), 'conf': 1.0 / len(keep)}
    return next(iter(keep)), 'derived', {'values': sorted(keep), 'n': 1, 'conf': 1.0}


def derive(text, state=None):
    global _MAJORITY
    """반환: (category|None, reason, trace)"""
    if DECISION == 'priority':
        return derive_priority(text, state)
    if DECISION == 'allvals':
        return derive_allvals(text, state)
    f = fire_proto(text) if SCORER == 'proto' else fire(text)
    if SCORER == 'proto':
        cands = sorted(((c, f['score'][c], 0) for c in f['score']), key=lambda x: -x[1])
    else:
        cands = sorted(((c, f['score'][c], f['strict'][c]) for c in f['score']),
                       key=lambda x: (-x[2], -x[1]))
    trace = {'cands': cands[:3], 'unknown_ratio': round(f['unknown_ratio'], 3),
             'conf': cands[0][1] if cands else 0.0,
             'proof': f['proof'][cands[0][0]] if cands else []}
    follow = bool(state and state.get('last_category')) and (
        any(w in FOLLOW for w in tokens(text)) or f['n_content'] <= 3)
    if not cands:
        if follow:
            return state['last_category'], 'state', trace
        return None, 'no_evidence', trace
    top_c, top_s, _ = cands[0]
    second = cands[1][1] if len(cands) > 1 else 0.0
    margin = (top_s - second) / top_s if top_s else 0.0
    trace['margin'] = round(margin, 3)
    if follow and margin < M_MIN:
        return state['last_category'], 'state', trace
    if f['unknown_ratio'] > OOV_MAX:
        return None, 'unknown', trace
    if margin < M_MIN:
        if FALLBACK:
            return top_c, 'fallback', trace
        return None, 'insufficient', trace
    return top_c, 'derived', trace


def compose_response(cat, text, base):
    """Silicon fold/unfold의 응용: 정의된 응답 틀의 개체 자리를 입력의 개체로 채운다."""
    if not COMPOSE:
        return base
    ins_words = [w for w in tokens(text) if w not in STOP and len(w) > 1]
    cand = [w for w in ins_words if w in S['vocab']]
    if not cand:
        return base
    for w in cand:
        for old in ('dogs', 'dog', 'birds', 'bird', 'cats', 'cat', 'boxes', 'box',
                    'windows', 'window', 'humans', 'human'):
            if old in base and w != old and w not in base:
                out = base.replace(old, w, 1)
                if out != base:
                    return out
    return base


def respond(text, state=None):
    c, why, trace = derive(text, state)
    if c is None:
        return None, None, why, trace
    cand = S['pool'].get(c, [])
    if not cand:                          # 보존: admitted pool 밖 응답은 만들지 않는다
        return None, None, 'no_pool', trace
    near = [r for r in cand if abs(len(r) - S['median_len']) <= 12] or cand
    h = int(hashlib.sha256(text.encode()).hexdigest(), 16)
    return c, compose_response(c, text, near[h % len(near)]), why, trace


if __name__ == '__main__':
    st = json.loads((ROOT / 'data' / 'basis.json').read_text())
    print(f"INFER units={len(S['units'])} vocab={len(S['vocab'])} median_len={S['median_len']} "
          f"M_MIN={M_MIN} OOV_MAX={OOV_MAX}")
    for q in ['hey there little one', 'the dog wants to play', 'what is the square root of two']:
        c, r, why, tr = respond(q)
        print(f"  '{q}' -> cat={c} why={why} resp={(r or '')[:40]!r} cands={tr['cands']}")
