# Linting

이 프로젝트는 순수 bash 스크립트 + 마크다운으로 구성되어 있습니다.

## Shell Scripts

| Tool | Purpose | Install |
|------|---------|---------|
| ShellCheck | Shell script static analysis | `brew install shellcheck` or `apt install shellcheck` |
| shfmt | Shell script formatter | `brew install shfmt` or `go install mvdan.cc/sh/v3/cmd/shfmt@latest` |

### 실행

```bash
# ShellCheck: 모든 스크립트 검사
find scripts .hxsk/hooks -name '*.sh' -exec shellcheck {} +

# shfmt: 포매팅 검사
find scripts .hxsk/hooks -name '*.sh' -exec shfmt -d {} +
```

## Markdown

| Tool | Purpose |
|------|---------|
| markdownlint | Markdown 스타일 검사 |

## Qlty (통합)

`qlty` CLI가 설치되어 있으면 통합 검사 가능:

```bash
qlty check
qlty fmt
```
