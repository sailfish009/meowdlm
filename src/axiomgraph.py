"""axiomgraph.py — 공리 의존 그래프와 DCE.

포트 출처: /research/dlm_v0.0284/src/dlm/axiom-graph.l
  ag-reach(후방 의존 도달), ag-dce(roots에서 도달 가능한 노드만 유지),
  ag-cse-maps(중복 노드 병합), ag-check-deps(의존 대상이 모두 존재해야 ok).
역할: 증거가 철회되면 그 증거에 의존하는 공리만 재검증 대상이 되게 한다.
"""


def ag_node(uid, rules, evidence, support, deps):
    return {'id': uid, 'rules': list(rules), 'evidence': list(evidence),
            'support': support, 'deps': list(deps)}


def ag_find(uid, nodes):
    for n in nodes:
        if n['id'] == uid:
            return n
    return None


def ag_deps_ok(nodes):
    ids = {n['id'] for n in nodes}
    return all(d in ids for n in nodes for d in n['deps'])


def ag_check_deps(nodes):
    return 'ok' if ag_deps_ok(nodes) else ['rejected107', 'ag-deps']


def ag_reach(ids, seen, nodes):
    if not ids:
        return seen
    nid = ids[0]
    if nid in seen:
        return ag_reach(ids[1:], seen, nodes)
    n = ag_find(nid, nodes)
    if n is None:
        return ag_reach(ids[1:], seen, nodes)
    return ag_reach(list(ids[1:]) + list(n['deps']), seen | {nid}, nodes)


def ag_dce(nodes, roots):
    keep = ag_reach(list(roots), set(), nodes)
    return [n for n in nodes if n['id'] in keep]


def ag_dependents(uid, nodes):
    """uid에 (전이적으로) 의존하는 노드 id 집합 — 철회 재검증 대상."""
    rev = {}
    for n in nodes:
        for d in n['deps']:
            rev.setdefault(d, []).append(n['id'])
    out, stack = set(), [uid]
    while stack:
        cur = stack.pop()
        for dn in rev.get(cur, ()):
            if dn not in out:
                out.add(dn)
                stack.append(dn)
    return out
