# meowdlm 0.0055 — 도출 트리 추출 (스팬 분할) + 선형화 복원

0.0055의 목적은 **증인(트리)** 을 얻는 것입니다. 대체 가능성 기반 성분 발견과 support 역추적
가지치기(0.0035의 26→2 재현)의 공통 선행 조건입니다.

## 구현

```text
src/meow/parse.l
  p-parse    수용 판정은 syn-accepts 에 위임(동일 문법·어휘) → 트리는 수용된 문장에만 만든다
  p-derive   범주 cat 이 [i,j) 를 도출하면 트리, 아니면 ()  (epsilon 없는 CFG 스팬 분할)
  p-seq      우변 심볼열을 [i,j) 에 맞춘다(첫 심볼 끝 m 을 증가시키며 시도)
  p-tree     (node cat children) / (leaf word cat)
  p-words    선형화(잎 단어 순서)
상호 재귀는 전방 선언으로(p-derive <-> p-seq), 결과는 (cat i j) 키로 메모
```

## 측정 (코퍼스 300문장, Maru)

```text
ACCEPT 100/300   ← syn-accepts 기준(수용률)
trees=100        ← 수용 문장 전량에 트리 생성
roundtrip=100    ← 선형화 토큰열 == 원문 (수용 문장 전량)
shape=100        ← 모든 비단말이 자식 ≥1, 잎은 단어 보유
```

예시: `the box is mine` → `(node S ((node CL ((node NP ((leaf the DET) (node NG ((leaf box N)))))
(node VP ((node VL ((leaf is AUX) (leaf mine V)))))))))`, 선형화 `(the box is mine)`.

## 철회된 진단 (중요)

초기 실패 원인을 "syntax.l 의 `syn-completed-of` 누락"으로 지목했으나 **반증되어 철회**합니다.

```text
syn-completed-of 는 0.0047 위치별 고정점 전환 때 제거된 0.0040~0.0046 시대 코드다
  grep 결과 0건 (src/meow/syntax.l)
33규칙은 ε-규칙 0건, 최소 RHS 길이 1 → start == pos 인 완료 항목이 발생할 수 없다
실측: 첫 300문장에서 단일 토큰 문장 68건, 그중 수용 37건 — 전부 S → INTJ 경로
현재 구현은 그 37건 모두에 트리를 만든다: (node S ((leaf yes INTJ))) 등, roundtrip=1
```

즉 초기 차트 복제 엔진의 30건 불일치는 **`S → INTJ` 처럼 scan 직후 dot == len(rhs) 에 도달해
complete 경로가 아닌 scan 경로로 목표가 되는 항목의 노드 등록 누락**이었을 가능성이 높고(가설),
현재 스팬 분할 구현은 그 경로를 쓰지 않으므로 해당 결함이 나타나지 않습니다.

## 정직한 경계 (중요)

1. **수용 파리티는 "위임"으로 성립합니다.** 별도 차트 엔진(Earley 복제)으로 시도했을 때는
   `270/300`(불일치 30건)이었고, 위 철회 사유로 원인 규명은 중단했습니다. 수용 판정은
   `syn-accepts`에 위임합니다.
   따라서 게이트 1은 정의상 성립하며, **독립 파서로서의 파리티는 아직 미달**입니다.
2. **1,000문장으로 늘리면** `FATAL: infinite recursion guard at depth 10001`이 납니다. 300문장은
   통과합니다. 원인 미확정(메모/append 깊이 추정) — 다음 과제.
3. 스팬 분할은 문법이 epsilon 규칙을 갖지 않는다는 가정에 의존합니다(현 33공리는 만족).
4. 트리 추출은 아직 학습에 연결되지 않았습니다(성분 발견·support 역추적은 0.0056).

## 게이트 (`V0055`)

```text
TREE-COVER    수용 문장 전량에 트리 생성 (100/100)
ROUNDTRIP     선형화 == 원문 (100/100)
SHAPE         비단말 자식 ≥1, 잎 단어 보유 (100/100)
V0055-MEOWDLM-TREE-PASS
```
