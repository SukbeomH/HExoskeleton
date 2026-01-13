#!/usr/bin/env node
/**
 * simplifier.js - 코드 단순화 서브에이전트
 *
 * 목적: 구현된 코드의 인지적 복잡도를 분석하고, 불필요한 추상화나 중복을 찾아 리팩토링을 제안합니다.
 * Senior Engineer의 관점에서 '간결함(Simplicity)'을 최우선 가치로 평가합니다.
 *
 * 사용법:
 *   node skills/simplifier/run.js [디렉토리 경로]
 *
 * 제약사항:
 *   - 모든 서브에이전트는 독단적으로 수정하지 않고, 항상 '제안' 후 사용자의 승인을 받아야 합니다.
 *   - detect_stack.sh의 결과를 참조하여 스택별로 적절한 도구를 선택합니다.
 *
 * 출력 형식:
 *   - JSON 형식으로 제안 사항 반환
 *   - 각 제안에 대해 파일 경로, 라인 번호, 제안 내용 포함
 *   - 사용자가 승인한 경우에만 수정 수행
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// 색상 출력을 위한 유틸리티
const colors = {
	reset: '\x1b[0m',
	red: '\x1b[31m',
	green: '\x1b[32m',
	yellow: '\x1b[33m',
	blue: '\x1b[34m',
	magenta: '\x1b[35m',
	cyan: '\x1b[36m',
};

function log(message, color = 'reset') {
	const colorCode = colors[color] || colors.reset;
	console.log(`${colorCode}${message}${colors.reset}`);
}

// 프로젝트 루트 디렉토리 찾기 (skills/simplifier 기준)
const SCRIPT_DIR = __dirname;
const PROJECT_ROOT = path.resolve(SCRIPT_DIR, '../..');
const CORE_DIR = path.join(PROJECT_ROOT, 'scripts/core');

// 간결함 평가 기준 (Senior Engineer 관점)
const SIMPLICITY_THRESHOLDS = {
	maxFunctionLines: 50, // 함수당 최대 라인 수
	maxNestingDepth: 4, // 최대 중첩 깊이
	maxCyclomaticComplexity: 10, // 최대 순환 복잡도
	maxCognitiveComplexity: 15, // 최대 인지적 복잡도
};

/**
 * detect_stack.sh를 실행하여 스택 정보를 가져옵니다.
 */
function detectStack() {
	try {
		const detectScript = path.join(CORE_DIR, 'detect_stack.sh');
		// 환경 변수를 파싱하기 위해 bash -c를 사용
		const output = execSync(
			`bash -c 'source ${detectScript} && echo "STACK=$DETECTED_STACK" && echo "PACKAGE_MANAGER=$DETECTED_PACKAGE_MANAGER"'`,
			{ cwd: PROJECT_ROOT, encoding: 'utf-8', stdio: 'pipe' }
		);

		const stackMatch = output.match(/STACK=(\w+)/);
		const packageManagerMatch = output.match(/PACKAGE_MANAGER=(\w+)/);

		return {
			stack: stackMatch ? stackMatch[1] : null,
			packageManager: packageManagerMatch ? packageManagerMatch[1] : null,
		};
	} catch (error) {
		log('⚠️  Stack detection failed. Continuing with default analysis...', 'yellow');
		return { stack: null, packageManager: null };
	}
}

/**
 * Node.js/JavaScript 코드 복잡도 분석
 */
