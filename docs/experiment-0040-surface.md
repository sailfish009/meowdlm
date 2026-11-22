# 실험: Maru 표면 실현(도식+슬롯) 이관과 동등성 측정

목표는 원본 MeowLLM 동등 이상입니다. 이번 단계는 **생성 경로를 Maru 로 옮기고** 동등성 수치를
같은 프로브로 다시 재는 것입니다.

## 이관 결과

```text
src/meow/surface.l   도식 선택(길이 목표 근접 16 → 8) + 슬롯 채움(top-8) + 렌더
data/surface_frames.l  범주당 16도식 × 15범주 = 240, 평균 길이 Q16
data/surface_slots.l   슬롯 위치 1,000, 위치별 빈도 상위 8
해시  sha256 대신 FNV-1a 32(모듈러스 2^32) — Maru 에 암호 해시가 없다
```

15개 범주 전부 문장이 나옵니다(표본):

```text
greeting      You may continue from the warm blanket.
hunger        Yes yes treats are always the answer.
naps          Shh i was in the middle of a dream.
territory     I have claimed this place formally.
vacuum        Not today i am leaving at top speed.
windows       I am on window patrol very carefully.
```

## 동등성 (같은 프로브 170건)

| 경로 | 카테고리 일치 | 비고 |
|---|---|---|
| Maru (증거 판정) | **105/170 = 0.618** | derived 150, 마진 Q16 |
| 파이썬 meowdlm 0.0039 | 0.618 (동일) | Maru 와 170/170 판정 일치 |
| 원본 MeowLLM (step 2000) | **0.467** 자유발화 / 0.000 영역밖 | 동일 프로브, 0.0289 측정 |

즉 판정 경로는 **원본 대비 +15.1pp**, 영역 밖에서도 판단을 유지합니다.

## 아직 동등하지 않은 것 (정직한 기록)

- **문자열 단위 실현 일치 미달**: 같은 (범주, seed)에 대해 Maru 와 파이썬 참조가 다른 도식을
  고릅니다(15건 중 14건 불일치). 원인 후보는 ① FNV 로 바꾸면서 해시 분포가 달라져 도식 인덱스가
  달라짐 ② 파이썬 참조의 도식 풀 정렬과 데이터 인덱스 대응. **문장 품질 지표는 두 경로 모두
  코퍼스 도식·슬롯 어휘에서 나오므로 분포는 같지만, 바이트 동일성은 아직 주장하지 않습니다.**
- **표면 게이트 미배선**: 0.0036 결론(하드 게이트가 유창성을 0.819→0.097로 떨어뜨림)에 따라
  게이트 없이 생성합니다.
- `avoid_corpus`(코퍼스 문장 회피) 검사는 이관하지 않았습니다.

## 다음 실험 (동등 → 개선)

```text
1  실현 동등성 마감: 도식 인덱스·해시 규약을 양쪽 동일하게 고정하고 60건 문자열 일치
2  원본 대비 잔여 손실 진단: OOV 35% 구간 / 화용 표현(miss you 등) 부재
3  개선 후보 1순위: 어휘 밖 단어를 침묵 대신 **범주 유추**(0.0039 P2 위에 규칙 추가)
```

## 실행

```bash
cd /research/meowdlm_v0.0040
/research/dlm_v0.0284/maru-compiler src/maru/boot.l src/maru/conversion.l \
  src/meow/surface.l experiments/parity/surface_start.l     # 15범주 문장
/research/dlm_v0.0284/maru-compiler src/maru/boot.l src/maru/conversion.l \
  src/meow/evidence.l experiments/parity/evidence_start.l   # 170건 판정
```
