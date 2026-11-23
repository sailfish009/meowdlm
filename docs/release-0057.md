# meowdlm 0.0057 — 학습 경험 저장 (L/R/C 레코드)

## 문제

학습이 계산한 결정이 매 실행마다 버려지고 있었습니다. `grep` 확인 결과 학습 모듈
(`induce.l`, `lexfix.l`, `surface.l`, `certify.l`)은 `st-save`를 **0회** 호출했고, 저장은 두
드라이버의 더미 규칙에만 쓰였습니다. 그 결과 0.0056의 규칙 심사(6분 30초), 0.0054의 가지치기
(1분 20초), 0.0050의 반례 18건이 모두 다음 실행에서 사라졌습니다.

## 구현

```text
src/meow/exp.l
  레코드 = (kind key payload witness gate)
    L  어휘 개정      (word, "removed", 제거 전후 범주 수)
    R  규칙 채택/기각 (rule, "adopt"|"reject", Δ도출, Δ셔플)
    C  반례           (id, tokens, cause, verdict)
  ex-add / ex-find / ex-rejected? / ex-clear
  ex-save(gen)  state/gen-N/experience.l  (state.l 의 dump-all 라이터 + file-replace)
  ex-load(gen)  load + 해시 재검
```

## 측정 (Maru)

```text
EXP   L=47  R=3  C=3  total=53        ← 30문장 가지치기 + 규칙 3건 + 반례 3건
SAVE  hash=1155959702 (115,595,9702)
CLEAR → 0
RELOAD (1155959702 53)                ← 해시 일치, 레코드 53 복원
RESUME-EQ   1                          재시작 후 개수·해시 동일
REJECT-MEM  1  adopt-ok=1              기각(r4)·채택(r7) 기억 정확
CEX-REPLAY  3/3                        저장된 반례 원인이 재검사에서 동일
```

## 판정

1. **경험이 이제 저장됩니다.** 학습 결정 53건이 파일로 남고, 해시로 검증되며, 재로드 시 그대로
   복원됩니다.
2. **기각 기억이 동작합니다.** `VP->AUX NP`(셔플 +9로 기각)는 `reject`로, `NG->N CL`은 `adopt`로
   구분되어 조회됩니다. 다음 실행에서 같은 후보를 재심사하지 않아도 됩니다.
3. **반례 재생이 성립합니다**(3/3). `me sleep`(case), `the cats chases`(agr), `the cat is`
   (no-complement)의 원인이 저장값과 일치합니다.

## 경계 (정직하게)

- 이번 저장은 **측정 하네스가 호출**합니다. 학습 모듈 내부 배선(가지치기·심사 직후 자동 기록)은
  다음 단계입니다.
- R 레코드의 Δ값은 0.0056 측정치를 **근거로 기록**한 것이며, 이번 릴리스에서 재측정하지 않았습니다.
- 저장이 이해도(0.700)나 생성 통과율(2/15)을 올리지는 않습니다. 비용·안정성·감사가 이득입니다.
- 상태 크기는 53레코드에서 수 KB 수준이며, 200KB 상한은 게이트로만 확인합니다.

## 게이트 (`V0057`)

```text
EXPERIENCE    L/R/C 레코드 저장·복원 (총 53)
RESUME-EQ     재로드 후 개수·해시 동일
REJECT-MEM    기각 후보 조회 = reject, 채택 후보 = adopt
CEX-REPLAY    저장 반례 3/3 원인 일치
BOUND         experience.l ≤ 200KB
V0057-MEOWDLM-EXPERIENCE-PASS
```
