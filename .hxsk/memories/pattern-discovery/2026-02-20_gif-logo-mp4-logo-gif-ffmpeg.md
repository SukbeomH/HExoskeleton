---
title: "로고 에셋 추가 및 GIF 변환 — logo.mp4 → logo.gif (ffmpeg)"
tags:
  - logo
  - gif
  - ffmpeg
  - README
type: pattern-discovery
created: 2026-02-20T06:22:46Z
contextual_description: "mp4→GIF 변환 패턴: 12fps/480px/64색/bayer로 최적화, GitHub README에 img 태그로 임베드."
keywords:
  - ffmpeg
  - gif
  - logo
  - mp4
  - GitHub README
  - video tag
related:
  - 2026-02-20_hexoskeleton-gsd-boilerplate
---

## 로고 에셋 추가 및 GIF 변환 — logo.mp4 → logo.gif (ffmpeg)

logo.png(픽셀 아트 엑소스켈레톤, 600x600), logo.mp4(1280x720, 24fps, 8초) 를 프로젝트에 추가.
ffmpeg로 GIF 변환: fps=12, scale=480, 64색 팔레트, bayer 디더링 → 2.6MB(1차: 5.7MB → 최적화).
변환 명령: ffmpeg -i logo.mp4 -vf 'fps=12,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=64[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3' -loop 0 logo.gif
GitHub Markdown은 <video> 태그 미지원 → <img src='logo.gif'> 로 대체.
README에서 logo.png(200px, 정적)와 logo.gif(480px, 애니메이션) 모두 center-align으로 배치.
