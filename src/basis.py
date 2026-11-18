"""basis.py — 버전 있는 기저 공리 저장소.

포트 출처: /research/dlm_v0.0284/src/dlm/basis.l (b-axiom, b-set-status, b-activate,
b-deactivate, b-rollback, b-active-rules, b-cse).
DLM의 규칙: 학습은 후보를 만들고, 공리는 active인 동안에만 쓰이며, 증거가 철회되면
상태가 바뀌고 version이 증가하고 history에 남는다.
"""


def b_axiom(uid, rules, evidence, support, version=0, status='inactive', history=()):
    return {'id': uid, 'rules': list(rules), 'evidence': list(evidence),
            'support': support, 'version': version, 'status': status,
            'history': list(history)}


def b_find(uid, basis):
    for ax in basis:
        if ax['id'] == uid:
            return ax
    return None


def b_put(ax, basis):
    return [ax] + [x for x in basis if x['id'] != ax['id']]


def b_add(basis, uid, rules, evidence, support):
    if b_find(uid, basis) is not None:
        return basis
    return basis + [b_axiom(uid, rules, evidence, support)]


def b_set_status(basis, uid, status):
    ax = b_find(uid, basis)
    if ax is None:
        return basis
    new = b_axiom(uid, ax['rules'], ax['evidence'], ax['support'],
                  version=ax['version'] + 1, status=status,
                  history=ax['history'] + [(ax['status'], ax['version'])])
    return b_put(new, basis)


def b_activate(basis, uid):
    return b_set_status(basis, uid, 'active')


def b_deactivate(basis, uid):
    return b_set_status(basis, uid, 'inactive')


def b_rollback(basis, uid):
    """마지막 상태 변경을 되돌린다(basis.l b-rollback과 같은 의미)."""
    ax = b_find(uid, basis)
    if ax is None or not ax['history']:
        return basis
    prev_status, prev_version = ax['history'][-1]
    new = b_axiom(uid, ax['rules'], ax['evidence'], ax['support'],
                  version=prev_version, status=prev_status,
                  history=ax['history'][:-1])
    return b_put(new, basis)


def b_active_rules(basis):
    out = []
    for ax in basis:
        if ax['status'] == 'active':
            out.extend(ax['rules'])
    return out


def b_active_ids(basis):
    return [ax['id'] for ax in basis if ax['status'] == 'active']


def b_key(ax):
    return (tuple(sorted(ax['rules'])), tuple(ax['evidence']), ax['support'])


def b_cse(basis):
    """규칙·증거·지지도가 같은 중복 공리를 하나로 합친다(basis.l b-cse)."""
    seen, out = set(), []
    for ax in basis:
        k = b_key(ax)
        if k in seen:
            continue
        seen.add(k)
        out.append(ax)
    return out


def b_stats(basis):
    return {'total': len(basis),
            'active': sum(1 for a in basis if a['status'] == 'active'),
            'inactive': sum(1 for a in basis if a['status'] == 'inactive')}
