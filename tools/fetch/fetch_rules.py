#!/usr/bin/env python3
"""웹 수집: Wikipedia 'Phrase structure rules' 에서 재작성 규칙을 추출해 캐시한다."""
import json, re, urllib.parse, urllib.request
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent.parent
CACHE = ROOT / 'cache' / 'rules.json'
PAGES = ['Phrase_structure_rules', 'English_clause_syntax', 'English_grammar']
out = {}
for page in PAGES:
    url = ('https://en.wikipedia.org/w/api.php?action=parse&format=json&prop=wikitext&page='
           + urllib.parse.quote(page))
    req = urllib.request.Request(url, headers={'User-Agent': 'meowdlm-research/0.0044'})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            txt = json.loads(r.read().decode())['parse']['wikitext']['*']
    except Exception as e:
        out[page] = {'error': type(e).__name__, 'rules': []}
        continue
    rules = []
    # 규칙은 <chem>S -> NP \quad VP</chem> 형태로 실려 있다
    for block in re.findall(r'<chem>(.*?)</chem>', txt, re.S):
        raw = block.replace('\\quad', ' ').replace('\\,', ' ')
        raw = re.sub(r'[()\[\]]', '', raw)
        raw = re.sub(r'\s+', ' ', raw).strip()
        m = re.match(r"^([A-Z][A-Za-z0-9]*)\s*(?:->|→|⇒|::=)\s*([A-Za-z0-9' ]+)$", raw)
        if m:
            rhs = m.group(2).split()
            if 1 <= len(rhs) <= 4:
                rules.append((m.group(1), rhs))
    out[page] = {'rules': rules, 'n_wikitext_chars': len(txt)}
CACHE.write_text(json.dumps(out, ensure_ascii=False, indent=1))
for page, v in out.items():
    print(page, 'rules', len(v['rules']), 'error', v.get('error'))
    for r in v['rules'][:6]:
        print('   ', r[0], '->', ' '.join(r[1]))
