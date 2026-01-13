"""
Skills API 라우터

스킬 instructions 및 지식 관련 API 엔드포인트를 제공합니다.
"""

from fastapi import APIRouter, HTTPException
from pathlib import Path
import sys
import re
from typing import List, Dict, Optional

# 프로젝트 루트를 Python 경로에 추가
backend_root = Path(__file__).parent.parent  # gui/backend/app
boilerplate_root = backend_root.parent.parent.parent  # boilerplate 루트
sys.path.insert(0, str(backend_root))

router = APIRouter(prefix="/api/v1/skills", tags=["skills"])

# Skills 디렉토리 경로
SKILLS_DIR = boilerplate_root / "skills"
CLAUDE_MD_PATH = boilerplate_root / "CLAUDE.md"

VALID_SKILLS = ["simplifier", "log-analyzer", "security-audit", "visual-verifier", "claude-knowledge-updater", "git-guard"]


@router.get("/{skill_name}/instructions")
async def get_skill_instructions(skill_name: str) -> Dict[str, str]:
	"""
	스킬의 instructions.md 파일을 읽어 반환합니다.

	Args:
		skill_name: 스킬 이름 (simplifier, log-analyzer, security-audit, visual-verifier 등)

	Returns:
		instructions.md 파일 내용
	"""
	if skill_name not in VALID_SKILLS:
		raise HTTPException(status_code=404, detail=f"Skill '{skill_name}' not found")

	instructions_path = SKILLS_DIR / skill_name / "instructions.md"

	if not instructions_path.exists():
		raise HTTPException(status_code=404, detail=f"Instructions file not found for skill '{skill_name}'")

	try:
		content = instructions_path.read_text(encoding="utf-8")
		return {
			"skill_name": skill_name,
			"content": content,
		}
	except Exception as e:
		raise HTTPException(status_code=500, detail=f"Failed to read instructions: {str(e)}")


@router.get("/claude/lessons")
async def get_claude_lessons() -> Dict[str, List[Dict[str, str]]]:
	"""
	CLAUDE.md의 'Lessons Learned' 섹션을 파싱하여 날짜별로 반환합니다.

	Returns:
		날짜별 지식 항목 리스트
	"""
	if not CLAUDE_MD_PATH.exists():
		raise HTTPException(status_code=404, detail="CLAUDE.md file not found")

	try:
		content = CLAUDE_MD_PATH.read_text(encoding="utf-8")

		# Lessons Learned 섹션 찾기
		lessons_section_match = re.search(
			r"## 🧠 Compounding Knowledge.*?(?=## |$)",
			content,
			re.DOTALL
		)

		if not lessons_section_match:
			return {"lessons": []}

		lessons_section = lessons_section_match.group(0)

		# 날짜별 항목 파싱 (#### [YYYY-MM-DD] 형식)
		date_pattern = r"#### \[(\d{4}-\d{2}-\d{2})\]\s+(.+?)(?=#### |$)"
		matches = re.finditer(date_pattern, lessons_section, re.DOTALL)

		lessons = []
		for match in matches:
			date = match.group(1)
			content_text = match.group(2).strip()

			# 항목 리스트 추출 (마크다운 리스트)
			items = re.findall(r"[-*]\s+(.+?)(?=\n[-*]|\n\n|$)", content_text, re.DOTALL)

			lessons.append({
				"date": date,
				"title": content_text.split("\n")[0] if content_text else "",
				"content": content_text,
				"items": [item.strip() for item in items],
			})

		# 날짜 역순 정렬 (최신순)
		lessons.sort(key=lambda x: x["date"], reverse=True)

		return {"lessons": lessons}
	except Exception as e:
		raise HTTPException(status_code=500, detail=f"Failed to parse CLAUDE.md: {str(e)}")

