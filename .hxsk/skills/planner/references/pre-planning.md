# Pre-Planning Reference

## SPEC.md Guard

계획 수립 전 SPEC.md에 미교체 플레이스홀더가 있으면 **즉시 경고** 후 중단한다:

```bash
PLACEHOLDER_COUNT=$(grep -c '{[A-Za-z]' .hxsk/SPEC.md 2>/dev/null || echo 0)
if [[ "$PLACEHOLDER_COUNT" -gt 0 ]]; then
    echo "⚠️  SPEC.md에 미교체 플레이스홀더 ${PLACEHOLDER_COUNT}개 발견"
    echo "   grep '{[A-Za-z]' .hxsk/SPEC.md 로 확인 후 실제 내용으로 교체하세요."
    echo "   플레이스홀더가 남은 SPEC을 기반으로 계획을 작성하면 잘못된 구현이 생성됩니다."
    # STOP — 사용자에게 SPEC.md 수정 요청
fi
```

SPEC.md에 `{ProjectName}`, `{description}` 등 `{...}` 패턴이 남아 있으면 계획 작성을 시작하지 말고 사용자에게 교체를 요청한다.

---

## Memory Recall

계획 수립 전 과거 실행 결과와 이탈 패턴을 recall한다:

```
Grep(pattern: "{phase/feature description}", path: ".hxsk/memories/", output_mode: "files_with_matches")
```

```bash
# lessons-learned 조회 — 반복 패턴 방지
bash .hxsk/hooks/md-recall-memory.sh "{phase/feature description} lessons-learned" \
  "." 5 compact
```

과거 `execution-summary`, `deviation`, `pattern-discovery` 메모리를 참고하여:
- 이전 실행에서 발생한 이탈 패턴 회피
- 검증된 접근 방식 재활용
- 실패한 접근 방식 사전 배제

특정 타입의 메모리가 필요하면 디렉토리 기반으로 좁히기:
```
Glob(pattern: ".hxsk/memories/{execution-summary,deviation,pattern-discovery}/*.md")
```
