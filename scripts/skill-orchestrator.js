#!/usr/bin/env node
/**
 * skill-orchestrator.js - Agent Skills 통합 실행 관리자
 *
 * 목적: skills/ 디렉토리의 모든 스킬을 동적으로 로드하고 실행하여 통합 검증 피드백 루프를 구현합니다.
 * Claude Agent Skills 표준 구조를 따르는 스킬들을 통합 관리합니다.
 *
 * 사용법:
 *   node scripts/skill-orchestrator.js
 *
 * 워크플로우:
 *   1. Plan 단계 확인 (Shrimp Task Manager)
 *   2. Build 단계 (이미 완료되었다고 가정)
 *   3. Verify 단계: skills/ 디렉토리의 스킬들을 동적으로 실행
 *   4. Approve 단계: 사용자 승인 및 CLAUDE.md 업데이트
 *
 * 제약사항:
 *   - 모든 검증은 제안 기반이며, 사용자 승인 없이 수정하지 않습니다.
 *   - 스킬은 Claude Agent Skills 표준 구조를 따라야 함 (run.js, instructions.md, schema.json)
 */

const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const readline = require('readline');

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

// 프로젝트 루트 디렉토리 찾기
const SCRIPT_DIR = __dirname;
const PROJECT_ROOT = path.resolve(SCRIPT_DIR, '..');
const CORE_DIR = path.join(PROJECT_ROOT, 'scripts/core');
const SKILLS_DIR = path.join(PROJECT_ROOT, 'skills');

// 검증 결과 수집
const verificationResults = {
	timestamp: new Date().toISOString(),
	steps: {
		plan: { status: 'pending', message: '' },
		build: { status: 'pending', message: '' },
		verify: {
			basic: { status: 'pending', message: '', errors: [] },
			simplifier: { status: 'pending', message: '', suggestions: [] },
			security: { status: 'pending', message: '', vulnerabilities: [], errors: [] },
			log_analysis: { status: 'pending', message: '', errors: [], criticals: [], code_analysis_guides: [] },
			visual: { status: 'pending', message: '', guide: null },
			proxymock: { status: 'pending', message: '', guide: null },
		},
		approve: { status: 'pending', message: '' },
	},
};

/**
 * 사용자 입력 받기
 */
function askUser(question) {
	const rl = readline.createInterface({
		input: process.stdin,
		output: process.stdout,
	});

	return new Promise((resolve) => {
		rl.question(question, (answer) => {
			rl.close();
			resolve(answer.trim().toLowerCase());
		});
	});
}

/**
 * detect_stack.sh를 실행하여 스택 정보를 가져옵니다.
 */
function detectStack() {
	try {
		const detectScript = path.join(CORE_DIR, 'detect_stack.sh');
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
		log('⚠️  Stack detection failed.', 'yellow');
		return { stack: null, packageManager: null };
	}
}

/**
 * skills/ 디렉토리를 스캔하여 모든 스킬을 찾습니다.
 */
function discoverSkills() {
	if (!fs.existsSync(SKILLS_DIR)) {
		log(`⚠️  Skills directory not found: ${SKILLS_DIR}`, 'yellow');
		return [];
	}

	const skills = [];
	const entries = fs.readdirSync(SKILLS_DIR, { withFileTypes: true });

	for (const entry of entries) {
		if (entry.isDirectory()) {
			const skillDir = path.join(SKILLS_DIR, entry.name);
			const runJsPath = path.join(skillDir, 'run.js');
			const schemaJsonPath = path.join(skillDir, 'schema.json');
			const instructionsMdPath = path.join(skillDir, 'instructions.md');

			if (fs.existsSync(runJsPath)) {
				skills.push({
					name: entry.name,
					path: skillDir,
					runJs: runJsPath,
					schemaJson: fs.existsSync(schemaJsonPath) ? schemaJsonPath : null,
					instructionsMd: fs.existsSync(instructionsMdPath) ? instructionsMdPath : null,
				});
			}
		}
	}

	return skills;
}

/**
 * 스킬을 실행합니다.
 */
