#!/usr/bin/env node
/**
 * verify-feedback-loop.js - 통합 검증 피드백 루프
 *
 * 목적: Phase 4의 auto_verify.sh와 Phase 5의 서브에이전트들을 통합하여 완전한 검증 피드백 루프를 구현합니다.
 * Plan -> Build -> Verify -> Approve 프로세스를 통합하여 코드 품질을 극대화합니다.
 *
 * 사용법:
 *   node scripts/verify-feedback-loop.js
 *
 * 워크플로우:
 *   1. Plan 단계 확인 (Shrimp Task Manager)
 *   2. Build 단계 (이미 완료되었다고 가정)
 *   3. Verify 단계:
 *      a. 기본 검증 (auto_verify.sh)
 *      b. 코드 단순화 검증 (simplifier.js)
 *      c. 시각적 검증 (visual_verifier.js, 웹 프로젝트인 경우)
 *      d. 데이터 기반 검증 (Proxymock MCP, API 프로젝트인 경우)
 *   4. Approve 단계: 사용자 승인 및 CLAUDE.md 업데이트
 *
 * 제약사항:
 *   - 모든 검증은 제안 기반이며, 사용자 승인 없이 수정하지 않습니다.
 *   - MCP 통합 부분은 AI 에이전트가 직접 수행해야 합니다.
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
const AGENTS_DIR = path.join(PROJECT_ROOT, 'scripts/agents');

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
 * Step 1: Plan 단계 확인
 */
async function checkPlanStep() {
	log('\n📋 Step 1: Plan Verification', 'cyan');
	log('==============================\n', 'cyan');

	// Shrimp Task Manager 확인 (선택적)
	// 실제로는 Shrimp Task Manager API를 호출하지만, 여기서는 기본 확인만 수행
	log('💡 Note: Plan step verification requires Shrimp Task Manager integration.', 'yellow');
	log('   For now, assuming plan is complete.', 'yellow');

	verificationResults.steps.plan.status = 'completed';
	verificationResults.steps.plan.message = 'Plan step verified (manual check recommended)';

	log('✅ Plan step: Completed', 'green');
}

/**
 * Step 2: Build 단계 확인
 */
