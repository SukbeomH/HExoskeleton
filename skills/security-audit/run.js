#!/usr/bin/env node
/**
 * security-audit.js - 보안 감사 서브에이전트
 *
 * 목적: detect_stack.sh 결과를 기반으로 스택별 보안 점검을 수행합니다.
 * Python 프로젝트는 'poetry run safety check'를, Node.js 프로젝트는 'npm/pnpm audit'을 실행합니다.
 *
 * 사용법:
 *   node skills/security-audit/run.js [target_directory]
 *
 * 출력:
 *   JSON 형식으로 보안 감사 결과를 반환합니다.
 *
 * 제약사항:
 *   - Python 프로젝트: safety 패키지가 설치되어 있어야 함 (poetry add safety --group dev)
 *   - Node.js 프로젝트: npm/pnpm이 설치되어 있어야 함
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

// 프로젝트 루트 디렉토리 찾기 (skills/security-audit 기준)
const SCRIPT_DIR = __dirname;
const PROJECT_ROOT = process.argv[2] 
	? path.resolve(process.argv[2]) 
	: path.resolve(SCRIPT_DIR, '../..');
const CORE_DIR = path.join(PROJECT_ROOT, 'scripts/core');

/**
 * detect_stack.sh를 실행하여 스택 정보를 가져옵니다.
 */
function detectStack() {
	try {
		const detectScript = path.join(CORE_DIR, 'detect_stack.sh');
		const output = execSync(
			`bash -c 'source ${detectScript} && echo "STACK=$DETECTED_STACK" && echo "PACKAGE_MANAGER=$DETECTED_PACKAGE_MANAGER" && echo "VENV=$DETECTED_VENV_PATH"'`,
			{ cwd: PROJECT_ROOT, encoding: 'utf-8', stdio: 'pipe' }
		);

		const stackMatch = output.match(/STACK=(\w+)/);
		const packageManagerMatch = output.match(/PACKAGE_MANAGER=(\w+)/);
		const venvMatch = output.match(/VENV=(.+)/);

		return {
			stack: stackMatch ? stackMatch[1] : null,
			packageManager: packageManagerMatch ? packageManagerMatch[1] : null,
			venvPath: venvMatch ? venvMatch[1] : null,
		};
	} catch (error) {
		log('⚠️  Stack detection failed.', 'yellow');
		return { stack: null, packageManager: null, venvPath: null };
	}
}

/**
 * Python 프로젝트 보안 감사 (safety check)
 */
function auditPython(stackInfo) {
	log('🔍 Running Python security audit (safety check)...', 'blue');
	
	const results = {
		stack: 'python',
		tool: 'safety',
		status: 'unknown',
		vulnerabilities: [],
		errors: [],
	};

	try {
		// uv 또는 poetry로 safety check 실행
		let command = '';
		
		// uv.lock이 있으면 uv 사용, poetry.lock이 있으면 poetry 사용
		const uvLock = path.join(PROJECT_ROOT, 'uv.lock');
		const poetryLock = path.join(PROJECT_ROOT, 'poetry.lock');
		
		if (fs.existsSync(uvLock)) {
			command = 'uv run safety check --json';
		} else if (fs.existsSync(poetryLock)) {
			command = 'poetry run safety check --json';
			// 가상 환경이 활성화되어 있지 않은 경우 직접 실행
			if (!process.env.VIRTUAL_ENV && stackInfo.venvPath) {
				if (stackInfo.venvPath.includes('.venv')) {
					const venvSafety = path.join(PROJECT_ROOT, stackInfo.venvPath, 'bin', 'safety');
					if (fs.existsSync(venvSafety)) {
						command = `${venvSafety} check --json`;
					}
				}
			}
		} else {
			// lock 파일이 없으면 기본 safety 명령어 시도
			command = 'safety check --json';
		}

		const output = execSync(command, {
			cwd: PROJECT_ROOT,
			encoding: 'utf-8',
			stdio: 'pipe',
			timeout: 60000, // 60초 타임아웃
		});

		// safety check는 JSON 형식으로 출력
		try {
			const safetyData = JSON.parse(output);
			if (safetyData.vulnerabilities && safetyData.vulnerabilities.length > 0) {
				results.status = 'vulnerable';
				results.vulnerabilities = safetyData.vulnerabilities;
				log(`❌ Found ${safetyData.vulnerabilities.length} vulnerability(ies)`, 'red');
			} else {
				results.status = 'secure';
				log('✅ No vulnerabilities found', 'green');
			}
		} catch (parseError) {
			// JSON 파싱 실패 시 텍스트 출력 분석
			if (output.includes('No known security vulnerabilities found')) {
				results.status = 'secure';
				log('✅ No vulnerabilities found', 'green');
			} else {
				results.status = 'error';
				results.errors.push('Failed to parse safety check output');
				log('⚠️  Could not parse safety check output', 'yellow');
			}
		}
	} catch (error) {
		// safety가 설치되지 않은 경우
		if (error.message.includes('command not found') || error.message.includes('safety')) {
			results.status = 'tool_not_found';
			results.errors.push('safety package not found. Install with: poetry add safety --group dev');
			log('⚠️  safety package not found. Install with: poetry add safety --group dev', 'yellow');
		} else {
			results.status = 'error';
			results.errors.push(error.message);
			log(`❌ Security audit failed: ${error.message}`, 'red');
		}
	}

	return results;
}