async function executeSkill(skill, params = {}) {
	try {
		log(`\n🔧 Executing skill: ${skill.name}`, 'cyan');
		
		// 스킬 실행 (CLI 방식)
		// 파라미터가 있으면 argv로 전달
		const args = [];
		if (params.target_directory) {
			args.push(params.target_directory);
		}
		if (params.log_file_path) {
			args.push(params.log_file_path);
		}
		if (params.port) {
			args.push(params.port.toString());
		}

		const output = execSync(`node ${skill.runJs} ${args.join(' ')}`, {
			cwd: PROJECT_ROOT,
			encoding: 'utf-8',
			stdio: 'pipe',
		});

		// JSON 출력 추출 시도
		let jsonResult = null;
		
		// 다양한 JSON 출력 패턴 시도
		const jsonPatterns = [
			/--- JSON Output ---\s*([\s\S]*?)(?=---|$)/,
			/--- JSON Report ---\s*([\s\S]*?)(?=---|$)/,
			/--- Log Analysis Results \(JSON\) ---\s*([\s\S]*)/,
			/\{[\s\S]*\}/,
		];

		for (const pattern of jsonPatterns) {
			const match = output.match(pattern);
			if (match) {
				try {
					jsonResult = JSON.parse(match[1] || match[0]);
					break;
				} catch (parseError) {
					// 다음 패턴 시도
				}
			}
		}

		console.log(output);

		return {
			success: true,
			output: output,
			json: jsonResult,
		};
	} catch (error) {
		// 스킬 실행 실패 (종료 코드 1 등)
		log(`⚠️  Skill execution failed: ${error.message}`, 'yellow');
		
		// stdout은 출력되어 있을 수 있음
		const output = error.stdout || '';
		
		// JSON 출력 추출 시도
		let jsonResult = null;
		const jsonMatch = output.match(/\{[\s\S]*\}/);
		if (jsonMatch) {
			try {
				jsonResult = JSON.parse(jsonMatch[0]);
			} catch (parseError) {
				// JSON 파싱 실패
			}
		}

		return {
			success: false,
			error: error.message,
			output: output,
			json: jsonResult,
		};
	}
}

/**
 * Step 1: Plan 확인
 */
async function checkPlanStep() {
	log('\n📋 Step 1: Plan Check', 'cyan');
	log('=====================\n', 'cyan');

	// Shrimp Task Manager 확인 (선택적)
	log('💡 Note: Plan verification with Shrimp Task Manager should be performed here.', 'yellow');
	log('   Use Shrimp Task Manager MCP to check task status.', 'yellow');

	verificationResults.steps.plan.status = 'completed';
	verificationResults.steps.plan.message = 'Plan check completed';
	log('✅ Plan step: Completed', 'green');
}

/**
 * Step 2: Build 확인
 */
async function checkBuildStep() {
	log('\n🔨 Step 2: Build Check', 'cyan');
	log('=====================\n', 'cyan');

	log('💡 Note: Build verification should be performed here.', 'yellow');
	log('   Assuming build is already completed.', 'yellow');

	verificationResults.steps.build.status = 'completed';
	verificationResults.steps.build.message = 'Build check completed';
	log('✅ Build step: Completed', 'green');
}

/**
 * Step 3a: 기본 검증 (auto_verify.sh)
 */
async function runBasicVerification() {
	log('\n🔍 Step 3a: Basic Verification (auto_verify.sh)', 'cyan');
	log('================================================\n', 'cyan');

	try {
		const autoVerifyScript = path.join(CORE_DIR, 'auto_verify.sh');
		if (!fs.existsSync(autoVerifyScript)) {
			throw new Error('auto_verify.sh not found');
		}

		log('Running auto_verify.sh...', 'blue');
		const output = execSync(`bash ${autoVerifyScript}`, {
			cwd: PROJECT_ROOT,
			encoding: 'utf-8',
			stdio: 'pipe',
		});

		verificationResults.steps.verify.basic.status = 'passed';
		verificationResults.steps.verify.basic.message = 'Basic verification passed';
		log('✅ Basic verification: Passed', 'green');
		console.log(output);
	} catch (error) {
		verificationResults.steps.verify.basic.status = 'failed';
		verificationResults.steps.verify.basic.message = error.message;
		verificationResults.steps.verify.basic.errors.push(error.message);
		log('❌ Basic verification: Failed', 'red');
		log(`   Error: ${error.message}`, 'red');
	}
}

/**
 * Step 3: Verify - 스킬 실행
 */
