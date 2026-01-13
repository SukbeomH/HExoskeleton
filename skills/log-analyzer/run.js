#!/usr/bin/env node
/**
 * log_analyzer.js - 로컬 로그 분석 서브에이전트
 *
 * 목적: logging.conf에 의해 생성되는 app.log를 분석하여 ERROR/CRITICAL 로그를 감지하고,
 * Codanna/Serena MCP를 통해 관련 소스 코드를 정밀 분석합니다.
 *
 * 사용법:
 *   node skills/log-analyzer/run.js [target_directory] [log_file_path]
 *
 * 출력:
 *   JSON 형식으로 로그 분석 결과를 반환합니다.
 *
 * 제약사항:
 *   - logging.conf 포맷을 정확히 파싱해야 함
 *   - 로그 내의 민감 정보는 마스킹 처리
 *   - ERROR/CRITICAL 로그 발생 시 Codanna/Serena MCP 호출
 */

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

// 프로젝트 루트 디렉토리 찾기 (skills/log-analyzer 기준)
const SCRIPT_DIR = __dirname;
const PROJECT_ROOT = process.argv[2] 
	? path.resolve(process.argv[2]) 
	: path.resolve(SCRIPT_DIR, '../..');
const LOG_FILE = process.argv[3] 
	? path.resolve(process.argv[3]) 
	: path.join(PROJECT_ROOT, 'app.log');

// 민감 정보 마스킹 패턴
const SENSITIVE_PATTERNS = [
	/\b(password|pwd|secret|token|api[_-]?key|auth[_-]?token|access[_-]?token)\s*[:=]\s*['"]?([^\s'"]+)['"]?/gi,
	/\b(email|phone|ssn|credit[_-]?card)\s*[:=]\s*['"]?([^\s'"]+)['"]?/gi,
	/\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/g, // Credit card numbers
];

/**
 * 민감 정보를 마스킹합니다.
 */
function maskSensitiveInfo(text) {
	let masked = text;
	SENSITIVE_PATTERNS.forEach(pattern => {
		masked = masked.replace(pattern, (match, key, value) => {
			if (value) {
				return `${key}=${'*'.repeat(Math.min(value.length, 8))}`;
			}
			return match;
		});
	});
	return masked;
}

/**
 * logging.conf 포맷에 맞춰 로그 라인을 파싱합니다.
 * 포맷: [%(asctime)s.%(msecs)d] [%(levelname)s] [%(name)s] [%(threadName)s:%(thread)d] [%(module)s:%(funcName)s:%(lineno)d] - %(message)s
 */
function parseLogLine(line) {
	// 로그 라인 패턴 매칭
	const logPattern = /^\[([^\]]+)\] \[([^\]]+)\] \[([^\]]+)\] \[([^\]]+)\] \[([^\]]+)\] - (.+)$/;
	const match = line.match(logPattern);
	
	if (!match) {
		return null;
	}
	
	const [, timestamp, levelname, name, threadInfo, location, message] = match;
	
	// location에서 module:funcName:lineno 추출
	const locationMatch = location.match(/^([^:]+):([^:]+):(\d+)$/);
	const module = locationMatch ? locationMatch[1] : null;
	const funcName = locationMatch ? locationMatch[2] : null;
	const lineno = locationMatch ? parseInt(locationMatch[3], 10) : null;
	
	return {
		timestamp,
		levelname: levelname.trim(),
		name: name.trim(),
		threadInfo: threadInfo.trim(),
		module,
		funcName,
		lineno,
		message: maskSensitiveInfo(message.trim()),
		raw: maskSensitiveInfo(line),
	};
}

/**
 * app.log 파일을 읽고 분석합니다.
 */
function analyzeLogFile(logFilePath) {
	const results = {
		total_lines: 0,
		errors: [],
		criticals: [],
		warnings: [],
		info: [],
		summary: {
			error_count: 0,
			critical_count: 0,
			warning_count: 0,
			has_severe_errors: false,
		},
	};
	
	if (!fs.existsSync(logFilePath)) {
		log(`⚠️  Log file not found: ${logFilePath}`, 'yellow');
		return results;
	}
	
	try {
		const logContent = fs.readFileSync(logFilePath, 'utf-8');
		const lines = logContent.split('\n').filter(line => line.trim());
		results.total_lines = lines.length;
		
		lines.forEach((line, index) => {
			const parsed = parseLogLine(line);
			if (!parsed) {
				return;
			}
			
			const level = parsed.levelname.toUpperCase();
			
			if (level === 'ERROR') {
				results.errors.push({
					...parsed,
					line_number: index + 1,
				});
				results.summary.error_count++;
			} else if (level === 'CRITICAL') {
				results.criticals.push({
					...parsed,
					line_number: index + 1,
				});
				results.summary.critical_count++;
			} else if (level === 'WARNING') {
				results.warnings.push({
					...parsed,
					line_number: index + 1,
				});
				results.summary.warning_count++;
			} else if (level === 'INFO') {
				results.info.push({
					...parsed,
					line_number: index + 1,
				});
			}
		});
		
		results.summary.has_severe_errors = 
			results.summary.error_count > 0 || results.summary.critical_count > 0;
		
	} catch (error) {
		log(`❌ Failed to read log file: ${error.message}`, 'red');
		results.error = error.message;
	}
	
	return results;
}

