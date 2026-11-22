#!/usr/bin/env python3
"""웹 수집(파이썬 허용 영역): 사전 API 에서 품사·표제어를 받아 캐시한다.

소스: https://api.dictionaryapi.dev (무료, 키 불필요)
캐시: cache/pos.json — 재실행 시 네트워크 없이 재현 가능
"""
import json, sys, time, urllib.request
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent.parent
M = Path('/research/meowdlm_v0.0039')
sys.path.insert(0, str(M / 'src'))
import induct as I
from collections import Counter

CACHE = ROOT / 'cache' / 'pos.json'
cnt = Counter()
for f in ('dialogue_train.jsonl', 'dialogue_val.jsonl'):
    for line in open(M / 'data' / f):
        r = json.loads(line)
        for k in ('input', 'output'):
            cnt.update(I.tokens(r.get(k, '')))
words = sorted(cnt)
cache = json.loads(CACHE.read_text()) if CACHE.exists() else {}
todo = [w for w in words if w not in cache]
print(f"vocab {len(words)} cached {len(cache)} todo {len(todo)}")
for i, w in enumerate(todo):
    url = f"https://api.dictionaryapi.dev/api/v2/entries/en/{urllib.parse.quote(w)}"
    try:
        req = urllib.request.Request(url, headers={
            'User-Agent': 'meowdlm-research/0.0044 (grammar data fetch; contact: local)',
            'Accept': 'application/json'})
        with urllib.request.urlopen(req, timeout=10) as r:
            data = json.loads(r.read().decode())
        pos = sorted({m.get('partOfSpeech') for e in data for m in e.get('meanings', []) if m.get('partOfSpeech')})
        lem = sorted({e.get('word', '') for e in data if e.get('word')})
        cache[w] = {'pos': pos, 'lemma': lem}
    except Exception as e:
        cache[w] = {'pos': [], 'error': type(e).__name__}
    if i % 50 == 0:
        CACHE.write_text(json.dumps(cache, ensure_ascii=False, sort_keys=True))
        print(f"  {i}/{len(todo)}", flush=True)
    time.sleep(0.12)
CACHE.write_text(json.dumps(cache, ensure_ascii=False, sort_keys=True))
ok = sum(1 for v in cache.values() if v.get('pos'))
print(f"수집 완료: {len(cache)} 단어, 품사 있음 {ok}")
