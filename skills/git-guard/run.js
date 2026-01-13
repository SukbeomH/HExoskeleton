#!/usr/bin/env node
/**
 * git-guard.js - Git Guide 규칙 준수 검증 서브에이전트
 *
 * 목적: Git Guide 규칙을 준수하는지 검증하고, 브랜치 명명 규칙, 커밋 메시지 형식,
 * Issue 번호 포함 여부 등을 확인합니다.
 *
 * 사용법:
 *   node skills/git-guard/run.js [target_directory]
 *
 * 출력:
 *   JSON 형식으로 검증 결과를 반환합니다.
 *
 * 제약사항:
 *   - 모든 검증은 제안만 제공하며, 자동으로 수정하지 않습니다.
 *   - 사용자가 직접 수정해야 합니다.
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

// 프로젝트 루트 디렉토리 찾기
const TARGET_PATH = process.argv[2]
	? path.resolve(process.argv[2])
	: process.cwd();

// Git Guide 규칙
const BRANCH_PATTERNS = {
	bugfix: /^bugfix\/(\d+)-(.+)$/,
	feature: /^feature\/(\d+)-(.+)$/,
};

const COMMIT_MESSAGE_PATTERN = /^Resolved\s+#(\d+)\s+-\s+(.+)$/i;

/**
 * Git 저장소인지 확인
 */
function isGitRepository(dir) {
	try {
		const gitDir = path.join(dir, '.git');
		return fs.existsSync(gitDir) || fs.statSync(gitDir).isDirectory();
	} catch {
		return false;
	}
}

/**
 * 현재 브랜치명 가져오기
 */
function getCurrentBranch() {
	try {
		const branch = execSync('git rev-parse --abbrev-ref HEAD', {
			cwd: TARGET_PATH,
			encoding: 'utf-8',
		}).trim();
		return branch;
	} catch (error) {
		return null;
	}
}

/**
 * 최근 커밋 메시지 가져오기
 */
function getLatestCommitMessage() {
	try {
		const message = execSync('git log -1 --pretty=%B', {
			cwd: TARGET_PATH,
			encoding: 'utf-8',
		}).trim();
		return message;
	} catch (error) {
		return null;
	}
}

/**
 * 브랜치명 검증
 */
function validateBranchName(branchName) {
	if (!branchName) {
		return {
			valid: false,
			message: '브랜치를 찾을 수 없습니다',
			current: null,
			issue_number: null,
		};
	}

	// main, develop, master 브랜치는 검증 제외
	if (['main', 'develop', 'master'].includes(branchName)) {
		return {
			valid: true,
			message: '메인 브랜치는 검증 대상이 아닙니다',
			current: branchName,
			issue_number: null,
		};
	}

	// bugfix 또는 feature 패턴 확인
	for (const [type, pattern] of Object.entries(BRANCH_PATTERNS)) {
		const match = branchName.match(pattern);
		if (match) {
			const issueNumber = match[1];
			const description = match[2];
			return {
				valid: true,
				message: `브랜치명이 규칙을 준수합니다 (${type}/${issueNumber}-${description})`,
				current: branchName,
				issue_number: issueNumber,
			};
		}
	}

	return {
		valid: false,
		message: `브랜치명이 규칙을 준수하지 않습니다. 형식: bugfix/{issue_number}-{description} 또는 feature/{issue_number}-{description}`,
		current: branchName,
		issue_number: null,
	};
}

/**
 * 커밋 메시지 검증
 */
function validateCommitMessage(commitMessage) {
	if (!commitMessage) {
		return {
			valid: false,
			message: '커밋 메시지를 찾을 수 없습니다',
			latest: null,
			issue_number: null,
		};
	}

	const match = commitMessage.match(COMMIT_MESSAGE_PATTERN);
	if (match) {
		const issueNumber = match[1];
		const description = match[2];
		return {
			valid: true,
			message: `커밋 메시지가 규칙을 준수합니다 (Resolved #${issueNumber} - ${description})`,
			latest: commitMessage,
			issue_number: issueNumber,
		};
	}

	return {
		valid: false,
		message: '커밋 메시지가 규칙을 준수하지 않습니다. 형식: Resolved #{Issue No} - {Description}',
		latest: commitMessage,
		issue_number: null,
	};
}

