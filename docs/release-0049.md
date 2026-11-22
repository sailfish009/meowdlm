# meowdlm 0.0049 — Lean 4 스타일 문법 강제를 Maru 에서 어디까지 할 수 있나

질문: (Lean 4 의 inductive/dependent type 예제처럼) 영어 문법 규칙을 형식언어로 표현해 문장의
구조적 정합성을 **강제**할 수 있는가. 답: **형식언어·생성·검증은 그대로 되고, 의존타입 수준의
"구성상 옳음" 보증은 안 된다**(자질 통일 검사로 대체).

## Lean 예제 → Maru 대응

| Lean 4 | Maru 0.0049 | 상태 |
|---|---|---|
| `inductive Det/Noun/Verb` | 태그된 리스트 + 어휘 표 `*lex*` (word cat number case) | 구현 |
| `inductive NP/VP/Sentence` (CFG) | 태그 리스트 + 생성기 `a-gen-s` | 구현 |
| `toWords` (선형화) | `a-gen-s`/`a-gen-np` 가 단어열을 만든다 | 구현 |
| 의존타입 `AgrNP n` / `ValidSentence` | **자질(수·격) + 통일 검사** `a-unify` | 구현(검사이지 증명 아님) |
| Lean 커널의 증명 검사 | 없음 — 우리 검사기는 테스트와 게이트로만 보증 | **한계** |

## 측정 (고정 증인 11문장)

```text
자질 문법 수용 4/11
  0 the cat chases a dog      → 수용 (정문)
  1 the cats chase a dog      → 수용 (정문)
  2 the cats chases a dog     → 거부 (주어-동사 수 불일치)
  3 the cat chase a dog       → 거부 (동일)
  4 a dog sleeps              → 수용
  5 a dogs sleep              → 거부 (관사-명사 수 불일치)
  6 a dogs sleeps             → 거부
  7 they sleep                → 수용
  8 they sleeps               → 거부
  9 i sleep                   → 거부 (모델 한계: 인칭 미구현)
 10 me sleep                  → 거부 (격 위반)
일반 33공리 CFG 대조
  0,1 거부(어휘 부재) · 7 they sleep 수용 · 9 i sleep 수용 · 10 me sleep **수용**
```

**핵심 대비**: `me sleep`(격 위반)을 자질 문법은 거부하고 일반 CFG는 수용합니다. 자질 층이
추가하는 제약이 실측으로 확인됩니다(0.0038 의 격 세분화와 같은 방향, 이번엔 수 일치까지 포함).

## 판정

1. **Maru 는 Lean 예제의 1~3단계(품사·CFG·선형화)를 그대로 재현**합니다. 생성기와 검사기가
   같은 자질 표를 공유하므로, 생성된 문장은 정의상 자질을 만족합니다.
2. **4단계(의존타입)는 "강제"가 아니라 "검사"** 입니다. Lean 은 `ValidSentence` 를 만들 수 없는
   값이 타입 수준에서 배제되지만, Maru 에는 타입 커널이 없으므로 우리 생성기 규율 + 테스트로만
   보증합니다. 이 차이는 숨기지 않습니다.
3. 모델 한계: 인칭(person) 미구현으로 `i sleep` 이 거부됩니다(수만 비교). 어휘 자질을
   (person, number, case)로 확장하면 해결되나 이번 측정에는 포함하지 않았습니다.

## 게이트 (`V0049`)

```text
AGREE-ACCEPT  정문 4건 수용 (0,1,4,7)
AGREE-REJECT  수·격 위반 6건 거부 (2,3,5,6,8,10)
CFG-GAP       `me sleep` 을 자질 문법은 거부, 일반 CFG 는 수용
V0049-MEOWDLM-FEATURE-GRAMMAR-PASS
```
