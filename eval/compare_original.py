#!/usr/bin/env python3
"""원본 MeowLLM(자기 체크포인트) vs meowdlm_v0.0005(연역) 같은 프로브 비교.

원본 체크포인트는 **원본 자신의 측정에만** 쓰인다(meowdlm 학습·추론 경로는 열지 않는다).
"""
import json, re, sys, os
from pathlib import Path
R = Path(__file__).resolve().parent.parent
MEOW = Path('/research/MeowLLM')
CKPT = Path('/research/meowdlm_orig/baseline/meow_orig/best.pt')
sys.path.insert(0, str(MEOW))
sys.path.insert(0, str(R / 'src'))
import torch
from meow.model import Meow, MeowConfig
from tokenizers import Tokenizer

free = [json.loads(l) for l in open(R / 'probe' / 'free_text.jsonl')]
ins = [r for r in free if r['category'] != 'out_of_scope']
oos = [r for r in free if r['category'] == 'out_of_scope']

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


pool = {}
for p in ('dialogue_train.jsonl', 'dialogue_val.jsonl'):
    for line in open(R / 'data' / p):
        r = json.loads(line)
        pool.setdefault(r['category'], set()).add(re.sub(r'\s+', ' ', r['output'].strip().lower()))
inv = {}
for c, v in pool.items():
    for o in v: inv.setdefault(o, set()).add(c)

orig_correct = {}
for r in ins:
    g = gen(r['input'])
    orig_correct[r['input']] = r['category'] in inv.get(g, set())
oos_handled = 0
for r in oos:
    g = gen(r['input'])
    if re.search(r"do not know|not know this|is it (food|a snake)", g): oos_handled += 1

# meowdlm 쪽
for kv in ('DECISION=priority', 'LGG=1'):
    k, v = kv.split('='); os.environ.setdefault(k, v)
import importlib, infer as F
assert F.LGG_ON
mine = {}
for r in ins:
    c, _, _ = F.derive(r['input'])
    mine[r['input']] = (c == r['category'])
my_oos = sum(1 for r in oos if F.derive(r['input'])[0] is None)
reasons = {}
for r in ins:
    _, why, _ = F.derive(r['input'])
    reasons[why] = reasons.get(why, 0) + 1

n = len(ins)
o = sum(orig_correct.values()); m = sum(mine.values())
def mcnemar(x, y):
    b = sum(1 for k in x if x[k] and not y.get(k)); c = sum(1 for k in x if not x[k] and y.get(k))
    nn = b + c
    if nn == 0: return b, c, 1.0
    from math import comb
    kk = min(b, c)
    return b, c, min(1.0, 2 * sum(comb(nn, i) for i in range(kk + 1)) / 2 ** nn)
b, c, p = mcnemar(mine, orig_correct)

print("| 경로 | 학습 | 파라미터 | free_act | 범위밖 | 2턴 |")
print("|---|---|---|---|---|---|")
print(f"| 원본 MeowLLM (자기 ckpt) | gradient {ck['step']} step | {model.num_parameters():,} | "
      f"{o/n:.3f} ({o}/{n}) | {oos_handled/len(oos):.3f} ({oos_handled}/{len(oos)}) | — |")
print(f"| **meowdlm_v0.0005 (연역)** | 공리 197 + LGG 24, gradient 0 | 0 | "
      f"**{m/n:.3f}** ({m}/{n}) | **{my_oos/len(oos):.3f}** ({my_oos}/{len(oos)}) | 0.600 |")
print(f"\nMCNEMAR meowdlm만맞음={b} 원본만맞음={c} p={p:.4f} {'유의' if p < 0.05 else '유의하지 않음'}")
print(f"MINE 판정 분포 {reasons}")
json.dump({'orig_free': o / n, 'mine_free': m / n, 'orig_oos': oos_handled / len(oos),
           'mine_oos': my_oos / len(oos), 'mcnemar': {'mine_only': b, 'orig_only': c, 'p': p},
           'orig_params': model.num_parameters(), 'orig_step': ck['step'],
           'reasons': reasons, 'n': n},
          open(R / 'eval' / 'vs_original.json', 'w'), indent=1)
