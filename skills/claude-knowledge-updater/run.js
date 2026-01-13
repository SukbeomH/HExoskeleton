#!/usr/bin/env node
/**
 * update_claude_knowledge.js - CLAUDE.md 지식 복리화 업데이트 유틸리티
 *
 * 목적: 검증 피드백 루프 결과를 CLAUDE.md의 'Lessons Learned' 섹션에 자동으로 추가합니다.
 * 이는 팀의 지식이 복리로 축적되도록 돕습니다.
 *
 * 사용법:
 *   node skills/claude-knowledge-updater/run.js <검증 결과 JSON>
 *
 * 제약사항:
 *   - 검증 결과는 JSON 형식이어야 합니다.
 *   - CLAUDE.md의 'Lessons Learned' 섹션에 자동으로 추가됩니다.
 */

const fs = require('fs');
const path = require('path');

// 프로젝트 루트 디렉토리 찾기 (skills/claude-knowledge-updater 기준)
const SCRIPT_DIR = __dirname;
const PROJECT_ROOT = path.resolve(SCRIPT_DIR, '../..');
const CLAUDE_MD_PATH = path.join(PROJECT_ROOT, 'CLAUDE.md');

/**
 * 검증 결과를 마크다운 형식으로 변환
 */
function formatVerificationResult(result) {
	const date = new Date().toISOString().split('T')[0];
	let markdown = `\n#### [${date}] 검증 피드백 루프 실행 결과\n`;

	// 기본 검증 결과
	if (result.steps && result.steps.verify) {
		const verify = result.steps.verify;

		// 코드 단순화 제안
		if (verify.simplifier && verify.simplifier.suggestions && verify.simplifier.suggestions.length > 0) {
			markdown += `- **코드 복잡도 분석**: ${verify.simplifier.suggestions.length}개의 개선 제안 발견\n`;
			for (const suggestion of verify.simplifier.suggestions.slice(0, 3)) {
				// 최대 3개만 표시
				markdown += `  - ${suggestion.type}: ${suggestion.message.replace(/\n/g, ' ')}\n`;
			}
		}

		// 기본 검증 에러
		if (verify.basic && verify.basic.errors && verify.basic.errors.length > 0) {
			markdown += `- **검증 에러**: ${verify.basic.errors.length}개의 에러 발견\n`;
			for (const error of verify.basic.errors.slice(0, 3)) {
				markdown += `  - ${error}\n`;
			}
		}

		// 보안 감사 결과
		if (verify.security) {
			if (verify.security.vulnerabilities && verify.security.vulnerabilities.length > 0) {
				markdown += `- **보안 감사**: ${verify.security.vulnerabilities.length}개의 취약점 발견\n`;
				for (const vuln of verify.security.vulnerabilities.slice(0, 3)) {
					markdown += `  - ${vuln.name || vuln.title || 'Unknown'}: ${vuln.severity || 'Unknown severity'}\n`;
				}
			} else if (verify.security.status === 'completed') {
				markdown += `- **보안 감사**: 취약점 없음\n`;
			} else if (verify.security.status === 'failed') {
				markdown += `- **보안 감사**: 실패 (도구 미설치 또는 오류)\n`;
			}
		}
	}

	// 승인 상태
	if (result.steps && result.steps.approve) {
		const approvalStatus = result.steps.approve.status === 'approved' ? '승인됨' : result.steps.approve.status === 'rejected' ? '거부됨' : '건너뜀';
		markdown += `- **적용 여부**: ${approvalStatus}\n`;
	}

	return markdown;
}

/**
 * CLAUDE.md에 Lessons Learned 섹션이 있는지 확인하고, 없으면 추가
 */
