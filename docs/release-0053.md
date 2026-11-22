# meowdlm 0.0053 — 적대적 반례 21/21 교정 + OOD 단서 적중률 게이트(신규 프로브로 일반화 검증)

## ① lexfeat.l 적대적 반례 교정 (0.0052 지적)

| 입력 | 0.0052 | 0.0053 | 원인 코드 |
|---|---|---|---|
| you sleep / it sleeps | 오거부 | **수용** | 격 `-1`(무관) 통일 누락 → 허용 |
| i is big / he am big | 오수용 | **거부** | COP 인칭 검사 추가 (`cop-agr`) |
| the cat is | 오수용 | **거부** | 보어 존재 검사 (`no-complement`) |
| the cat is sleep dogs cat | 오수용 | **거부** | 보어 범주 검사 (`comp-cat`) |
| the cat sleeps dog dog dog | 오수용 | **거부** | 자동사 종단 검사 (`trailing`) |
| the cat chases a dogs | 오수용 | **거부** | 목적어 DET+N 수 일치 (`obj-det-n-agree`) |
| the cat chases the | 오수용 | **거부** | 목적어 명사 누락 (`no-obj-noun`) |

기존 증인 8건 포함 **21/21 정답**. `lf-form-bad?`의 중복 조건과 `lf-check-np-subj` 경계 검사도 고쳤습니다.

## ② state.l 잔여 결함

- `(define b 0)` 전역 → **let 로컬**로 격리(전역 오염 제거)
- `st-load`가 **pointer 결손 시 `reject-nopointer`** 반환(프로세스 종료 없음)
- 재직렬화 검증은 *st-rules*만 수행, 저널 검증·tmp 정리는 **미완(0.0054 이월)**

## ③ tools/sx.py 따옴표 보존

`'(1 2)`가 `' (1 2)`로 변형되던 문제를 수정하고 자체 테스트에 고정했습니다.
정렬(sort)은 문자열·주석 인식 + define/define-function 통합 위상 정렬이라, 이번 릴리스에서
`lexfeat.l`·`state.l`·`evidence.l` 정렬을 이 도구로 수행했습니다(수작업 재배치 제거).

## ④ OOD 기권 재교정 — 단서 적중률 게이트

단어 OOV 비율 대신 **판정에 쓰인 단서의 적중률**(matched_unique_cues / total_unique_cues)을
Q16 임계(0.25 = 16384)로 사용합니다. 기존 170건과 **별도 신규 OOD 20건**(양자·천문·금융·법률 등
코퍼스 비중복 어휘)으로 일반화를 확인했습니다.

| 임계 | 영역 내 150 (같은 gold) | 영역 밖 20 기권 | 전체 170 | **신규 OOD 20 기권** |
|---|---|---|---|---|
| 0.00 (현행) | 105 (0.700) | 3 | 0.635 | 15/20 |
| **0.25** | **103 (0.687, −1.3pp)** | **16** | **0.700 (+6.5pp)** | **20/20** |

핵심: 리뷰가 지적한 사후(post-hoc) 임계 우려를 **신규 20건으로 검증**했습니다. 0.25에서 신규 OOD는
20/20 기권하고 영역 내 손실은 2건(−1.3pp)입니다.

## 게이트 (`V0053`)

```text
FEAT-ADV-21   적대적 21건 정답(오거부 2건·오수용 6건 교정 포함)
SX-SORT       문자열/주석 인식 + 따옴표 보존 + define↔define-function 위상 정렬
STATE-HARD    b 로컬화 · pointer 결손 reject
CUE-GATE      임계 0.25: 영역 내 손실 ≤ 2pp AND 신규 OOD 기권 ≥ 0.75
V0053-MEOWDLM-OOD-CUE-PASS
```