async function checkBuildStep() {
	log('\n🔨 Step 2: Build Verification', 'cyan');
	log('==============================\n', 'cyan');

	log('💡 Note: Build step assumes code has been written.', 'yellow');
	log('   This script focuses on verification, not building.', 'yellow');

	verificationResults.steps.build.status = 'completed';
	verificationResults.steps.build.message = 'Build step assumed complete (code written)';

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
 * Step 3b: 코드 단순화 검증 (simplifier.js)
 */
async function runSimplifierVerification() {
	log('\n🔧 Step 3b: Code Simplification Verification (simplifier.js)', 'cyan');
	log('===========================================================\n', 'cyan');

	try {
		const simplifierScript = path.join(AGENTS_DIR, 'simplifier.js');
		if (!fs.existsSync(simplifierScript)) {
			throw new Error('simplifier.js not found');
		}

		log('Running simplifier.js...', 'blue');
		const output = execSync(`node ${simplifierScript}`, {
			cwd: PROJECT_ROOT,
			encoding: 'utf-8',
			stdio: 'pipe',
		});

		// JSON 출력 부분 추출
		const jsonMatch = output.match(/--- JSON Output ---\s*([\s\S]*)/);
		if (jsonMatch) {
			try {
				const jsonData = JSON.parse(jsonMatch[1]);
				verificationResults.steps.verify.simplifier.suggestions = jsonData.suggestions || [];
			} catch (parseError) {
				// JSON 파싱 실패 시 무시
			}
		}

		verificationResults.steps.verify.simplifier.status = 'completed';
		verificationResults.steps.verify.simplifier.message = 'Code simplification analysis completed';
		log('✅ Code simplification: Analysis completed', 'green');
		console.log(output);
	} catch (error) {
		verificationResults.steps.verify.simplifier.status = 'failed';
		verificationResults.steps.verify.simplifier.message = error.message;
		log('⚠️  Code simplification: Analysis failed', 'yellow');
		log(`   Error: ${error.message}`, 'yellow');
	}
}

/**
 * Step 3c: 보안 감사 (security-audit.js)
 */
async function runSecurityAudit(stackInfo) {
	log('\n🔒 Step 3c: Security Audit (security-audit.js)', 'cyan');
	log('=============================================\n', 'cyan');

	try {
		const securityScript = path.join(AGENTS_DIR, 'security-audit.js');
		if (!fs.existsSync(securityScript)) {
			throw new Error('security-audit.js not found');
		}

		log('Running security-audit.js...', 'blue');
		const output = execSync(`node ${securityScript}`, {
			cwd: PROJECT_ROOT,
			encoding: 'utf-8',
			stdio: 'pipe',
		});

		// JSON 출력 부분 추출
		const jsonMatch = output.match(/\{[\s\S]*\}/);
		if (jsonMatch) {
			try {
				const jsonData = JSON.parse(jsonMatch[0]);
				if (jsonData.audit) {
					verificationResults.steps.verify.security.vulnerabilities = jsonData.audit.vulnerabilities || [];
					verificationResults.steps.verify.security.errors = jsonData.audit.errors || [];
					
					if (jsonData.audit.status === 'vulnerable') {
						verificationResults.steps.verify.security.status = 'failed';
						verificationResults.steps.verify.security.message = `Found ${jsonData.audit.vulnerabilities.length} vulnerability(ies)`;
						log(`❌ Security audit: Found ${jsonData.audit.vulnerabilities.length} vulnerability(ies)`, 'red');
					} else if (jsonData.audit.status === 'secure') {
						verificationResults.steps.verify.security.status = 'completed';
						verificationResults.steps.verify.security.message = 'No vulnerabilities found';
						log('✅ Security audit: No vulnerabilities found', 'green');
					} else {
						verificationResults.steps.verify.security.status = 'warning';
						verificationResults.steps.verify.security.message = jsonData.audit.message || 'Security audit completed with warnings';
						log('⚠️  Security audit: Completed with warnings', 'yellow');
					}
				}
			} catch (parseError) {
				// JSON 파싱 실패 시 무시
				verificationResults.steps.verify.security.status = 'error';
				verificationResults.steps.verify.security.message = 'Failed to parse security audit output';
			}
		}

		console.log(output);
	} catch (error) {
		// security-audit.js가 종료 코드 1을 반환한 경우 (취약점 발견)
		if (error.status === 1) {
			verificationResults.steps.verify.security.status = 'failed';
			verificationResults.steps.verify.security.message = 'Security vulnerabilities found';
			log('❌ Security audit: Vulnerabilities found', 'red');
		} else {
			verificationResults.steps.verify.security.status = 'failed';
			verificationResults.steps.verify.security.message = error.message;
			log('⚠️  Security audit: Failed', 'yellow');
			log(`   Error: ${error.message}`, 'yellow');
		}
	}
}

/**
 * Step 3d: 로컬 로그 분석 (log_analyzer.js)
 */
async function runLogAnalysis(stackInfo) {
	log('\n📋 Step 3d: Local Log Analysis (log_analyzer.js)', 'cyan');
	log('================================================\n', 'cyan');

	try {
		const logAnalyzerScript = path.join(AGENTS_DIR, 'log_analyzer.js');
		if (!fs.existsSync(logAnalyzerScript)) {
			throw new Error('log_analyzer.js not found');
		}

		log('Running log_analyzer.js...', 'blue');
		const output = execSync(`node ${logAnalyzerScript} "${PROJECT_ROOT}"`, {
			cwd: PROJECT_ROOT,
			encoding: 'utf-8',
			stdio: 'pipe',
		});

		// JSON 출력 부분 추출
		const jsonMatch = output.match(/\{[\s\S]*\}/);
		if (jsonMatch) {
			try {
				const jsonData = JSON.parse(jsonMatch[0]);
				if (jsonData.status === 'failed') {
					verificationResults.steps.verify.log_analysis = {
						status: 'failed',
						message: `Found ${jsonData.summary.error_count} error(s) and ${jsonData.summary.critical_count} critical(s) in logs`,
						errors: jsonData.errors || [],
						criticals: jsonData.criticals || [],
						code_analysis_guides: jsonData.code_analysis_guides || [],
					};
					log(`❌ Log analysis: Found severe errors in logs`, 'red');
					log(`   Errors: ${jsonData.summary.error_count}, Criticals: ${jsonData.summary.critical_count}`, 'red');
				} else {
					verificationResults.steps.verify.log_analysis = {
						status: 'completed',
						message: 'No severe errors found in logs',
						summary: jsonData.summary,
					};
					log('✅ Log analysis: No severe errors found', 'green');
				}
			} catch (parseError) {
				verificationResults.steps.verify.log_analysis = {
					status: 'error',
					message: 'Failed to parse log analysis output',
				};
				log('⚠️  Log analysis: Failed to parse output', 'yellow');
			}
		}

		console.log(output);
	} catch (error) {
		// log_analyzer.js가 종료 코드 1을 반환한 경우 (심각한 에러 발견)
		if (error.status === 1) {
			verificationResults.steps.verify.log_analysis = {
				status: 'failed',
				message: 'Severe errors found in logs',
			};
			log('❌ Log analysis: Severe errors found', 'red');
		} else {
			verificationResults.steps.verify.log_analysis = {
				status: 'failed',
				message: error.message,
			};
			log('⚠️  Log analysis: Failed', 'yellow');
			log(`   Error: ${error.message}`, 'yellow');
		}
	}
}

/**
 * Step 3e: 시각적 검증 (visual_verifier.js, 웹 프로젝트인 경우)
 */
async function runVisualVerification(stackInfo) {
	log('\n👁️  Step 3c: Visual Verification (visual_verifier.js)', 'cyan');
	log('====================================================\n', 'cyan');

	// 웹 프로젝트인지 확인
	const { isWebProject } = require(path.join(AGENTS_DIR, 'visual_verifier.js'));
	if (!isWebProject(stackInfo)) {
		verificationResults.steps.verify.visual.status = 'skipped';
		verificationResults.steps.verify.visual.message = 'Not a web project, skipping visual verification';
		log('⚠️  Visual verification: Skipped (not a web project)', 'yellow');
		return;
	}

	try {
		const visualVerifierScript = path.join(AGENTS_DIR, 'visual_verifier.js');
		if (!fs.existsSync(visualVerifierScript)) {
			throw new Error('visual_verifier.js not found');
		}

		log('Running visual_verifier.js...', 'blue');
		const output = execSync(`node ${visualVerifierScript}`, {
			cwd: PROJECT_ROOT,
			encoding: 'utf-8',
			stdio: 'pipe',
		});

		// JSON 리포트 부분 추출
		const jsonMatch = output.match(/--- JSON Report ---\s*([\s\S]*)/);
		if (jsonMatch) {
			try {
				const jsonData = JSON.parse(jsonMatch[1]);
				verificationResults.steps.verify.visual.guide = jsonData;
			} catch (parseError) {
				// JSON 파싱 실패 시 무시
			}
		}

		verificationResults.steps.verify.visual.status = 'completed';
		verificationResults.steps.verify.visual.message = 'Visual verification guide generated';
		log('✅ Visual verification: Guide generated', 'green');
		log('💡 Note: Use Chrome DevTools MCP to perform actual verification.', 'yellow');
		console.log(output);
	} catch (error) {
		verificationResults.steps.verify.visual.status = 'failed';
		verificationResults.steps.verify.visual.message = error.message;
		log('⚠️  Visual verification: Failed', 'yellow');
		log(`   Error: ${error.message}`, 'yellow');
	}
}

/**
 * Step 3d: 데이터 기반 검증 (Proxymock MCP, API 프로젝트인 경우)
 */
async function runProxymockVerification(stackInfo) {
	log('\n📊 Step 3d: Data-based Verification (Proxymock MCP)', 'cyan');
	log('==================================================\n', 'cyan');

	// API 프로젝트인지 확인 (간단한 휴리스틱)
	const isAPIProject = stackInfo.stack === 'node' || stackInfo.stack === 'python';
	if (!isAPIProject) {
		verificationResults.steps.verify.proxymock.status = 'skipped';
		verificationResults.steps.verify.proxymock.message = 'Not an API project, skipping Proxymock verification';
		log('⚠️  Proxymock verification: Skipped (not an API project)', 'yellow');
		return;
	}

	log('💡 Note: Proxymock MCP verification requires AI agent integration.', 'yellow');
	log('   Use Proxymock MCP to replay production traffic and verify edge cases.', 'yellow');

	verificationResults.steps.verify.proxymock.status = 'pending';
	verificationResults.steps.verify.proxymock.message = 'Proxymock MCP verification guide';
	verificationResults.steps.verify.proxymock.guide = {
		description: 'Use Proxymock MCP to replay production traffic',
		steps: [
			'1. Connect to Proxymock MCP server',
			'2. Select production traffic pattern to replay',
			'3. Run replay in sandbox environment',
			'4. Verify API responses match expected patterns',
			'5. Check for edge cases and error handling',
		],
	};

	log('✅ Proxymock verification: Guide provided', 'green');
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
	log(`   Visual Verification: ${verificationResults.steps.verify.visual.status}`, 'yellow');
	log(`   Proxymock Verification: ${verificationResults.steps.verify.proxymock.status}`, 'yellow');

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
				log(`   - [${error.level}] ${error.module}:${error.funcName}:${error.lineno} - ${error.message}`, 'red');
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
			const { updateClaudeMD } = require(path.join(AGENTS_DIR, 'update_claude_knowledge.js'));
			updateClaudeMD(verificationResults);
			log('✅ CLAUDE.md updated successfully', 'green');
		} catch (error) {
			log(`⚠️  Failed to update CLAUDE.md: ${error.message}`, 'yellow');
			log('   Verification results are still available in JSON output.', 'yellow');
		}

		// Shrimp Task Manager 연동 (선택적)
		log('\n💡 Note: Shrimp Task Manager integration should be implemented here.', 'yellow');
		log('   Use Shrimp Task Manager MCP to update task status.', 'yellow');

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
	log('🔄 Integrated Verification Feedback Loop', 'cyan');
	log('========================================\n', 'cyan');

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

	// 3b. 코드 단순화 검증
	await runSimplifierVerification();

	// 3c. 보안 감사
	await runSecurityAudit(stackInfo);

	// 3d. 로컬 로그 분석
	await runLogAnalysis(stackInfo);

	// 3e. 시각적 검증 (웹 프로젝트인 경우)
	await runVisualVerification(stackInfo);

	// 3f. 데이터 기반 검증 (API 프로젝트인 경우)
	await runProxymockVerification(stackInfo);

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
	checkPlanStep,
	checkBuildStep,
	runBasicVerification,
	runSimplifierVerification,
	runVisualVerification,
	runProxymockVerification,
	runApproveStep,
};