/**
 * 위반 사항 수집
 */
function collectViolations(checks) {
	const violations = [];

	if (!checks.branch_name.valid && checks.branch_name.current) {
		violations.push({
			type: 'branch_name',
			severity: 'error',
			message: checks.branch_name.message,
			suggestion: `브랜치명을 다음 형식으로 변경하세요: feature/{issue_number}-{description} 또는 bugfix/{issue_number}-{description}`,
		});
	}

	if (!checks.commit_message.valid && checks.commit_message.latest) {
		violations.push({
			type: 'commit_message',
			severity: 'error',
			message: checks.commit_message.message,
			suggestion: `커밋 메시지를 다음 형식으로 변경하세요: Resolved #{Issue No} - {Description}`,
		});
	}

	return violations;
}

/**
 * 전체 상태 결정
 */
function determineStatus(checks, violations) {
	if (violations.some(v => v.severity === 'error')) {
		return 'failed';
	}
	if (violations.length > 0) {
		return 'warning';
	}
	return 'passed';
}

// 메인 실행
function main() {
	log('🔒 Git Guard Agent', 'cyan');
	log('========================', 'cyan');
	log('');

	// 1. Git 저장소 확인
	log('1. Checking Git repository...', 'blue');
	if (!isGitRepository(TARGET_PATH)) {
		log('   ❌ Git repository not found', 'red');
		process.exit(1);
	}
	log('   ✓ Git repository found', 'green');
	log('');

	// 2. 브랜치명 검증
	log('2. Validating branch name...', 'blue');
	const branchName = getCurrentBranch();
	const branchCheck = validateBranchName(branchName);

	if (branchCheck.valid) {
		log(`   ✓ Branch name: ${branchCheck.current}`, 'green');
		if (branchCheck.issue_number) {
			log(`   ✓ Issue number extracted: ${branchCheck.issue_number}`, 'green');
		}
	} else {
		log(`   ❌ ${branchCheck.message}`, 'red');
		log(`   Current: ${branchCheck.current}`, 'yellow');
	}
	log('');

	// 3. 커밋 메시지 검증
	log('3. Validating commit message...', 'blue');
	const commitMessage = getLatestCommitMessage();
	const commitCheck = validateCommitMessage(commitMessage);

	if (commitCheck.valid) {
		log(`   ✓ Latest commit: ${commitCheck.latest}`, 'green');
		if (commitCheck.issue_number) {
			log(`   ✓ Issue number extracted: ${commitCheck.issue_number}`, 'green');
		}
	} else {
		log(`   ❌ ${commitCheck.message}`, 'red');
		if (commitCheck.latest) {
			log(`   Current: ${commitCheck.latest}`, 'yellow');
		}
	}
	log('');

	// 4. 결과 수집
	const checks = {
		branch_name: branchCheck,
		commit_message: commitCheck,
	};

	const violations = collectViolations(checks);
	const status = determineStatus(checks, violations);

	const result = {
		timestamp: new Date().toISOString(),
		status,
		checks,
		violations,
	};

	// 5. JSON 출력
	log('--- JSON Output ---', 'cyan');
	console.log(JSON.stringify(result, null, 2));

	// 6. 종료 코드
	if (status === 'failed') {
		process.exit(1);
	} else if (status === 'warning') {
		process.exit(0);
	} else {
		process.exit(0);
	}
}

// 실행
try {
	main();
} catch (error) {
	log(`❌ Error: ${error.message}`, 'red');
	console.error(error);
	process.exit(1);
}

