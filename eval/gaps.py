#!/usr/bin/env python3
"""원본 대비 meowdlm의 부족 지점을 측정한다(카테고리별, 되묻기 구간, 2턴, 새 문자열 생성)."""
import json, re, sys, os
from collections import Counter, defaultdict
from pathlib import Path
R = Path(__file__).resolve().parent.parent
MEOW = Path('/research/MeowLLM')
CKPT = Path('/research/meowdlm_orig/baseline/meow_orig/best.pt')
sys.path.insert(0, str(MEOW)); sys.path.insert(0, str(R / 'src'))
os.environ.setdefault('DECISION', 'priority'); os.environ.setdefault('LGG', '1')
import torch
from meow.model import Meow, MeowConfig
from tokenizers import Tokenizer
import infer as F

ck = torch.load(CKPT, map_location='cpu', weights_only=False)
cfg = MeowConfig(**ck['config']); model = Meow(cfg)
model.load_state_dict(ck['model_state_dict']); model.eval()
tok = Tokenizer.from_file(str(MEOW / 'data' / 'tokenizer.json'))
EOS = tok.token_to_id('<eos>')

@torch.no_grad()
def gen(t, mx=40):
    ids = torch.tensor([tok.encode(f"<user>{t}<miso>").ids]); out = []
    for _ in range(mx):
        lg, _ = model(ids[:, -cfg.max_seq_len:])
        n = int(torch.argmax(lg[0, -1]))
        if n == EOS: break
        out.append(n); ids = torch.cat([ids, torch.tensor([[n]])], 1)
    return re.sub(r'\s+', ' ', tok.decode(out).strip().lower())

pool = defaultdict(set)
for p in ('dialogue_train.jsonl', 'dialogue_val.jsonl'):
    for line in open(R / 'data' / p):
        r = json.loads(line)
        pool[r['category']].add(re.sub(r'\s+', ' ', r['output'].strip().lower()))
inv = {}
for c, v in pool.items():
    for o in v: inv.setdefault(o, set()).add(c)
all_resp = set().union(*pool.values())

free = [json.loads(l) for l in open(R / 'probe' / 'free_text.jsonl')]
two = [json.loads(l) for l in open(R / 'probe' / 'two_turn.jsonl')]
ins = [r for r in free if r['category'] != 'out_of_scope']

per = defaultdict(lambda: [0, 0, 0])       # n, mine, orig
abstain_items = []
orig_only_items = []
novel = 0
for r in ins:
    c, resp, why, _ = F.respond(r['input'])
    g = gen(r['input'])
    mine_ok = (c == r['category'])
    orig_ok = r['category'] in inv.get(g, set())
    novel += (g not in all_resp)
    p = per[r['category']]; p[0] += 1; p[1] += mine_ok; p[2] += orig_ok
    if not mine_ok and orig_ok: orig_only_items.append((r['input'], r['category'], g, why))
    if c is None: abstain_items.append((r['input'], r['category'], orig_ok, why))

print("== 카테고리별 (meowdlm / 원본)")
rows = sorted(per.items(), key=lambda kv: kv[1][1] - kv[1][2])
for cat, (n, m, o) in rows:
    flag = '  ← 원본 우세' if o > m else ''
    print(f"  {cat:20s} n={n:2d}  mine={m:2d}  orig={o:2d}{flag}")
print(f"  원본이 더 맞힌 카테고리: {sum(1 for _, (n,m,o) in rows if o>m)}/{len(rows)}")

print(f"\n== 되묻기 구간 (meowdlm이 답하지 않은 {len(abstain_items)}건)")
ab_orig = sum(1 for _, _, o, _ in abstain_items if o)
if abstain_items:
    print(f"  원본 정답 = {ab_orig}/{len(abstain_items)} = {ab_orig/len(abstain_items):.3f}")
else:
    print("  되묻기 0건 (항상 답하는 구성)")
print(f"  사유 분포 = {dict(Counter(w for *_, w in abstain_items))}")

print(f"\n== 원본만 맞힌 항목 {len(orig_only_items)}건 (샘플 6)")
for x in orig_only_items[:6]:
    print(f"  {x[0]!r:38s} gold={x[1]:18s} orig={x[2][:42]!r} mine={x[3]}")

print(f"\n== 새 문자열 생성 (코퍼스 응답 풀 밖)")
my_novel = sum(1 for (c, resp, w, _), r in zip(
    [F.respond(x['input']) for x in ins], ins) if resp and resp not in all_resp)
print(f"  원본 = {novel}/{len(ins)} = {novel/len(ins):.3f}")
print(f"  meowdlm = {my_novel}/{len(ins)} = {my_novel/len(ins):.3f}")

print(f"\n== 2턴 (원본은 상태 없이 turn2만 입력)")
ok_o = 0
for r in two:
    g = gen(r['turn2'])
    ok_o += r['category'] in inv.get(g, set())
c1s, ok_m = 0, 0
for r in two:
    c1, _, _ = F.derive(r['turn1'])
    st = {'last_category': c1} if c1 else None
    c2, _, _ = F.derive(r['turn2'], st)
    ok_m += (c2 == r['category'])
print(f"  meowdlm = {ok_m}/50 = {ok_m/50:.3f}   원본(turn2 단독) = {ok_o}/50 = {ok_o/50:.3f}")
json.dump({'per_cat': {k: {'n': v[0], 'mine': v[1], 'orig': v[2]} for k, v in per.items()},
           'abstain': {'n': len(abstain_items), 'orig_correct': ab_orig},
           'orig_only': len(orig_only_items),
           'novel': novel / len(ins), 'two_turn': {'mine': ok_m / 50, 'orig': ok_o / 50}},
          open(R / 'eval' / 'gaps.json', 'w'), indent=1)