function analyzeJavaScriptComplexity(filePath) {
	const suggestions = [];
	const content = fs.readFileSync(filePath, 'utf-8');
	const lines = content.split('\n');

	// 간단한 복잡도 분석 (실제로는 ESLint complexity 규칙을 사용하는 것이 더 정확함)
	let currentFunction = null;
	let functionStartLine = 0;
	let nestingDepth = 0;
	let lineCount = 0;
	let complexity = 1; // 기본 복잡도

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const trimmedLine = line.trim();

		// 함수 시작 감지 (간단한 패턴 매칭)
		if (
			/^(export\s+)?(async\s+)?function\s+\w+/.test(trimmedLine) ||
			/^(export\s+)?const\s+\w+\s*=\s*(async\s+)?\(/.test(trimmedLine) ||
			/^(export\s+)?\w+\s*:\s*(async\s+)?\(/.test(trimmedLine)
		) {
			// 이전 함수 분석
			if (currentFunction && lineCount > SIMPLICITY_THRESHOLDS.maxFunctionLines) {
				suggestions.push({
					type: 'long_function',
					file: filePath,
					line: functionStartLine + 1,
					message: `Function "${currentFunction}" is ${lineCount} lines long (threshold: ${SIMPLICITY_THRESHOLDS.maxFunctionLines} lines). Consider splitting it into smaller functions.`,
					severity: 'medium',
				});
			}

			currentFunction = trimmedLine.match(/(?:function|const|:)\s+(\w+)/)?.[1] || 'anonymous';
			functionStartLine = i;
			lineCount = 0;
			nestingDepth = 0;
			complexity = 1;
		}

		if (currentFunction) {
			lineCount++;

			// 중첩 깊이 계산
			const openBraces = (line.match(/{/g) || []).length;
			const closeBraces = (line.match(/}/g) || []).length;
			nestingDepth += openBraces - closeBraces;

			if (nestingDepth > SIMPLICITY_THRESHOLDS.maxNestingDepth) {
				suggestions.push({
					type: 'deep_nesting',
					file: filePath,
					line: i + 1,
					message: `Nesting depth is ${nestingDepth} (threshold: ${SIMPLICITY_THRESHOLDS.maxNestingDepth}). Consider refactoring to reduce nesting.`,
					severity: 'high',
				});
			}

			// 복잡도 증가 조건
			if (/\b(if|else|for|while|switch|catch)\b/.test(trimmedLine)) {
				complexity++;
			}

			// 함수 종료 감지
			if (trimmedLine === '}' && nestingDepth <= 0) {
				if (complexity > SIMPLICITY_THRESHOLDS.maxCyclomaticComplexity) {
					suggestions.push({
						type: 'high_complexity',
						file: filePath,
						line: functionStartLine + 1,
						message: `Function "${currentFunction}" has cyclomatic complexity of ${complexity} (threshold: ${SIMPLICITY_THRESHOLDS.maxCyclomaticComplexity}). Consider simplifying the logic.`,
						severity: 'high',
					});
				}
				currentFunction = null;
			}
		}
	}

	return suggestions;
}

/**
 * Python 코드 복잡도 분석 (기본적인 분석)
 */
function analyzePythonComplexity(filePath) {
	const suggestions = [];
	const content = fs.readFileSync(filePath, 'utf-8');
	const lines = content.split('\n');

	let currentFunction = null;
	let functionStartLine = 0;
	let lineCount = 0;
	let nestingDepth = 0;

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const trimmedLine = line.trim();

		// 함수 정의 감지
		if (/^def\s+\w+/.test(trimmedLine) || /^async\s+def\s+\w+/.test(trimmedLine)) {
			if (currentFunction && lineCount > SIMPLICITY_THRESHOLDS.maxFunctionLines) {
				suggestions.push({
					type: 'long_function',
					file: filePath,
					line: functionStartLine + 1,
					message: `Function "${currentFunction}" is ${lineCount} lines long (threshold: ${SIMPLICITY_THRESHOLDS.maxFunctionLines} lines). Consider splitting it into smaller functions.`,
					severity: 'medium',
				});
			}

			currentFunction = trimmedLine.match(/def\s+(\w+)/)?.[1] || 'anonymous';
			functionStartLine = i;
			lineCount = 0;
			nestingDepth = 0;
		}

		if (currentFunction) {
			lineCount++;

			// 들여쓰기로 중첩 깊이 계산 (간단한 방법)
			const indentLevel = (line.match(/^(\s*)/)?.[1] || '').length / 4; // 4 spaces per indent
			if (indentLevel > SIMPLICITY_THRESHOLDS.maxNestingDepth) {
				suggestions.push({
					type: 'deep_nesting',
					file: filePath,
					line: i + 1,
					message: `Nesting depth is ${indentLevel} (threshold: ${SIMPLICITY_THRESHOLDS.maxNestingDepth}). Consider refactoring to reduce nesting.`,
					severity: 'high',
				});
			}
		}
	}

	return suggestions;
}

/**
 * 스택별 코드 분석 실행
 */
