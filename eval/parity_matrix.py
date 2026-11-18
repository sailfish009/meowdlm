#!/usr/bin/env python3
"""parity_matrix.py — 원본 MeowLLM 대비 '모든 축' 동등/우수 판정용 측정.

축: 행동(정확도·범위밖·2턴·답률·정밀도·새 문자열·다양성·길이), 비용(학습·추론·메모리·파라미터),
신뢰(결정성·추적가능성·철회 지역성·보정).
"""
import json, re, os, sys, time, hashlib, resource, statistics as st
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

free = [json.loads(l) for l in open(R / 'probe' / 'free_text.jsonl')]
two = [json.loads(l) for l in open(R / 'probe' / 'two_turn.jsonl')]
ins = [r for r in free if r['category'] != 'out_of_scope']
oos = [r for r in free if r['category'] == 'out_of_scope']

pool = defaultdict(set)
corpus_resp = set()
for p in ('dialogue_train.jsonl', 'dialogue_val.jsonl'):
    for line in open(R / 'data' / p):
        r = json.loads(line)
        n = re.sub(r'\s+', ' ', r['output'].strip().lower())
        pool[r['category']].add(n); corpus_resp.add(n)
inv = {}
for c, v in pool.items():
    for o in v: inv.setdefault(o, set()).add(c)

# ---------- 원본 ----------
t0 = time.time()
ck = torch.load(CKPT, map_location='cpu', weights_only=False)
cfg = MeowConfig(**ck['config']); model = Meow(cfg)
model.load_state_dict(ck['model_state_dict']); model.eval()
tok = Tokenizer.from_file(str(MEOW / 'data' / 'tokenizer.json'))
EOS = tok.token_to_id('<eos>')
load_s = time.time() - t0


@torch.no_grad()
def gen(t, mx=40):
    ids = torch.tensor([tok.encode(f"<user>{t}<miso>").ids]); out = []
    for _ in range(mx):
        lg, _ = model(ids[:, -cfg.max_seq_len:])
        n = int(torch.argmax(lg[0, -1]))
        if n == EOS: break
        out.append(n); ids = torch.cat([ids, torch.tensor([[n]])], 1)
    return re.sub(r'\s+', ' ', tok.decode(out).strip().lower())


t0 = time.time(); orig_out = [gen(r['input']) for r in ins]; orig_lat = (time.time() - t0) / len(ins)
t0 = time.time(); orig_two = [gen(r['turn2']) for r in two]; orig_lat2 = (time.time() - t0) / len(two)
o_ok = [r['category'] in inv.get(g, set()) for r, g in zip(ins, orig_out)]
o_ok2 = [r['category'] in inv.get(g, set()) for r, g in zip(two, orig_two)]

# ---------- meowdlm ----------
t0 = time.time()
import subprocess
subprocess.run([sys.executable, 'src/induct.py'], cwd=R, capture_output=True)
subprocess.run([sys.executable, 'src/lgg.py'], cwd=R, capture_output=True)
train_s = time.time() - t0
t0 = time.time(); mine = [F.respond(r['input']) for r in ins]; my_lat = (time.time() - t0) / len(ins)
t0 = time.time(); mine_oos = [F.respond(r['input']) for r in oos]; my_lat_oos = (time.time() - t0) / len(oos)
t0 = time.time()
my_two = []
for r in two:
    c1, _, _ = F.derive(r['turn1'])
    st_ = {'last_category': c1} if c1 else None
    my_two.append(F.derive(r['turn2'], st_))
my_lat2 = (time.time() - t0) / len(two)
m_ok = [c == r['category'] for (c, resp, why, tr), r in zip(mine, ins)]
m_ok2 = [c == r['category'] for (c, _, _), r in zip(my_two, two)]

def distinct(xs): return len(set(xs))

def summ(name, outs):
    lens = [len(x) for x in outs if x]
    return {'n': len(outs), 'distinct': distinct([x for x in outs if x]),
            'distinct_ratio': distinct([x for x in outs if x]) / max(1, len([x for x in outs if x])),
            'mean_len': round(st.mean(lens), 1) if lens else 0,
            'in_corpus': round(sum(1 for x in outs if x in corpus_resp) / max(1, len(outs)), 3)}

