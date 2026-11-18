# meowdlm_v0.0005 — BACKUP 재료 이식: 변수 추상화 + 정렬 채택(LGG) → 원본 비교

## 무엇을 가져왔나 (출처 명시)

| 출처 | 메커니즘 | 이식 |
|---|---|---|
| `BACKUP/dlm_v0.0110/src/dlm/d107-learn.l:22` `p107-abstract-atoms` | "structure, not content": 서로 다른 상수를 변수로 | `src/lgg.py: abstract` |
| `BACKUP/dlm_v0.0110/src/dlm/d107-learn.l:30-64` `p107-patterns2/3`, `p107-align-subset` | 쌍/삼중에서 패턴 생성, 채택은 점수가 아니라 **정렬 검사**, 지지는 **서로 다른 기록 수** | `src/lgg.py: induce` |
| `BACKUP/dlm_v0.0017/dlm/deductive.py:626` `lgg_atoms` | 열 단위 LGG, 같은 항 튜플은 같은 변수(대응 보존) | `src/lgg.py: lgg_pair, lgg_of` |
| `BACKUP/dlm_v0.0031/dlm/galois.py:1-40` | LGG ⊣ 폐쇄 수반: "p가 S를 덮음 ⟺ p ≥ LGG(S)", 과잉일반화 반례 | `src/lgg.py: verify_adjunction` |

학습 결과:

```text
LGG records=7000 admitted=24 rejected=44
reject_reasons: negative-coverage 44      ← 타범주 기록을 덮는 패턴은 즉시 기각
수반 법칙: 채택 24개 전부 verify_adjunction 통과(반례 0)
범주 분포: boxes 4, greeting 4, jealousy/territory/dogs/hunger/rain/vacuum 2, 나머지 1
```

## 4-arm (같은 프로브: 자유 발화 150 + 범위 밖 20)

| arm | derived_cov | derived_prec | free_act | oos | over_abst | 2턴 | LGG 발화 |
|---|---|---|---|---|---|---|---|
| `sum` (0.0004 대조) | 0.640 | 0.760 | 0.487 | 0.650 | 0.360 | 0.520 | 0 |
| `priority` LGG off | 0.720 | 0.722 | 0.520 | 0.650 | 0.280 | 0.620 | 0 |
| **`priority` + LGG on** | 0.733 | **0.764** | **0.560** | 0.650 | **0.267** | 0.600 | 15 |
| `allvals` | 0.620 | 0.731 | 0.453 | 0.650 | 0.380 | 0.160 | 0 |

```text
쌍대 비교(McNemar exact):
  LGG off → on          이전만맞음 0 / LGG만맞음 6   p=0.0312  ★유의
  sum → priority+LGG    sum만 10 / priority+LGG만 21 p=0.0708  경계
  sum → allvals         sum만 17 / allvals만 12      p=0.4583  귀무
```

**LGG 계층은 통계적으로 유의합니다**(6:0, p=0.0312). derived 정밀도도 0.722 → 0.764로 올라갑니다.

## 위험-커버리지 (같은 coverage에서 정밀도)

| arm | cov 0.50 | 0.60 | 0.70 | 0.80 | 1.00 |
|---|---|---|---|---|---|
| sum | **0.747** | 0.678 | 0.648 | 0.583 | 0.487 |
| priority (LGG off) | **0.760** | 0.711 | 0.714 | 0.650 | 0.520 |
| priority + LGG | 0.707 | 0.711 | **0.752** | **0.700** | **0.560** |
| allvals | 0.733 | 0.733 | 0.648 | 0.567 | 0.453 |

LGG 계층은 **높은 정밀도 구간(cov 0.50)에서 순위를 조금 해칩니다**(0.760 → 0.707). LGG 패턴 15건이
최상위 신뢰도로 올라가면서 그보다 확실한 기존 판정을 밀어내기 때문입니다. cov 0.60 이상에서는
LGG가 우세합니다(0.752 / 0.700). 즉 이득은 **커버리지를 넓히는 방향**이고, 최상위 신뢰도 정렬은
아직 개선 여지가 있습니다.

## 원본 MeowLLM과의 비교 (원본은 자기 체크포인트 사용)

```text
체크포인트  /research/meowdlm/baseline/meow_orig/best.pt (sha256 0b80e132…c1327)
            step=2000, best_val=0.430, params=3,447,552
디코딩      greedy(argmax), <user>…<miso>, 원본 BPE(vocab 1682)
```

| 경로 | 학습 | 파라미터 | free_act | 범위 밖 | 2턴 |
|---|---|---|---|---|---|
| 원본 MeowLLM (자기 ckpt) | gradient 2000 step | 3,447,552 | 0.467 (70/150) | 0.000 (0/20) | — |
| **meowdlm_v0.0005** | 공리 197 + LGG 24, **gradient 0** | 0 | **0.560** (84/150) | **0.650** (13/20) | 0.600 |

```text
McNemar: meowdlm만 33 / 원본만 19  p=0.0704  (경계 — 유의하지 않음)
판정 분포: derived 95, lgg 15, no_evidence 26, unknown 14
```

정직하게: **10문항 우세(+9.3pp)지만 p=0.0704로 유의 수준에 못 미칩니다.** 범위 밖 처리는 0.000 → 0.650으로
크게 벌어집니다(원본은 "모른다"를 한 번도 못 냄).

## 왜 LGG가 효과가 있었나 (반증 검토)

- 0.0003의 손수 만든 gap 패턴은 채택 기준이 순도 임계값이었고, 생성 14,756개 중 194개만 남아 OOV 흡수율이 0%였습니다.
- 이번 LGG는 **서로 다른 기록 수로 지지를 세고, 정렬·음성커버리지·수반 법칙으로 채택**합니다. 채택된 24개는
  전부 타범주 커버리지 0이고, 프로브 발화 15건 전부 정답입니다.
- 대안 가설(검증됨): 개선이 "패턴 수가 많아서"라는 설명은 성립하지 않습니다. LGG off 대비 on의 차이는
  6문항이고, 그 6문항은 모두 LGG 계층에서만 나온 판정입니다.

## 남는 한계

- LGG 패턴은 같은 길이 기록 쌍에서만 나오므로 프로브 발화율이 10%(15/150)입니다. 커버리지 상한이 구조적으로 낮습니다.
- 2턴 0.600은 0.0004의 0.520보다 좋아졌지만 여전히 단일턴 수준에 못 미칩니다.
- 원본과의 비교는 공개 체크포인트 1개(step 2000) 조건입니다.

## 게이트 (`V0005`)

```text
LGG        재현 결정적 + 채택 24 + 기각 사유 기록
ADJUNCTION 채택 패턴 전부 "p가 S를 덮음 ⟺ p ≥ LGG(S)" 통과(반례 0)
ARMS       4-arm 표 + LGG on/off 유의성(p<0.05) 단정
ORIGINAL   체크포인트 해시 검증 후 같은 프로브 비교 + McNemar p 기록
STRUCT     0.0002 구조 테스트·철회 지역성 유지
V0005-MEOWDLM-LGG-PASS
```