function ensureLessonsLearnedSection(content) {
	// Lessons Learned 섹션이 있는지 확인
	if (content.includes('### 📚 Lessons Learned')) {
		return content;
	}

	// Compounding Knowledge 섹션 찾기
	const compoundingKnowledgeMatch = content.match(/(## 🧠 Compounding Knowledge \(복리 지식\)[\s\S]*?)(## |$)/);
	if (!compoundingKnowledgeMatch) {
		// Compounding Knowledge 섹션이 없으면 추가
		const insertPoint = content.indexOf('## 🚀 Workflow Control');
		if (insertPoint === -1) {
			// Workflow Control 섹션도 없으면 끝에 추가
			return content + '\n\n## 🧠 Compounding Knowledge (복리 지식)\n\n이 섹션은 팀의 실전 경험이 축적되는 공간입니다. AI가 잘못된 행동을 할 때마다 여기에 추가하여 다음에 같은 실수를 방지합니다.\n\n### 📚 Lessons Learned (자동 업데이트)\n\n이 섹션은 검증 피드백 루프 실행 결과가 자동으로 추가됩니다.\n\n';
		}
		return (
			content.slice(0, insertPoint) +
			'\n\n## 🧠 Compounding Knowledge (복리 지식)\n\n이 섹션은 팀의 실전 경험이 축적되는 공간입니다. AI가 잘못된 행동을 할 때마다 여기에 추가하여 다음에 같은 실수를 방지합니다.\n\n### 📚 Lessons Learned (자동 업데이트)\n\n이 섹션은 검증 피드백 루프 실행 결과가 자동으로 추가됩니다.\n\n' +
			content.slice(insertPoint)
		);
	}

	// Compounding Knowledge 섹션 안에 Lessons Learned 추가
	const sectionContent = compoundingKnowledgeMatch[1];
	if (!sectionContent.includes('### 📚 Lessons Learned')) {
		// Model-Specific Tips 섹션 전에 추가
		const tipsMatch = sectionContent.match(/(### 📚 Model-Specific Tips)/);
		if (tipsMatch) {
			const insertPoint = compoundingKnowledgeMatch.index + sectionContent.indexOf(tipsMatch[0]);
			return (
				content.slice(0, insertPoint) +
				'\n### 📚 Lessons Learned (자동 업데이트)\n\n이 섹션은 검증 피드백 루프 실행 결과가 자동으로 추가됩니다.\n\n' +
				content.slice(insertPoint)
			);
		}

		// Workarounds 섹션 후에 추가
		const workaroundsMatch = sectionContent.match(/(### 🔧 Workarounds \(해결 방법\)[\s\S]*?)(?=###|$)/);
		if (workaroundsMatch) {
			const insertPoint = compoundingKnowledgeMatch.index + sectionContent.indexOf(workaroundsMatch[0]) + workaroundsMatch[0].length;
			return (
				content.slice(0, insertPoint) +
				'\n### 📚 Lessons Learned (자동 업데이트)\n\n이 섹션은 검증 피드백 루프 실행 결과가 자동으로 추가됩니다.\n\n' +
				content.slice(insertPoint)
			);
		}
	}

	return content;
}

/**
 * CLAUDE.md에 검증 결과 추가
 */
function updateClaudeMD(result) {
	if (!fs.existsSync(CLAUDE_MD_PATH)) {
		console.error(`❌ CLAUDE.md not found at ${CLAUDE_MD_PATH}`);
		process.exit(1);
	}

	let content = fs.readFileSync(CLAUDE_MD_PATH, 'utf-8');

	// Lessons Learned 섹션 확인 및 추가
	content = ensureLessonsLearnedSection(content);

	// Lessons Learned 섹션 찾기
	const lessonsLearnedMatch = content.match(/(### 📚 Lessons Learned \(자동 업데이트\)[\s\S]*?)(?=###|##|$)/);
	if (!lessonsLearnedMatch) {
		console.error('❌ Lessons Learned section not found in CLAUDE.md');
		process.exit(1);
	}

	// 검증 결과를 마크다운으로 변환
	const newEntry = formatVerificationResult(result);

	// 섹션 끝에 추가 (다음 섹션 전에)
	const insertPoint = lessonsLearnedMatch.index + lessonsLearnedMatch[0].length;
	const beforeNextSection = content.slice(insertPoint).match(/^(?=\n*(?:###|##))/);
	const actualInsertPoint = beforeNextSection ? insertPoint + beforeNextSection.index : insertPoint;

	content = content.slice(0, actualInsertPoint) + newEntry + content.slice(actualInsertPoint);

	// 파일 저장
	fs.writeFileSync(CLAUDE_MD_PATH, content, 'utf-8');
	console.log('✅ CLAUDE.md updated successfully');
}

/**
 * 메인 실행 함수
 */
function main() {
	const resultJson = process.argv[2];

	if (!resultJson) {
		console.error('❌ Usage: node claude-knowledge-updater/run.js <verification_result_json>');
		process.exit(1);
	}

	let result;
	try {
		result = JSON.parse(resultJson);
	} catch (error) {
		console.error(`❌ Failed to parse JSON: ${error.message}`);
		process.exit(1);
	}

	updateClaudeMD(result);
}

// 스크립트 직접 실행 시
if (require.main === module) {
	main();
}

module.exports = { updateClaudeMD, formatVerificationResult, ensureLessonsLearnedSection };