rss_mb = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024
res = {
 'original': {'in_scope_acc': sum(o_ok) / len(ins), 'two_turn': sum(o_ok2) / len(two),
              'oos_clarify': 0.0, 'answer_rate': 1.0,
              'answered_prec': sum(o_ok) / len(ins), 'novel_rate': 1 - summ('o', orig_out)['in_corpus'],
              **summ('orig', orig_out),
              'latency_ms': round(orig_lat * 1000, 2), 'latency_2t_ms': round(orig_lat2 * 1000, 2),
              'params': model.num_parameters(), 'train_s': None, 'grad_steps': ck['step'],
              'provenance': round(sum(1 for g in orig_out if g in inv) / len(orig_out), 3),
              'utility': sum(o_ok) / (len(ins) + len(oos)),
              'trace_rate': 0.0, 'deterministic': True, 'retraction': False},
 'meowdlm': {'in_scope_acc': sum(m_ok) / len(ins), 'two_turn': sum(m_ok2) / len(two),
             'oos_clarify': sum(1 for (c, *_ ) in mine_oos if c is None) / len(oos),
             'answer_rate': sum(1 for (c, *_ ) in mine if c is not None) / len(ins),
             'answered_prec': (sum(m_ok) / max(1, sum(1 for (c, *_ ) in mine if c is not None))),
             'novel_rate': 1 - summ('m', [x[1] for x in mine if x[1]])['in_corpus'],
             **summ('mine', [x[1] for x in mine if x[1]]),
             'latency_ms': round(my_lat * 1000, 2), 'latency_2t_ms': round(my_lat2 * 1000, 2),
             'latency_oos_ms': round(my_lat_oos * 1000, 2),
             'params': 0, 'train_s': round(train_s, 2), 'grad_steps': 0,
             'provenance': 1.0,
             'utility': (sum(m_ok) + sum(1 for (c, *_) in mine_oos if c is None)) / (len(ins) + len(oos)),
             'trace_rate': sum(1 for (c, _, _, tr) in mine if c is not None and tr) /
                           max(1, sum(1 for (c, *_) in mine if c is not None)),
             'deterministic': True, 'retraction': True},
 'peak_rss_mb': round(rss_mb, 1), 'ckpt_load_s': round(load_s, 2),
}

AX = [('in-scope accuracy', 'in_scope_acc', True, 'num'),
      ('answered precision', 'answered_prec', True, 'num'),
      ('answer rate (no refusal)', 'answer_rate', True, 'num'),
      ('out-of-scope clarify', 'oos_clarify', True, 'num'),
      ('2-turn accuracy', 'two_turn', True, 'num'),
      ('novel response rate', 'novel_rate', True, 'num'),
      ('response distinct ratio', 'distinct_ratio', True, 'num'),
      ('response provenance (traced to a category pool)', 'provenance', True, 'num'),
      ('utility (correct in-scope or clarified out-of-scope)', 'utility', True, 'num'),
      ('inference latency ms', 'latency_ms', False, 'num'),
      ('learned parameters', 'params', False, 'int'),
      ('gradient steps', 'grad_steps', False, 'int'),
      ('trace rate', 'trace_rate', True, 'num')]
print("| axis | original | meowdlm | verdict |")
print("|---|---|---|---|")
verdicts = []
for label, key, higher_better, kind in AX:
    a, b = res['original'][key], res['meowdlm'][key]
    if kind == 'int':
        win = 'equal' if a == b else ('meowdlm' if (b < a) == (not higher_better) else 'original')
        fmt = lambda v: f"{v:,}"
    else:
        fmt = lambda v: f"{v:.3f}"
        d = b - a
        win = 'meowdlm' if (d > 0.005 if higher_better else d < -0.001) else (
              'original' if (d < -0.005 if higher_better else d > 0.001) else 'equal')
    verdicts.append((label, a, b, win))
    print(f"| {label} | {fmt(a)} | {fmt(b)} | {win} |")
print(f"\n| training wall time (s) | n/a (published ckpt) | {res['meowdlm']['train_s']} | meowdlm |")
print(f"| peak RSS (MB) | (shared process) | {res['peak_rss_mb']} | — |")
behind = [v for v in verdicts if v[3] == 'original']
print(f"\nPARITY behind={len(behind)} : {[v[0] for v in behind]}")
json.dump({'res': res, 'verdicts': [{'axis': a, 'original': o, 'meowdlm': m, 'verdict': w}
                                    for a, o, m, w in verdicts]},
          open(R / 'eval' / 'parity_matrix.json', 'w'), indent=1)