async function runVerifySkills(stackInfo) {
	const skills = discoverSkills();
	log(`\n📦 Discovered ${skills.length} skill(s)`, 'blue');

	// 스킬 매핑 (스킬 이름 -> verificationResults 키)
	const skillMapping = {
		'simplifier': 'simplifier',
		'security-audit': 'security',
		'log-analyzer': 'log_analysis',
		'visual-verifier': 'visual',
	};

	for (const skill of skills) {
		// 특정 스킬만 실행 (claude-knowledge-updater는 approve 단계에서 사용)
		if (skill.name === 'claude-knowledge-updater') {
			continue;
		}

		const resultKey = skillMapping[skill.name];
		if (!resultKey) {
			log(`⚠️  Unknown skill: ${skill.name}, skipping`, 'yellow');
			continue;
		}

		// 조건부 실행 확인
		if (skill.name === 'visual-verifier') {
			// 웹 프로젝트인지 확인
			try {
				const { isWebProject } = require(skill.runJs);
				if (!isWebProject(stackInfo)) {
					verificationResults.steps.verify[resultKey].status = 'skipped';
					verificationResults.steps.verify[resultKey].message = 'Not a web project, skipping visual verification';
					log(`⚠️  ${skill.name}: Skipped (not a web project)`, 'yellow');
					continue;
				}
			} catch (error) {
				// isWebProject 함수가 없으면 실행 시도
			}
		}

		// 스킬 실행
		const result = await executeSkill(skill);

		// 결과 처리
		if (result.success) {
			verificationResults.steps.verify[resultKey].status = 'completed';
			verificationResults.steps.verify[resultKey].message = `${skill.name} verification completed`;

			// JSON 결과 처리
			if (result.json) {
				if (resultKey === 'simplifier' && result.json.suggestions) {
					verificationResults.steps.verify[resultKey].suggestions = result.json.suggestions;
				} else if (resultKey === 'security' && result.json.audit) {
					verificationResults.steps.verify[resultKey].vulnerabilities = result.json.audit.vulnerabilities || [];
					verificationResults.steps.verify[resultKey].errors = result.json.audit.errors || [];
					if (result.json.audit.status === 'vulnerable') {
						verificationResults.steps.verify[resultKey].status = 'failed';
					}
				} else if (resultKey === 'log_analysis') {
					verificationResults.steps.verify[resultKey].errors = result.json.errors || [];
					verificationResults.steps.verify[resultKey].criticals = result.json.criticals || [];
					verificationResults.steps.verify[resultKey].code_analysis_guides = result.json.code_analysis_guides || [];
					if (result.json.status === 'failed') {
						verificationResults.steps.verify[resultKey].status = 'failed';
					}
				} else if (resultKey === 'visual' && result.json) {
					verificationResults.steps.verify[resultKey].guide = result.json;
				}
			}

			log(`✅ ${skill.name}: Completed`, 'green');
		} else {
			verificationResults.steps.verify[resultKey].status = 'failed';
			verificationResults.steps.verify[resultKey].message = result.error || 'Skill execution failed';
			log(`⚠️  ${skill.name}: Failed`, 'yellow');
		}
	}
}

/**
 * Step 4: Approve 단계
 */
