# /research/BACKUP 재료 탐색 — meowdlm 개선용

## 방법 (중단 없이 끝까지)

전체 29GB, 소스 파일 36,396개(`*.py` 8,965 + `*.l` 28,091은 아님이 아니라 대부분 vendor 중복).
내용 해시로 중복 제거 → **고유 소스 2,515개**. 11개 키워드 가족으로 스캔해 파일별 적중을
`index.jsonl`에 기록(2분 이내 완료). 도구: `index.py`, 결과: `index.jsonl`, 검증: `lgg_probe.py`.

```text
files=36396  unique_contents=2515  (vendor/maru 런타임이 278회 중복)
hits_by_family = definition 1111, incomplete 977, nondet 633, evidence 561,
                 canon 548, fold 508, learn 360, basis 313, retract 289,
                 conserv 157, lexicon 79
```

## 재료 후보 (근거: 파일:줄)

| # | 출처 | 메커니즘 | meowdlm에 주는 것 |
|---|---|---|---|
| **1** | `dlm_v0.0110/src/dlm/d107-learn.l:22` `p107-abstract-atoms` | *"structure, not content: each distinct constant becomes a variable"* — 기록의 서로 다른 상수를 변수로 | 어휘가 다른 발화를 같은 도식으로 묶는 **변수 추상화** (0.0003의 수작업 gap 패턴을 대체) |
| **2** | `dlm_v0.0110/src/dlm/d107-learn.l:30-64` `p107-patterns2/3` + `p107-align-subset` | 쌍/삼중 기록에서 패턴 생성, **정렬 검사**로 채택(점수 아님), 지지는 서로 다른 기록 수 | 채택 기준을 purity 임계값에서 **검사된 동등성**으로 교체 |
| **3** | `dlm_v0.0017/dlm/deductive.py:626` `lgg_atoms` | 열 단위 LGG: 같은 항 튜플은 같은 변수 → **대응(link) 보존** | 반복어 관계를 보존하는 일반화 |
| **4** | `dlm_v0.0031/dlm/galois.py:1-40` + `experiments/galois/run.py` | LGG와 폐쇄의 **수반(adjunction)**: "p가 S를 덮음 ⟺ p가 LGG(S)보다 일반적". 과잉일반화 반례를 커널이 제시 | 채택된 패턴이 **과잉일반화인지 커널이 증거로 판정** |
| **5** | `dlm_v0.0009/dlm/lexicon.py:1-30` | 표제어 제안기 + **사전 멤버십 게이트**(제안은 하되 발명하지 않음) | 형태 정규화 제안/게이트 구조 |
| **6** | `dlm_v0.0001/dlm/generalize.py:20-45` | ILP: 최단 Horn 규칙 탐색 + `covers(pos, neg)` 검사 | 채택 검사의 원형(양성 덮기·음성 안 덮기) |
| 7 | `dlm_v0.0036/dlm/reify.py` (canon 35) | 순서 접기·정책 사실 병합 | 응답 선택 순서 규칙 |
| 8 | `dlm_v0.0032/dlm/axioms.py` (canon 31) | 공리 저장소 정규화 | 공리 키 정규화 |

## 즉시 검증한 재료 — 1·2·3번(구조 추상화 + 정렬 채택)

meowdlm 코퍼스(7,000 기록)에 그대로 적용:

```text
LGG candidates=68           (같은 길이·같은 범주 기록 쌍에서 유도)
admitted patterns=24        (지지 ≥2 기록, 타범주 커버리지 0)
train coverage=2038/7000=0.291
probe fired=15/150          precision=1.000  (15/15 정답)
```

현재 v0.0004(우선순위 arm) 판정과 대조:

```text
LGG 정답 & 현재 오답/되묻기 = 7   ← 순이득 후보 (+4.7pp)
LGG 정답 & 현재 정답        = 8
LGG 오답                    = 0
```

발화 예: `big dog coming` → 현재 `nonsense_questions` 오답, LGG는 `dogs`.
`hello again kitty` → 현재 `ambiguous` 되묻기, LGG는 `greeting`.
`another dog in the park` → 현재 `ambiguous`, LGG는 `dogs`.

**프로브 어휘를 쓰지 않고** 코퍼스 구조만으로 얻은 패턴이 100% 정밀도로 15건에 발화합니다.

## 다음 (v0.0005 설계)

```text
1) 1·2·3번 이식: 변수 추상화 + 정렬 채택을 증거 계층의 최상위 인스턴스로 등록
   (Rocq 우선순위 -1, strict=0 보다 강함). 지지는 서로 다른 기록 수로 센다.
2) 4번으로 채택 검증: 패턴이 덮는 기록 집합에 대해 커널 폐쇄가 재현되는지 확인,
   과잉일반화 반례(타범주 기록을 덮는 경우)는 즉시 기각.
3) 기대: free_act 0.487 → 약 0.53, oos 유지. 위험: 패턴 24개는 커버리지 29%로 좁고,
   학습 기록 쌍에서만 나오므로 프로브 발화율 10%(15/150)가 상한.
4) 4번의 수반 법칙을 게이트로: "p가 S를 덮음 ⟺ p ≥ LGG(S)" 를 meowdlm 데이터에서 검증.
```

## 재현

```bash
cd /research/backup-survey
python3 index.py        # 2분, index.jsonl 생성
python3 lgg_probe.py    # 재료 검증(위 수치)
```
