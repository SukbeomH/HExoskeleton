#!/bin/bash
# _json_parse.sh — JSON 파싱 런타임 추상화
# 훅에서 `source`하여 json_get() 사용
# 우선순위: jq → python3 → node

# json_get <json_string> <jq_filter>
# 예: json_get "$INPUT" '.tool_input.file_path // empty'
json_get() {
    local json="$1"
    local filter="$2"

    # 1. jq (최우선)
    if command -v jq &>/dev/null; then
        echo "$json" | jq -r "$filter" 2>/dev/null
        return
    fi

    # 2. python3
    if command -v python3 &>/dev/null; then
        # jq 필터를 Python 코드로 변환
        echo "$json" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    # jq 필터 해석: '.key1.key2 // empty' → 중첩 접근
    path = '''$filter'''.strip()
    # '// empty' fallback 제거
    fallback = ''
    if ' // ' in path:
        path, fallback_token = path.rsplit(' // ', 1)
        if fallback_token.strip() == 'empty':
            fallback = ''
        else:
            fallback = fallback_token.strip().strip('\"')
    # 점 표기법 파싱
    keys = [k for k in path.lstrip('.').split('.') if k]
    val = d
    for k in keys:
        if isinstance(val, dict):
            val = val.get(k, None)
        else:
            val = None
            break
    if val is None:
        print(fallback)
    else:
        print(val if isinstance(val, str) else json.dumps(val))
except:
    print('')
" 2>/dev/null
        return
    fi

    # 3. node
    if command -v node &>/dev/null; then
        echo "$json" | node -e "
const chunks = [];
process.stdin.on('data', c => chunks.push(c));
process.stdin.on('end', () => {
    try {
        const d = JSON.parse(chunks.join(''));
        const path = '$filter'.replace(/ \/\/ .*/,'').replace(/^\./, '').split('.');
        let val = d;
        for (const k of path) {
            if (val && typeof val === 'object') val = val[k];
            else { val = undefined; break; }
        }
        console.log(val == null ? '' : (typeof val === 'string' ? val : JSON.stringify(val)));
    } catch { console.log(''); }
});
" 2>/dev/null
        return
    fi

    # 런타임 없음
    echo ""
}

# json_dumps <string>
# 문자열을 JSON-safe로 이스케이프
json_dumps() {
    local str="$1"

    if command -v jq &>/dev/null; then
        echo "$str" | jq -Rs '.' 2>/dev/null
        return
    fi

    if command -v python3 &>/dev/null; then
        python3 -c "import json,sys; print(json.dumps(sys.stdin.read().strip()))" <<< "$str" 2>/dev/null
        return
    fi

    if command -v node &>/dev/null; then
        node -e "
const chunks = [];
process.stdin.on('data', c => chunks.push(c));
process.stdin.on('end', () => console.log(JSON.stringify(chunks.join('').trim())));
" <<< "$str" 2>/dev/null
        return
    fi

    # 최소한의 이스케이프
    echo "\"$(echo "$str" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g')\""
}
