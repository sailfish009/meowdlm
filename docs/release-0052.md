# meowdlm 0.0052 — 0.0051 숨은 결함 3건 수정 + 단일 자질 어휘(6-튜플)

## 수정 ① state.l 10KB 초과 파일 크래시 (치명)

`st-fnv-file-acc`가 바이트마다 재귀해 26KB 파일에서 `FATAL: infinite recursion guard`로 죽었습니다.
**while 반복 + `file-open-read`**로 교체해 스택 깊이를 O(1)로 고정하고, 결손 파일도 함께 처리했습니다.

```text
FNV26K 3915785769   (Python 동일값 3915785769, 파일 26,101 B)
FNV-MISSING ()      (결손 → reject 경로)
```

## 수정 ② certify.l lex 인자 무시

`c-check-leaf`가 인자 `lex`를 받고도 전역 `*lex*`를 참조했습니다 → `(c-assoc w lex)`로 수정.

## 수정 ③ tools/sx.py (문자열·주석 인식 + 통합 위상 정렬)

`reorder.py`의 두 결함을 고친 도구를 새로 만들었습니다.

```text
SX-SELFTEST-PASS forms=3 order=*a*,g,f
  - "(x(y" 처럼 문자열 안 괄호를 세지 않는다
  - ;; 주석 안 괄호도 무시
  - (define ...) 과 (define-function ...) 을 한 그래프로 정렬(데이터가 함수를 부르면 뒤로)
  - 쓰기 전후 괄호 균형 단언(불균형이면 파일을 쓰지 않음)
```

## 0.0052 게이트 ① — 단일 자질 어휘 (6-튜플)

`data/lexfeat_data.l`(41단어, `word cat person number case valence`) + `src/meow/lexfeat.l`.

| 문장 | 판정 | 원인 |
|---|---|---|
| i sleep | **수용** | |
| i sleeps | 거부 | subj-verb-agr |
| me sleep | 거부 | case |
| they sleep / he sleeps | 수용 | |
| he sleep | 거부 | subj-verb-agr (기본형 + 3인칭 단수) |
| the cat chases a dog / the cats chase a dog | 수용 | |
| the cats chases a dog | 거부 | subj-verb-agr |
| a dogs sleep | 거부 | det-n-agree |
| the cat chases me / chases i | 수용 / 거부 | object-case |
| the cat is big / the cats are big | 수용 (계사) | |

14/14 정답. `i sleep` 거부(0.0049 한계)와 계사 수용이 함께 해소됐습니다.

## 게이트 ② 보정 (리뷰 권고 채택)

15/15 강제를 목표로 두지 않고 두 단계로 나눕니다(무자질 CFG 규칙 증설은 셔플 역전 +40/+44 재발).
이번 릴리스는 **어휘·자질 층**까지이고, surface↔syntax 연결·진단 게이트는 0.0053으로 넘깁니다.
리뷰 실측(현재 어휘로 10/15 범주, 누락 48단어 개방 시 14/15)을 기준선으로 기록합니다.

## 게이트 (`V0052`)

```text
SX-SELFTEST     문자열/주석 괄호 무시 + define↔define-function 위상 정렬
FNV-26K         26KB 파일 해시가 Python 과 일치(while 루프, 크래시 없음)
MISSING-REJECT   결손 파일 → reject
GEN-MISMATCH     세대 불일치 → reject-gen
FEAT-14/14       자질 판정 14건 정답(i sleep 수용, i sleeps·me sleep 거부, 계사 수용)
V0052-MEOWDLM-FEAT-PASS
```