/**
 * Node.js 프로젝트 보안 감사 (npm/pnpm audit)
 */
function auditNodejs(stackInfo) {
	log('🔍 Running Node.js security audit...', 'blue');
	
	const results = {
		stack: 'node',
		tool: stackInfo.packageManager || 'npm',
		status: 'unknown',
		vulnerabilities: [],
		errors: [],
	};

	try {
		// npm/pnpm audit 실행
		const command = stackInfo.packageManager === 'pnpm' 
			? 'pnpm audit --json' 
			: 'npm audit --json';

		const output = execSync(command, {
			cwd: PROJECT_ROOT,
			encoding: 'utf-8',
			stdio: 'pipe',
			timeout: 120000, // 120초 타임아웃
		});

		// npm/pnpm audit는 JSON 형식으로 출력
		try {
			const auditData = JSON.parse(output);
			
			// npm audit 출력 구조 분석
			if (auditData.vulnerabilities) {
				const vulnCount = Object.keys(auditData.vulnerabilities).length;
				if (vulnCount > 0) {
					results.status = 'vulnerable';
					results.vulnerabilities = Object.values(auditData.vulnerabilities).map(v => ({
						name: v.name,
						severity: v.severity,
						title: v.title,
						url: v.url,
					}));
					log(`❌ Found ${vulnCount} vulnerability(ies)`, 'red');
				} else {
					results.status = 'secure';
					log('✅ No vulnerabilities found', 'green');
				}
			} else if (auditData.metadata && auditData.metadata.vulnerabilities) {
				const vulnCount = auditData.metadata.vulnerabilities.total || 0;
				if (vulnCount > 0) {
					results.status = 'vulnerable';
					log(`❌ Found ${vulnCount} vulnerability(ies)`, 'red');
				} else {
					results.status = 'secure';
					log('✅ No vulnerabilities found', 'green');
				}
			} else {
				results.status = 'secure';
				log('✅ No vulnerabilities found', 'green');
			}
		} catch (parseError) {
			results.status = 'error';
			results.errors.push('Failed to parse audit output');
			log('⚠️  Could not parse audit output', 'yellow');
		}
	} catch (error) {
		// npm/pnpm이 설치되지 않은 경우
		if (error.message.includes('command not found')) {
			results.status = 'tool_not_found';
			results.errors.push(`${stackInfo.packageManager || 'npm'} not found`);
			log(`⚠️  ${stackInfo.packageManager || 'npm'} not found`, 'yellow');
		} else {
			results.status = 'error';
			results.errors.push(error.message);
			log(`❌ Security audit failed: ${error.message}`, 'red');
		}
	}

	return results;
}

/**
 * 메인 실행 함수
 */
function main() {
	const targetDir = process.argv[2] || null;

	log('🔒 Security Audit Agent', 'cyan');
	log('========================\n', 'cyan');

	// 1. 스택 감지
	log('1. Detecting stack...', 'blue');
	const stackInfo = detectStack();
	if (!stackInfo.stack) {
		log('❌ Could not detect project stack.', 'red');
		process.exit(1);
	}
	log(`   Detected stack: ${stackInfo.stack} (${stackInfo.packageManager})`, 'green');

	// 2. 스택별 보안 감사 실행
	log('\n2. Running security audit...', 'blue');
	let auditResult;

	if (stackInfo.stack === 'python') {
		auditResult = auditPython(stackInfo);
	} else if (stackInfo.stack === 'node') {
		auditResult = auditNodejs(stackInfo);
	} else {
		log(`⚠️  Security audit not supported for stack: ${stackInfo.stack}`, 'yellow');
		auditResult = {
			stack: stackInfo.stack,
			status: 'not_supported',
			message: `Security audit not supported for ${stackInfo.stack}`,
		};
	}

	// 3. 결과 출력 (JSON 형식)
	log('\n3. Audit Results:', 'blue');
	const jsonOutput = {
		timestamp: new Date().toISOString(),
		stack: stackInfo.stack,
		packageManager: stackInfo.packageManager,
		audit: auditResult,
	};

	console.log(JSON.stringify(jsonOutput, null, 2));

	// 4. 취약점이 발견된 경우 종료 코드 1 반환
	if (auditResult.status === 'vulnerable') {
		log('\n❌ Security vulnerabilities found. Please review and fix.', 'red');
		process.exit(1);
	} else if (auditResult.status === 'secure') {
		log('\n✅ Security audit passed.', 'green');
		process.exit(0);
	} else {
		// tool_not_found 또는 error 상태는 경고로 처리 (종료 코드 0)
		log('\n⚠️  Security audit completed with warnings.', 'yellow');
		process.exit(0);
	}
}

// 스크립트 직접 실행 시
if (require.main === module) {
	main();
}

module.exports = { detectStack, auditPython, auditNodejs };

