# data/ — 무엇이 소스이고 무엇이 생성물인가

## 소스로 취급(재생성 스크립트 없음)

| 파일 | 내용 |
|---|---|
| `facts.l` | 커널 사실 28건 (0.0040에서 손으로 내보냄) |
| `queries.l` | 판정 증인 질의 20건 |
| `classes.l` | 폐쇄류 클래스 목록 |
| `probe.l`, `probe_cues.*` | 프로브 170건과 그 단서(파이썬 참조 산출, 벤더링) |
| `ood_new.l`, `oov_rows.json` | 신규 OOD 20건·OOV 목록(0.0053) |
| `syntax_*.l` | 유도 어휘·33공리·코퍼스 표본 (원천 dlm_v0.0285 는 폐기됨) |

## 도구로 재생성 가능

| 파일 | 생성 |
|---|---|
| `evidence.l`, `ev.l`, `idf.l`, `vocab.l` | `tools/export_evidence.py` |
| `oov_vocab.l` | `tools/export_oov.py` |
| `surface_frames.l`, `surface_slots.l`, `surface_cats.l` | `tools/export_surface.py` |
| `web_pos.l`, `web_rules.l` | `tools/export_web.py` (← `cache/pos.json`, `cache/rules.json` ← `tools/fetch/*.py`) |
| `lexfeat_data.l` | 0.0052 내장 생성 스크립트(문서 참조) |

`tools/*.py` 는 데이터 변환기이며, 모델 로직은 `src/meow/*.l`(Maru) 에만 있습니다.
