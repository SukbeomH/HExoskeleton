#!/usr/bin/env bash
# bench-recall.sh — md-recall-memory.sh hop=1 vs hop=2 레이턴시 벤치마크
# Usage: bash .hxsk/scripts/bench-recall.sh
# Output: TSV (query | hop | latency_ms | top1_file) + 요약

# set -e 금지: grep 0건 결과에서 abort 방지
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RECALL_SCRIPT="$PROJECT_ROOT/.hxsk/hooks/md-recall-memory.sh"

if [ ! -f "$RECALL_SCRIPT" ]; then
    echo "[ERROR] md-recall-memory.sh not found at: $RECALL_SCRIPT" >&2
    exit 1
fi

# 5개 기준 쿼리 (실제 .hxsk/memories/ 내 존재하는 topics 기반)
QUERIES=(
    "gate-check"
    "CSO"
    "memory-system"
    "pattern-discovery"
    "execution"
)

# TSV 헤더
echo -e "query\thop\tlatency_ms\ttop1_file"

# hop=1, hop=2 누적값 (ms 합계, 카운트)
hop1_total=0
hop1_count=0
hop2_total=0
hop2_count=0

for QUERY in "${QUERIES[@]}"; do
    for HOP in 1 2; do
        # 나노초 타이머 시작
        START_NS=$(date +%s%N 2>/dev/null || echo "0")

        # 검색 실행 (오류는 무시, 결과만 캡처)
        RAW_OUTPUT=$(bash "$RECALL_SCRIPT" "$QUERY" "$PROJECT_ROOT" 5 compact "$HOP" 2>/dev/null || true)

        # 나노초 타이머 종료
        END_NS=$(date +%s%N 2>/dev/null || echo "0")

        # 레이턴시 계산 (ms)
        if [ "$START_NS" = "0" ] || [ "$END_NS" = "0" ]; then
            LATENCY_MS=0
        else
            DIFF_NS=$(( END_NS - START_NS ))
            LATENCY_MS=$(( DIFF_NS / 1000000 ))
        fi

        # top-1 결과 파일명 추출 (첫 번째 출력 행에서 .md 파일 경로 또는 제목 추출)
        TOP1_FILE=""
        if [ -n "$RAW_OUTPUT" ]; then
            # 출력 첫 줄에서 파일명 추출 시도
            FIRST_LINE=$(echo "$RAW_OUTPUT" | head -1 || true)
            # "- **title** [type] date" 형태에서 title 추출
            TOP1_FILE=$(echo "$FIRST_LINE" | sed -n 's/^- \*\*\(.*\)\*\* \[.*\].*/\1/p' || true)
            if [ -z "$TOP1_FILE" ]; then
                TOP1_FILE=$(echo "$FIRST_LINE" | head -c 60 || true)
            fi
        fi

        if [ -z "$TOP1_FILE" ]; then
            TOP1_FILE="(no_match)"
        fi

        echo -e "${QUERY}\t${HOP}\t${LATENCY_MS}\t${TOP1_FILE}"

        # 누적합 업데이트
        if [ "$HOP" -eq 1 ]; then
            hop1_total=$(( hop1_total + LATENCY_MS ))
            hop1_count=$(( hop1_count + 1 ))
        else
            hop2_total=$(( hop2_total + LATENCY_MS ))
            hop2_count=$(( hop2_count + 1 ))
        fi
    done
done

echo ""
echo "=== Summary ==="
echo "Total queries: ${#QUERIES[@]}"

if [ "$hop1_count" -gt 0 ]; then
    AVG_HOP1=$(( hop1_total / hop1_count ))
else
    AVG_HOP1=0
fi

if [ "$hop2_count" -gt 0 ]; then
    AVG_HOP2=$(( hop2_total / hop2_count ))
else
    AVG_HOP2=0
fi

echo "Avg latency hop=1: ${AVG_HOP1} ms"
echo "Avg latency hop=2: ${AVG_HOP2} ms"

if [ "$AVG_HOP1" -gt 0 ]; then
    OVERHEAD=$(( (AVG_HOP2 - AVG_HOP1) * 100 / AVG_HOP1 ))
    echo "Overhead (hop2 vs hop1): ${OVERHEAD}%"
else
    echo "Overhead: N/A (hop1 latency=0)"
fi
