# meowdlm_v0.0002 — DLM 0.0284 방법론을 이식한 연역학습 대화 모델

## 무엇을 가져왔나 (방법론 → 모듈)

| DLM 0.0284 소스 | 메커니즘 | meowdlm_v0.0002 |
|---|---|---|
| `src/dlm/basis.l` (b-axiom, b-set-status, b-activate, b-deactivate, b-rollback, b-cse) | 버전 있는 기저 공리, active 상태에서만 사용, 상태 변경 시 version+1·history 기록, 롤백, 중복 공리 병합 | `src/basis.py` |
| `src/dlm/axiom-graph.l` (ag-node, ag-deps, ag-check-deps, ag-reach, ag-dce, ag-cse-maps) | 공리 간 의존 그래프, 후방 도달, DCE, 의존 검사 | `src/axiomgraph.py` |
| `src/dlm/deduce.l` (d-select, d-eval, d-covered) | 커버리지 최대화 + 음성 커버리지(conflict) 최소화로 공리 부분집합 선택 | `src/induct.py` 채택 검사 |
| `src/dlm/proof.l` (p-derive, p-child-ids) | 증거까지 추적되는 도출(proof-carrying) | `src/infer.py` trace |
| 불완전 경계(0.0288 계열 incomplete107) | 증거 부족과 증거 충돌을 구분 | `abstain:no_evidence` / `abstain:insufficient` / `abstain:unknown` |

## 학습 (gradient 0)

```text
1) 기록      data/dialogue_{train,val}.jsonl (7,000행)
2) 단서      내용어 1·2·3gram + 철자 정규화(어미 제거·중복자음 축약)
             + 응답 텍스트의 단서(응답도 같은 코퍼스의 증거)
3) 후보 단위 (단서 → 범주): 지지 기록 ≥1, 순도 ≥0.5 (엄격층 순도 1.0 / 방어가능층 0.5~1.0)
4) 채택 검사 d-select: 범주 양성 커버리지를 늘리고 음성 커버리지를 예산 이하로 유지
5) 의존 간선 같은 단서를 공유하는 타범주 단위와 연결(철회 시 재검증 경로)
6) 공리 저장 basis.json: 198개 단위 + 15개 범주 정의(외연: 범주별 단서 집합 + IDF)
```

## 추론

```text
입력 → 단서 → (a) 단위 발화 점수  (b) 범주 정의(외연) 커버리지
     → 후보 정렬 → margin / unknown_ratio 로 판정
     → derived | insufficient | no_evidence | unknown
     → 응답은 도출된 범주의 admitted pool 에서만 선택(보존)
```

## 결과 (같은 프로브: 자유 발화 150 + 범위 밖 20)

| 경로 | 학습 | free_act | oos_clarify | over_abstain | two_turn |
|---|---|---|---|---|---|
| 원본 MeowLLM (자기 ckpt, gradient 2000 step) | gradient | 0.453 | 0.000 | 0.000 | — |
| meowdlm 0.0292 (사전 포함) | 공리 771 + 큐레이션 사전 100여 항목 | 0.713 | 0.900 | 0.180 | 0.480 |
| meowdlm 0.0292 (사전 제거 = 데이터만) | 공리 771 | 0.487 | 0.900 | 0.427 | 0.380 |
| **meowdlm_v0.0002 (DLM 0.0284 구조)** | 단위 198 + 정의 15 | **0.487** | **0.650** | **0.360** | **0.520** |

판정 요약: v0.0002는 **원본을 두 지표 모두에서 넘고**(+3.4pp / +65pp), 2턴은 이전 최고(0.480)보다 높습니다.
그러나 0.0292의 사전 포함 수치(0.713)에는 미달합니다.

## 발견 1 — 0.713의 상당 부분은 프로브에서 만든 사전이었다

```text
0.0292 사전 포함   0.713
0.0292 사전 제거   0.487   (Δ -22.6pp)
```

사전 항목 상당수는 0.0290에서 **프로브 실패 단어를 보고** 추가한 것입니다(테스트 조정).
v0.0002는 그 사전을 쓰지 않고, 코퍼스에서 유도한 구조만 씁니다. 그 조건의 정직한 값은 0.487입니다.

## 발견 2 — DLM 구조가 사는 것은 정확도가 아니라 강제성

| 검사 | 결과 |
|---|---|
| 공리 active 상태에서만 추론 | PASS (inactive 단위 발화 0) |
| 의존 그래프 완결성 `ag-check-deps` | ok (427 노드) |
| DCE(roots 도달 유지) | PASS |
| CSE 중복 병합 | PASS |
| 철회 지역성: `dogs` 철회 → dogs 0.200→0.000, 나머지 14범주 Δ=0.000 | PASS |
| 답 보존: 도출 범주 pool 밖 응답 0건 | PASS |

철회 실험은 정확도를 올리지 않지만, **증거를 빼면 그 증거에 의존하는 정의만 무효화되고 나머지는
그대로**라는 성질을 측정 가능하게 만듭니다. gradient 모델에는 이 단위의 개입이 없습니다.

## 한계

- 프로브 토큰의 27%가 코퍼스 어휘 밖입니다. 표면 일치 계열의 상한이 여기서 결정됩니다.
- 임계값은 dev(A)에서 골랐고 test(B)에서 0.425 / 0.700이 나옵니다(A는 0.557). 반분할 간 난이도 차가 큽니다.
- 범주 정의(외연)는 IDF 가중 커버리지라 어휘 중첩이 낮은 범주(`dogs`, `territory`)에서 약합니다.
