#!/usr/bin/env bash
# sem-loop-1 이관분만 실행하는 게이트 러너(전체 verify.sh 는 0.0071 이전 구간의 참조 구현에
# 의존한다). 구간: S1 의미항·증명서 / S2 대명사 해소 / S3 수 동치 조회. 약 8분.
set -euo pipefail
cd "$(dirname "$0")"
sed -n '/== 38\. S1 sem-syntax/,$p' verify.sh > /tmp/mw_semloop_sections.sh
{ echo 'MARU="${MARU:-/research/dlm_v0.0284/maru-compiler}"'
  echo 'set -euo pipefail'
  cat /tmp/mw_semloop_sections.sh
} > /tmp/mw_semloop_run.sh
exec bash /tmp/mw_semloop_run.sh
