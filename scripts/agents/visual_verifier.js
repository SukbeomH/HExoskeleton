#!/usr/bin/env node
/**
 * visual_verifier.js - 시각적 검증 서브에이전트
 *
 * 목적: Chrome DevTools MCP와 연계하여 웹 프로젝트의 렌더링 및 네트워크 문제를 검증합니다.
 * 브라우저를 실행하여 UI가 깨지지 않았는지, 콘솔 에러가 없는지, 네트워크 요청이 올바르게 처리되는지 확인합니다.
 *
 * 사용법:
 *   node scripts/agents/visual_verifier.js [포트 번호]
 *
 * 제약사항:
 *   - 웹 프로젝트인 경우에만 실행됩니다.
 *   - 개발 서버가 실행 중이어야 합니다 (자동 시작 시도).
 *   - Chrome DevTools MCP는 AI 에이전트(Cursor 등)가 직접 호출해야 합니다.
 *     이 스크립트는 검증 환경을 준비하고 검증 가이드를 제공합니다.
 *
 * MCP 통합:
 *   - Chrome DevTools MCP의 browser_navigate, browser_snapshot, browser_console_messages,
 *     browser_network_requests 도구를 사용합니다.
 *   - 실제 MCP 호출은 AI 에이전트가 수행합니다.
 */

const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const http = require('http');

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
const BOILERPLATE_ROOT = path.resolve(SCRIPT_DIR, '../..');
const CORE_DIR = path.join(BOILERPLATE_ROOT, 'scripts/core');

/**
 * detect_stack.sh를 실행하여 스택 정보를 가져옵니다.
 *
 * @param {string|null} targetDir - 대상 프로젝트 경로 (선택적)
 * @returns {Object} 스택 정보
 */