/**
 * Codanna/Serena MCP를 통해 관련 소스 코드를 분석합니다.
 * 실제 MCP 호출은 AI 에이전트가 수행해야 하므로, 여기서는 가이드만 제공합니다.
 */
function generateCodeAnalysisGuide(logEntry) {
	const guides = [];
	
	if (logEntry.module && logEntry.funcName && logEntry.lineno) {
		guides.push({
			tool: 'Codanna',
			action: 'semantic_search_with_context',
			query: `Error in ${logEntry.module}.${logEntry.funcName} at line ${logEntry.lineno}: ${logEntry.message}`,
			description: `Search for related code patterns and error handling in ${logEntry.module}`,
		});
		
		guides.push({
			tool: 'Serena',
			action: 'find_symbol',
			name_path: `${logEntry.module}/${logEntry.funcName}`,
			description: `Find the exact symbol definition for ${logEntry.funcName} in ${logEntry.module}`,
		});
		
		guides.push({
			tool: 'Serena',
			action: 'find_referencing_symbols',
			name_path: `${logEntry.module}/${logEntry.funcName}`,
			description: `Find all references to ${logEntry.funcName} to understand usage context`,
		});
	} else {
		guides.push({
			tool: 'Codanna',
			action: 'semantic_search_with_context',
			query: logEntry.message,
			description: `Search for code patterns related to error message: ${logEntry.message}`,
		});
	}
	
	return guides;
}

/**
 * 메인 분석 함수
 */
function main() {
	log('📋 Local Log Analyzer', 'cyan');
	log('=====================\n', 'cyan');
	
	log(`Analyzing log file: ${LOG_FILE}`, 'blue');
	
	const analysis = analyzeLogFile(LOG_FILE);
	
	// 결과 출력
	if (analysis.error) {
		log(`\n❌ Analysis failed: ${analysis.error}`, 'red');
		process.exit(1);
	}
	
	log(`\n📊 Analysis Summary:`, 'cyan');
	log(`   Total lines: ${analysis.total_lines}`, 'blue');
	log(`   Errors: ${analysis.summary.error_count}`, 
		analysis.summary.error_count > 0 ? 'red' : 'green');
	log(`   Criticals: ${analysis.summary.critical_count}`, 
		analysis.summary.critical_count > 0 ? 'red' : 'green');
	log(`   Warnings: ${analysis.summary.warning_count}`, 
		analysis.summary.warning_count > 0 ? 'yellow' : 'green');
	
	// ERROR/CRITICAL 로그에 대한 코드 분석 가이드 생성
	const codeAnalysisGuides = [];
	
	[...analysis.errors, ...analysis.criticals].forEach(logEntry => {
		const guides = generateCodeAnalysisGuide(logEntry);
		codeAnalysisGuides.push({
			log_entry: {
				timestamp: logEntry.timestamp,
				level: logEntry.levelname,
				module: logEntry.module,
				funcName: logEntry.funcName,
				lineno: logEntry.lineno,
				message: logEntry.message,
			},
			analysis_guides: guides,
		});
	});
	
	// JSON 출력
	const output = {
		status: analysis.summary.has_severe_errors ? 'failed' : 'passed',
		summary: analysis.summary,
		errors: analysis.errors.slice(0, 10), // 최근 10개만
		criticals: analysis.criticals.slice(0, 10),
		warnings: analysis.warnings.slice(0, 10),
		code_analysis_guides: codeAnalysisGuides,
		timestamp: new Date().toISOString(),
	};
	
	console.log('\n--- Log Analysis Results (JSON) ---');
	console.log(JSON.stringify(output, null, 2));
	
	// 심각한 에러가 있으면 종료 코드 1 반환
	if (analysis.summary.has_severe_errors) {
		log('\n❌ Severe errors found in logs. Approval blocked.', 'red');
		process.exit(1);
	} else {
		log('\n✅ No severe errors found in logs.', 'green');
		process.exit(0);
	}
}

// 스크립트 직접 실행 시
if (require.main === module) {
	main();
}

module.exports = { analyzeLogFile, parseLogLine, maskSensitiveInfo };