function analyzeCodeComplexity(stackInfo, targetDir) {
	const suggestions = [];
	const analyzeDir = targetDir || path.join(PROJECT_ROOT, 'src');

	if (!fs.existsSync(analyzeDir)) {
		log(`⚠️  Directory not found: ${analyzeDir}`, 'yellow');
		return suggestions;
	}

	log(`🔍 Analyzing code complexity in: ${analyzeDir}`, 'blue');

	// 파일 찾기 및 분석
	function findFiles(dir, ext) {
		const files = [];
		const entries = fs.readdirSync(dir, { withFileTypes: true });

		for (const entry of entries) {
			const fullPath = path.join(dir, entry.name);
			if (entry.isDirectory() && !entry.name.startsWith('.') && entry.name !== 'node_modules') {
				files.push(...findFiles(fullPath, ext));
			} else if (entry.isFile() && entry.name.endsWith(ext)) {
				files.push(fullPath);
			}
		}
		return files;
	}

	switch (stackInfo.stack) {
		case 'node':
			log('📦 Analyzing JavaScript/TypeScript files...', 'blue');
			const jsFiles = [
				...findFiles(analyzeDir, '.js'),
				...findFiles(analyzeDir, '.jsx'),
				...findFiles(analyzeDir, '.ts'),
				...findFiles(analyzeDir, '.tsx'),
			];
			for (const file of jsFiles) {
				suggestions.push(...analyzeJavaScriptComplexity(file));
			}
			break;

		case 'python':
			log('🐍 Analyzing Python files...', 'blue');
			const pyFiles = findFiles(analyzeDir, '.py');
			for (const file of pyFiles) {
				suggestions.push(...analyzePythonComplexity(file));
			}
			break;

		default:
			log(`⚠️  Stack "${stackInfo.stack}" analysis not yet fully implemented.`, 'yellow');
			break;
	}

	return suggestions;
}

/**
 * 제안 사항을 JSON 형식으로 출력
 */
function outputSuggestions(suggestions) {
	if (suggestions.length === 0) {
		log('✅ No complexity issues found. Code follows simplicity principles!', 'green');
		return;
	}

	log(`\n📋 Found ${suggestions.length} suggestion(s):\n`, 'blue');

	// 심각도별로 정렬
	suggestions.sort((a, b) => {
		const severityOrder = { high: 0, medium: 1, low: 2 };
		return severityOrder[a.severity] - severityOrder[b.severity];
	});

	for (const suggestion of suggestions) {
		const severityColor = suggestion.severity === 'high' ? 'red' : suggestion.severity === 'medium' ? 'yellow' : 'blue';
		log(`[${suggestion.severity.toUpperCase()}] ${suggestion.file}:${suggestion.line}`, severityColor);
		log(`  ${suggestion.message}\n`, 'reset');
	}

	// JSON 출력
	const jsonOutput = {
		timestamp: new Date().toISOString(),
		totalSuggestions: suggestions.length,
		suggestions: suggestions,
	};

	console.log('\n--- JSON Output ---');
	console.log(JSON.stringify(jsonOutput, null, 2));
}

/**
 * 메인 실행 함수
 */
function main() {
	const targetDir = process.argv[2] || null;

	log('🔧 Code Simplifier Agent', 'cyan');
	log('========================\n', 'cyan');

	// 1. 스택 감지
	log('1. Detecting stack...', 'blue');
	const stackInfo = detectStack();
	if (stackInfo.stack) {
		log(`   Detected stack: ${stackInfo.stack} (${stackInfo.packageManager})`, 'green');
	} else {
		log('   No stack detected. Using default analysis.', 'yellow');
	}

	// 2. 코드 복잡도 분석
	log('\n2. Analyzing code complexity...', 'blue');
	const suggestions = analyzeCodeComplexity(stackInfo, targetDir);

	// 3. 제안 사항 출력
	log('\n3. Generating suggestions...', 'blue');
	outputSuggestions(suggestions);

	// 4. 사용자 승인 안내
	if (suggestions.length > 0) {
		log('\n💡 Note: These are suggestions only. Review and apply changes manually.', 'yellow');
		log('   This agent does not modify code automatically to ensure code quality.', 'yellow');
	}
}

// 스크립트 직접 실행 시
if (require.main === module) {
	main();
}

module.exports = { analyzeCodeComplexity, detectStack, SIMPLICITY_THRESHOLDS };