function detectStack(targetDir = null) {
	const targetProjectRoot = targetDir ? path.resolve(targetDir) : process.cwd();

	try {
		const detectScript = path.join(CORE_DIR, 'detect_stack.sh');
		const output = execSync(
			`bash -c 'source ${detectScript} && echo "STACK=$DETECTED_STACK" && echo "PACKAGE_MANAGER=$DETECTED_PACKAGE_MANAGER"'`,
			{ cwd: targetProjectRoot, encoding: 'utf-8', stdio: 'pipe' }
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
 * 웹 프로젝트 여부 확인
 *
 * @param {Object} stackInfo - 스택 정보
 * @param {string} projectRoot - 프로젝트 루트 경로
 */
function isWebProject(stackInfo, projectRoot) {
	if (stackInfo.stack !== 'node') {
		return false;
	}

	const packageJsonPath = path.join(projectRoot, 'package.json');
	if (!fs.existsSync(packageJsonPath)) {
		return false;
	}

	try {
		const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf-8'));

		// packageJson 구조 검증
		if (!packageJson || typeof packageJson !== 'object') {
			return false;
		}

		const dependencies = {
			...(packageJson.dependencies || {}),
			...(packageJson.devDependencies || {}),
		};

		// 웹 프레임워크 감지
		const webFrameworks = [
			'react',
			'vue',
			'angular',
			'svelte',
			'next',
			'nuxt',
			'remix',
			'sveltekit',
			'express',
			'fastify',
			'koa',
		];

		return webFrameworks.some((fw) => dependencies[fw] || dependencies[`@${fw}`]);
	} catch (error) {
		return false;
	}
}

/**
 * 개발 서버 포트 확인
 */
function findDevServerPort() {
	const commonPorts = [3000, 3001, 5173, 8080, 8000, 4200, 5000];
	for (const port of commonPorts) {
		try {
			http.get(`http://localhost:${port}`, (res) => {
				// 서버가 응답하면 포트가 사용 중
			}).on('error', () => {
				// 연결 실패는 정상 (서버가 없음)
			});
		} catch (error) {
			// 무시
		}
	}
	return commonPorts[0]; // 기본 포트
}

/**
 * 개발 서버 시작 시도
 *
 * @param {Object} stackInfo - 스택 정보
 * @param {string} projectRoot - 프로젝트 루트 경로
 * @param {number} port - 포트 번호
 */
function startDevServer(stackInfo, projectRoot, port = 3000) {
	const packageJsonPath = path.join(projectRoot, 'package.json');
	if (!fs.existsSync(packageJsonPath)) {
		return null;
	}

	try {
		const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf-8'));

		// packageJson 구조 검증
		if (!packageJson || typeof packageJson !== 'object') {
			return null;
		}

		const scripts = packageJson.scripts || {};

		// 개발 서버 시작 명령어 찾기
		const devCommands = ['dev', 'start', 'serve', 'develop'];
		let devCommand = null;

		for (const cmd of devCommands) {
			if (scripts[cmd]) {
				devCommand = scripts[cmd];
				break;
			}
		}

		if (!devCommand) {
			log('⚠️  No dev server script found in package.json', 'yellow');
			return null;
		}

		log(`🚀 Starting dev server: ${stackInfo.packageManager} run ${devCommands.find((c) => scripts[c])}`, 'blue');

		// 개발 서버 시작 (백그라운드)
		const packageManager = stackInfo.packageManager || 'npm';
		const command = packageManager === 'pnpm' ? 'pnpm' : packageManager === 'yarn' ? 'yarn' : 'npm';
		const scriptName = devCommands.find((c) => scripts[c]);

		const serverProcess = spawn(command, ['run', scriptName], {
			cwd: projectRoot,
			stdio: 'inherit',
			detached: true,
		});

		serverProcess.unref();

		log(`✅ Dev server started (PID: ${serverProcess.pid})`, 'green');
		log(`   Access at: http://localhost:${port}`, 'blue');
		log(`   To stop: kill ${serverProcess.pid}`, 'yellow');

		return serverProcess;
	} catch (error) {
		log(`❌ Failed to start dev server: ${error.message}`, 'red');
		return null;
	}
}

/**
 * 서버가 시작될 때까지 대기
 */
function waitForServer(url, maxAttempts = 30, delay = 1000) {
	return new Promise((resolve, reject) => {
		let attempts = 0;

		const checkServer = () => {
			attempts++;
			const req = http.get(url, (res) => {
				resolve(true);
			});

			req.on('error', () => {
				if (attempts >= maxAttempts) {
					reject(new Error(`Server did not start within ${maxAttempts * delay}ms`));
				} else {
					setTimeout(checkServer, delay);
				}
			});

			req.setTimeout(1000, () => {
				req.destroy();
				if (attempts >= maxAttempts) {
					reject(new Error(`Server did not start within ${maxAttempts * delay}ms`));
				} else {
					setTimeout(checkServer, delay);
				}
			});
		};

		checkServer();
	});
}

/**
 * Chrome DevTools MCP 검증 가이드 생성
 */
function generateMCPVerificationGuide(url, port) {
	const guide = {
		url: url,
		port: port,
		steps: [
			{
				step: 1,
				action: 'Navigate to URL',
				mcpTool: 'browser_navigate',
				description: `Navigate to ${url}`,
			},
			{
				step: 2,
				action: 'Take snapshot',
				mcpTool: 'browser_snapshot',
				description: 'Capture accessibility snapshot to check for rendering errors',
			},
			{
				step: 3,
				action: 'Check console messages',
				mcpTool: 'browser_console_messages',
				description: 'Check for JavaScript errors, React/Vue errors, or warnings',
			},
			{
				step: 4,
				action: 'Analyze network requests',
				mcpTool: 'browser_network_requests',
				description: 'Check for 4xx/5xx errors, slow requests (>500ms), or unnecessary API calls',
			},
		],
		checks: {
			consoleErrors: {
				description: 'No JavaScript errors should be present in console',
				severity: 'high',
			},
			networkErrors: {
				description: 'No 4xx/5xx HTTP errors should be present',
				severity: 'high',
			},
			slowRequests: {
				description: 'Requests should complete within 500ms',
				severity: 'medium',
			},
			renderingIssues: {
				description: 'No layout breaking or image load failures',
				severity: 'high',
			},
		},
	};

	return guide;
}

/**
 * 검증 리포트 생성
 *
 * @param {Object|null} guide - 검증 가이드 (null일 수 있음)
 * @param {Object} results - 검증 결과
 */
function generateReport(guide, results = {}) {
	const report = {
		timestamp: new Date().toISOString(),
		url: guide?.url || null,
		verificationSteps: guide?.steps || [],
		checks: guide?.checks || {},
		results: results,
		recommendations: [],
	};

	// 결과가 있는 경우 권장사항 생성
	if (results.consoleErrors && results.consoleErrors.length > 0) {
		report.recommendations.push({
			type: 'console_errors',
			message: `Found ${results.consoleErrors.length} console error(s). Review and fix JavaScript errors.`,
			severity: 'high',
		});
	}

	if (results.networkErrors && results.networkErrors.length > 0) {
		report.recommendations.push({
			type: 'network_errors',
			message: `Found ${results.networkErrors.length} network error(s). Check API endpoints and error handling.`,
			severity: 'high',
		});
	}

	if (results.slowRequests && results.slowRequests.length > 0) {
		report.recommendations.push({
			type: 'slow_requests',
			message: `Found ${results.slowRequests.length} slow request(s) (>500ms). Consider optimization.`,
			severity: 'medium',
		});
	}

	return report;
}

/**
 * 메인 실행 함수
 *
 * 사용법:
 *   node scripts/agents/visual_verifier.js [target_directory] [port]
 */
function main() {
	// 첫 번째 인자가 숫자면 포트, 아니면 대상 프로젝트 경로
	const firstArg = process.argv[2];
	const secondArg = process.argv[3];

	let targetDir = null;
	let port = 3000;

	if (firstArg && !isNaN(parseInt(firstArg))) {
		// 첫 번째 인자가 포트인 경우
		port = parseInt(firstArg);
	} else if (firstArg) {
		// 첫 번째 인자가 대상 프로젝트 경로인 경우
		targetDir = firstArg;
		if (secondArg && !isNaN(parseInt(secondArg))) {
			port = parseInt(secondArg);
		}
	}

	const projectRoot = targetDir ? path.resolve(targetDir) : process.cwd();
	const url = `http://localhost:${port}`;

	log('🔍 Visual Verifier Agent', 'cyan');
	log('========================\n', 'cyan');

	if (targetDir) {
		log(`📁 Target project: ${projectRoot}`, 'blue');
	}

	// 1. 스택 감지
	log('1. Detecting stack...', 'blue');
	const stackInfo = detectStack(targetDir);
	if (!stackInfo.stack) {
		log('⚠️  Could not detect project stack.', 'yellow');
		log('   Visual verification requires a web project (Node.js stack).', 'yellow');
		log('   Skipping visual verification.', 'yellow');

		const report = generateReport(null, {
			status: 'no_stack',
			message: 'No supported stack detected. Visual verification skipped.',
		});

		console.log('\n--- Visual Verification Report (JSON) ---');
		console.log(JSON.stringify(report, null, 2));
		log('\n⚠️  Visual verification skipped (no stack detected).', 'yellow');
		process.exit(0);
	}
	log(`   Detected stack: ${stackInfo.stack} (${stackInfo.packageManager})`, 'green');

	// 2. 웹 프로젝트 확인
	log('\n2. Checking if this is a web project...', 'blue');
	if (!isWebProject(stackInfo, projectRoot)) {
		log('⚠️  This does not appear to be a web project.', 'yellow');
		log('   Visual verification is only applicable to web projects.', 'yellow');
		log('   Skipping visual verification.', 'yellow');

		const report = generateReport(null, {
			status: 'not_web_project',
			message: 'Not a web project. Visual verification skipped.',
		});

		console.log('\n--- Visual Verification Report (JSON) ---');
		console.log(JSON.stringify(report, null, 2));
		log('\n⚠️  Visual verification skipped (not a web project).', 'yellow');
		process.exit(0);
	}
	log('   ✅ Web project detected', 'green');

	// 3. 개발 서버 확인 및 시작
	log('\n3. Checking dev server...', 'blue');
	let serverProcess = null;

	try {
		// 서버가 이미 실행 중인지 확인
		http.get(url, () => {
			log(`   ✅ Dev server is already running at ${url}`, 'green');
		}).on('error', () => {
			// 서버가 없으면 시작 시도
			log(`   ⚠️  Dev server not running. Attempting to start...`, 'yellow');
			serverProcess = startDevServer(stackInfo, projectRoot, port);
			if (serverProcess) {
				log(`   ⏳ Waiting for server to start...`, 'blue');
				waitForServer(url, 30, 1000)
					.then(() => {
						log(`   ✅ Server started successfully`, 'green');
					})
					.catch((error) => {
						log(`   ❌ Server failed to start: ${error.message}`, 'red');
						process.exit(1);
					});
			}
		});
	} catch (error) {
		log(`   ❌ Error checking server: ${error.message}`, 'red');
		process.exit(1);
	}

	// 4. Chrome DevTools MCP 검증 가이드 생성
	log('\n4. Generating Chrome DevTools MCP verification guide...', 'blue');
	const guide = generateMCPVerificationGuide(url, port);

	// 5. 검증 리포트 출력
	log('\n5. Verification Guide:', 'blue');
	log('\n--- Chrome DevTools MCP Verification Steps ---', 'cyan');
	for (const step of guide.steps) {
		log(`\nStep ${step.step}: ${step.action}`, 'yellow');
		log(`  MCP Tool: ${step.mcpTool}`, 'blue');
		log(`  Description: ${step.description}`, 'reset');
	}

	log('\n--- Verification Checks ---', 'cyan');
	for (const [checkName, check] of Object.entries(guide.checks)) {
		const severityColor = check.severity === 'high' ? 'red' : 'yellow';
		log(`\n${checkName}:`, severityColor);
		log(`  ${check.description}`, 'reset');
	}

	// JSON 리포트 출력
	const report = generateReport(guide);
	log('\n--- JSON Report ---', 'cyan');
	console.log(JSON.stringify(report, null, 2));

	log('\n💡 Note: This script prepares the verification environment.', 'yellow');
	log('   Actual Chrome DevTools MCP calls should be made by the AI agent (Cursor).', 'yellow');
	log('   Use the MCP tools listed above to perform the verification.', 'yellow');
}

// 스크립트 직접 실행 시
if (require.main === module) {
	main();
}

module.exports = {
	detectStack,
	isWebProject: (stackInfo) => isWebProject(stackInfo, process.cwd()),
	startDevServer: (stackInfo, port) => startDevServer(stackInfo, process.cwd(), port),
	generateMCPVerificationGuide,
	generateReport,
};