async function runApproveStep() {
	log('\n✅ Step 4: Approval', 'cyan');
	log('==================\n', 'cyan');

	// 검증 결과 요약
	log('📊 Verification Summary:', 'blue');
	log(`   Basic Verification: ${verificationResults.steps.verify.basic.status}`, verificationResults.steps.verify.basic.status === 'passed' ? 'green' : 'red');
	log(`   Code Simplification: ${verificationResults.steps.verify.simplifier.status}`, 'yellow');
	log(`   Security Audit: ${verificationResults.steps.verify.security.status}`, verificationResults.steps.verify.security.status === 'completed' ? 'green' : verificationResults.steps.verify.security.status === 'failed' ? 'red' : 'yellow');
	log(`   Log Analysis: ${verificationResults.steps.verify.log_analysis.status}`, verificationResults.steps.verify.log_analysis.status === 'completed' ? 'green' : verificationResults.steps.verify.log_analysis.status === 'failed' ? 'red' : 'yellow');
	log(`   Visual Verification: ${verificationResults.steps.verify.visual.status}`, 'yellow');

	// 문제가 있는 경우 요약
	const hasErrors = verificationResults.steps.verify.basic.status === 'failed';
	const hasSuggestions = verificationResults.steps.verify.simplifier.suggestions.length > 0;
	const hasVulnerabilities = verificationResults.steps.verify.security.status === 'failed';
	const hasLogErrors = verificationResults.steps.verify.log_analysis?.status === 'failed';

	if (hasErrors) {
		log('\n❌ Errors found during verification:', 'red');
		for (const error of verificationResults.steps.verify.basic.errors) {
			log(`   - ${error}`, 'red');
		}
	}

	if (hasSuggestions) {
		log(`\n💡 Found ${verificationResults.steps.verify.simplifier.suggestions.length} code simplification suggestion(s)`, 'yellow');
	}

	if (hasVulnerabilities) {
		log('\n🔒 Security vulnerabilities found:', 'red');
		for (const vuln of verificationResults.steps.verify.security.vulnerabilities.slice(0, 5)) {
			log(`   - ${vuln.name || vuln.title || 'Unknown'}: ${vuln.severity || 'Unknown severity'}`, 'red');
		}
	}

	if (hasLogErrors) {
		log('\n📋 Severe errors found in local logs:', 'red');
		const logAnalysis = verificationResults.steps.verify.log_analysis;
		if (logAnalysis.errors && logAnalysis.errors.length > 0) {
			for (const error of logAnalysis.errors.slice(0, 5)) {
				log(`   - [${error.level || error.levelname}] ${error.module}:${error.funcName}:${error.lineno} - ${error.message}`, 'red');
			}
		}
		if (logAnalysis.criticals && logAnalysis.criticals.length > 0) {
			for (const critical of logAnalysis.criticals.slice(0, 5)) {
				log(`   - [CRITICAL] ${critical.module}:${critical.funcName}:${critical.lineno} - ${critical.message}`, 'red');
			}
		}
		log('   💡 Use Codanna/Serena MCP to analyze related source code.', 'yellow');
	}

	// 사용자 승인 요청
	log('\n🤔 Do you want to approve these changes?', 'cyan');
	log('   [A]pprove - Accept verification results and update CLAUDE.md', 'blue');
	log('   [R]eject - Reject and fix issues', 'blue');
	log('   [S]kip - Skip approval step', 'blue');

	const answer = await askUser('\nYour choice (A/R/S): ');

	if (answer === 'a' || answer === 'approve') {
		verificationResults.steps.approve.status = 'approved';
		verificationResults.steps.approve.message = 'User approved verification results';
		log('\n✅ Approval: Accepted', 'green');

		// CLAUDE.md 업데이트
		try {
			log('\n📝 Updating CLAUDE.md with verification results...', 'blue');
			const claudeUpdaterSkill = discoverSkills().find(s => s.name === 'claude-knowledge-updater');
			if (claudeUpdaterSkill) {
				const { updateClaudeMD } = require(claudeUpdaterSkill.runJs);
				updateClaudeMD(verificationResults);
				log('✅ CLAUDE.md updated successfully', 'green');
			} else {
				log('⚠️  claude-knowledge-updater skill not found', 'yellow');
			}
		} catch (error) {
			log(`⚠️  Failed to update CLAUDE.md: ${error.message}`, 'yellow');
			log('   Verification results are still available in JSON output.', 'yellow');
		}

		return true;
	} else if (answer === 'r' || answer === 'reject') {
		verificationResults.steps.approve.status = 'rejected';
		verificationResults.steps.approve.message = 'User rejected verification results';
		log('\n❌ Approval: Rejected', 'red');
		log('   Please fix the issues and run verification again.', 'yellow');
		return false;
	} else {
		verificationResults.steps.approve.status = 'skipped';
		verificationResults.steps.approve.message = 'User skipped approval';
		log('\n⚠️  Approval: Skipped', 'yellow');
		return false;
	}
}

/**
 * 검증 결과를 JSON으로 출력
 */
function outputResults() {
	log('\n--- Verification Results (JSON) ---', 'cyan');
	console.log(JSON.stringify(verificationResults, null, 2));
}

/**
 * 메인 실행 함수
 */
async function main() {
	log('🔄 Agent Skills Orchestrator', 'cyan');
	log('================================\n', 'cyan');

	// 스택 감지
	const stackInfo = detectStack();
	if (!stackInfo.stack) {
		log('❌ Could not detect project stack.', 'red');
		process.exit(1);
	}
	log(`📋 Detected stack: ${stackInfo.stack} (${stackInfo.packageManager})\n`, 'green');

	// Step 1: Plan 확인
	await checkPlanStep();

	// Step 2: Build 확인
	await checkBuildStep();

	// Step 3: Verify
	log('\n🔍 Step 3: Verification', 'cyan');
	log('========================\n', 'cyan');

	// 3a. 기본 검증
	await runBasicVerification();

	// 3b. 스킬 실행
	await runVerifySkills(stackInfo);

	// Step 4: Approve
	const approved = await runApproveStep();

	// 보안 취약점이 있는 경우 승인 여부와 관계없이 경고
	const securityStatus = verificationResults.steps.verify.security?.status;
	if (securityStatus === 'failed') {
		log('\n⚠️  WARNING: Security vulnerabilities were found during verification.', 'yellow');
		log('   Even if approved, please review and fix vulnerabilities before merging.', 'yellow');
	}

	// 결과 출력
	outputResults();

	// 종료 코드: 보안 취약점이 있으면 실패로 처리
	if (securityStatus === 'failed') {
		log('\n❌ Verification failed due to security vulnerabilities.', 'red');
		process.exit(1);
	}

	process.exit(approved ? 0 : 1);
}

// 스크립트 직접 실행 시
if (require.main === module) {
	main().catch((error) => {
		log(`\n❌ Fatal error: ${error.message}`, 'red');
		console.error(error);
		process.exit(1);
	});
}

module.exports = {
	discoverSkills,
	executeSkill,
	checkPlanStep,
	checkBuildStep,
	runBasicVerification,
	runVerifySkills,
	runApproveStep,
};

