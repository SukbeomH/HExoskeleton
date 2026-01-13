/**
 * LogMonitor 컴포넌트
 * 실시간 로컬 로그 모니터링 및 진단 결과 시각화
 * 타임라인 시각화 및 에러 클릭 시 코드 가이드 포함
 */

import { useState, useEffect } from "react";
import { analyzeLogs, readLogs, type LogAnalysisResult } from "@/lib/api";

interface LogMonitorProps {
	targetPath?: string;
	logFile?: string;
}

interface LogEntry {
	timestamp: string;
	level: string;
	message: string;
	module?: string;
	funcName?: string;
	lineno?: number;
}

export default function LogMonitor({ targetPath, logFile }: LogMonitorProps) {
	const [logs, setLogs] = useState<string[]>([]);
	const [analysis, setAnalysis] = useState<LogAnalysisResult | null>(null);
	const [loading, setLoading] = useState(false);
	const [autoRefresh, setAutoRefresh] = useState(false);
	const [selectedError, setSelectedError] = useState<LogEntry | null>(null);
	const [filterLevel, setFilterLevel] = useState<string>("all");
	const [searchQuery, setSearchQuery] = useState("");

	useEffect(() => {
		const fetchLogs = async () => {
			try {
				const result = await readLogs(targetPath, logFile, 100);
				if (result.status === "success") {
					setLogs(result.lines);
				}
			} catch (error) {
				console.error("Failed to fetch logs:", error);
			}
		};

		fetchLogs();

		if (autoRefresh) {
			const interval = setInterval(fetchLogs, 5000); // 5초마다 갱신
			return () => clearInterval(interval);
		}
	}, [targetPath, logFile, autoRefresh]);

	const handleAnalyze = async () => {
		// 로그가 없으면 분석하지 않음
		if (logs.length === 0) {
			alert("분석할 로그가 없습니다. 먼저 로그 파일을 확인하세요.");
			return;
		}

		setLoading(true);
		try {
			const result = await analyzeLogs(targetPath, logFile);
			setAnalysis(result);
		} catch (error: any) {
			console.error("Failed to analyze logs:", error);
			const errorMessage = error.response?.data?.detail || error.message || "로그 분석에 실패했습니다.";
			alert(`로그 분석 실패: ${errorMessage}`);
		} finally {
			setLoading(false);
		}
	};

	// 로그 파싱 (간단한 파싱)
	const parseLogLine = (line: string): LogEntry | null => {
		// 타임스탬프 추출 시도
		const timestampMatch = line.match(/(\d{4}-\d{2}-\d{2}[\sT]\d{2}:\d{2}:\d{2})/);
		const levelMatch = line.match(/\[(ERROR|CRITICAL|WARNING|INFO|DEBUG)\]/);
		const moduleMatch = line.match(/(\w+\.py|\w+\.js):(\d+)/);
		const funcMatch = line.match(/in\s+(\w+)/);

		return {
			timestamp: timestampMatch ? timestampMatch[1] : new Date().toISOString(),
			level: levelMatch ? levelMatch[1] : "INFO",
			message: line,
			module: moduleMatch ? moduleMatch[1] : undefined,
			lineno: moduleMatch ? parseInt(moduleMatch[2]) : undefined,
			funcName: funcMatch ? funcMatch[1] : undefined,
		};
	};

	// 필터링된 로그
	const filteredLogs = logs.filter((line) => {
		if (filterLevel !== "all") {
			if (!line.includes(`[${filterLevel}]`)) return false;
		}
		if (searchQuery) {
			if (!line.toLowerCase().includes(searchQuery.toLowerCase())) return false;
		}
		return true;
	});

	// 타임라인 데이터 생성
	const timelineData = filteredLogs
		.map((line, index) => {
			const parsed = parseLogLine(line);
			if (!parsed) return null;
			return {
				index,
				...parsed,
				line,
			};
		})
		.filter((entry): entry is LogEntry & { index: number; line: string } => entry !== null);

	return (
		<div className="space-y-6 dark:text-gray-100">
			<div className="flex items-center justify-between">
				<h2 className="text-2xl font-bold text-gray-800 dark:text-gray-100">
					로컬 로그 모니터
				</h2>
				<div className="flex gap-4">
					<input
						type="text"
						placeholder="검색..."
						value={searchQuery}
						onChange={(e) => setSearchQuery(e.target.value)}
						className="px-4 py-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600 dark:text-gray-100"
					/>
					<select
						value={filterLevel}
						onChange={(e) => setFilterLevel(e.target.value)}
						className="px-4 py-2 border rounded-lg dark:bg-gray-700 dark:border-gray-600 dark:text-gray-100"
					>
						<option value="all">모든 레벨</option>
						<option value="ERROR">ERROR</option>
						<option value="CRITICAL">CRITICAL</option>
						<option value="WARNING">WARNING</option>
						<option value="INFO">INFO</option>
					</select>
					<label className="flex items-center gap-2">
						<input
							type="checkbox"
							checked={autoRefresh}
							onChange={(e) => setAutoRefresh(e.target.checked)}
							className="rounded"
						/>
						<span className="text-sm text-gray-600 dark:text-gray-400">자동 갱신</span>
					</label>
					<button
						type="button"
						onClick={handleAnalyze}
						disabled={loading || logs.length === 0}
						className={`px-6 py-2 rounded-lg font-semibold ${
							loading || logs.length === 0
								? "bg-gray-400 dark:bg-gray-600 text-gray-600 dark:text-gray-400 cursor-not-allowed"
								: "bg-blue-600 dark:bg-blue-500 text-white hover:bg-blue-700 dark:hover:bg-blue-600"
						}`}
					>
						{loading ? "분석 중..." : "로그 분석"}
					</button>
				</div>
			</div>

			{/* 타임라인 뷰 */}
			<div className="bg-white dark:bg-gray-800 border-2 dark:border-gray-700 rounded-lg p-6">
				<h3 className="text-lg font-semibold text-gray-800 dark:text-gray-100 mb-4">
					로그 타임라인
				</h3>
				<div className="space-y-2 max-h-96 overflow-auto">
					{timelineData.map((entry, index) => {
						const isError = entry.level === "ERROR" || entry.level === "CRITICAL";
						return (
							<div
								key={index}
								onClick={() => isError && setSelectedError(entry)}
								className={`p-3 rounded-lg border-l-4 cursor-pointer transition-colors ${
									isError
										? "border-red-500 dark:border-red-400 bg-red-50 dark:bg-red-900/20 hover:bg-red-100 dark:hover:bg-red-900/30"
										: entry.level === "WARNING"
										? "border-yellow-500 dark:border-yellow-400 bg-yellow-50 dark:bg-yellow-900/20"
										: "border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700"
								}`}
							>
								<div className="flex items-start justify-between">
									<div className="flex-1">
										<div className="flex items-center gap-2 mb-1">
											<span className="text-xs font-semibold text-gray-600 dark:text-gray-400">
												{entry.timestamp}
											</span>
											<span
												className={`text-xs font-semibold px-2 py-1 rounded ${
													entry.level === "ERROR" || entry.level === "CRITICAL"
														? "bg-red-200 dark:bg-red-800 text-red-800 dark:text-red-200"
														: entry.level === "WARNING"
														? "bg-yellow-200 dark:bg-yellow-800 text-yellow-800 dark:text-yellow-200"
														: "bg-blue-200 dark:bg-blue-800 text-blue-800 dark:text-blue-200"
												}`}
											>
												{entry.level}
											</span>
										</div>
										<div className="text-sm text-gray-800 dark:text-gray-200 font-mono">
											{entry.message}
										</div>
										{entry.module && entry.lineno && (
											<div className="text-xs text-gray-600 dark:text-gray-400 mt-1">
												{entry.module}:{entry.lineno}
												{entry.funcName && ` in ${entry.funcName}()`}
											</div>
										)}
									</div>
								</div>
							</div>
						);
					})}
				</div>
			</div>

			{/* 터미널 스타일 로그 뷰어 */}
			<div className="bg-black border border-zinc-800 rounded-lg font-mono text-sm overflow-hidden">
				{/* 터미널 헤더 */}
				<div className="bg-zinc-900 border-b border-zinc-800 px-4 py-2 flex items-center gap-2">
					<div className="flex gap-1.5">
						<div className="w-3 h-3 rounded-full bg-red-500" />
						<div className="w-3 h-3 rounded-full bg-yellow-500" />
						<div className="w-3 h-3 rounded-full bg-green-500" />
					</div>
					<span className="text-xs text-zinc-400 ml-2">Terminal</span>
				</div>

				{/* 로그 컨텐츠 */}
				<div className="p-4 overflow-auto max-h-[600px]">
					{filteredLogs.length === 0 ? (
						<div className="text-zinc-500">로그 파일이 없거나 비어있습니다.</div>
					) : (
						filteredLogs.map((line, index) => {
							const isError = line.includes("[ERROR]") || line.includes("[CRITICAL]");
							const isWarning = line.includes("[WARNING]");
							const isInfo = line.includes("[INFO]");

							// 로그 레벨에 따른 색상
							let colorClass = "text-green-400";
							if (isError) {
								colorClass = "text-red-400";
							} else if (isWarning) {
								colorClass = "text-yellow-400";
							} else if (isInfo) {
								colorClass = "text-blue-400";
							}

							return (
								<div key={index} className="flex items-start gap-2 group hover:bg-zinc-900/50 px-2 py-1 rounded">
									<div className={`flex-1 ${colorClass} whitespace-pre-wrap`}>
										{line}
									</div>
									{isError && logs.length > 0 && (
										<button
											type="button"
											onClick={() => {
												// log_analyzer 스킬 호출
												const parsed = parseLogLine(line);
												if (parsed) {
													handleAnalyze();
												}
											}}
											disabled={loading}
											className="opacity-0 group-hover:opacity-100 px-2 py-1 text-xs font-medium bg-indigo-500 text-white rounded hover:bg-indigo-600 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
										>
											Analyze with AI
										</button>
									)}
								</div>
							);
						})
					)}
				</div>
			</div>

			{/* 분석 결과 */}
			{analysis && (
				<div className="bg-white dark:bg-gray-800 border-2 dark:border-gray-700 rounded-lg p-6">
					<h3 className="text-xl font-semibold text-gray-800 dark:text-gray-100 mb-4">
						로그 분석 결과
					</h3>

					<div className="grid grid-cols-3 gap-4 mb-6">
						<div
							className={`p-4 rounded-lg ${
								analysis.summary.error_count > 0
									? "bg-red-50 dark:bg-red-900/20 border-2 border-red-500 dark:border-red-400"
									: "bg-green-50 dark:bg-green-900/20 border-2 border-green-500 dark:border-green-400"
							}`}
						>
							<div className="text-2xl font-bold text-gray-800 dark:text-gray-100">
								{analysis.summary.error_count}
							</div>
							<div className="text-sm text-gray-600 dark:text-gray-400">Errors</div>
						</div>

						<div
							className={`p-4 rounded-lg ${
								analysis.summary.critical_count > 0
									? "bg-red-50 dark:bg-red-900/20 border-2 border-red-500 dark:border-red-400"
									: "bg-green-50 dark:bg-green-900/20 border-2 border-green-500 dark:border-green-400"
							}`}
						>
							<div className="text-2xl font-bold text-gray-800 dark:text-gray-100">
								{analysis.summary.critical_count}
							</div>
							<div className="text-sm text-gray-600 dark:text-gray-400">Criticals</div>
						</div>

						<div
							className={`p-4 rounded-lg ${
								analysis.summary.warning_count > 0
									? "bg-yellow-50 dark:bg-yellow-900/20 border-2 border-yellow-500 dark:border-yellow-400"
									: "bg-green-50 dark:bg-green-900/20 border-2 border-green-500 dark:border-green-400"
							}`}
						>
							<div className="text-2xl font-bold text-gray-800 dark:text-gray-100">
								{analysis.summary.warning_count}
							</div>
							<div className="text-sm text-gray-600 dark:text-gray-400">Warnings</div>
						</div>
					</div>

					{analysis.summary.has_severe_errors && (
						<div className="bg-red-50 dark:bg-red-900/20 border-l-4 border-red-500 dark:border-red-400 p-4 mb-4">
							<p className="text-red-800 dark:text-red-200 font-semibold">
								⚠️ 심각한 에러가 발견되었습니다. 승인이 차단됩니다.
							</p>
						</div>
					)}

					{/* 에러 목록 */}
					{(analysis.errors.length > 0 || analysis.criticals.length > 0) && (
						<div className="space-y-4">
							<h4 className="font-semibold text-gray-800 dark:text-gray-100">에러 상세</h4>

							{analysis.criticals.map((critical, index) => (
								<div
									key={`critical-${index}`}
									className="bg-red-50 dark:bg-red-900/20 border-l-4 border-red-500 dark:border-red-400 p-3 cursor-pointer hover:bg-red-100 dark:hover:bg-red-900/30"
									onClick={() => setSelectedError({
										timestamp: critical.timestamp,
										level: critical.level,
										message: critical.message,
										module: critical.module ?? undefined,
										funcName: critical.funcName ?? undefined,
										lineno: critical.lineno ?? undefined,
									})}
								>
									<div className="font-semibold text-red-800 dark:text-red-200">
										[CRITICAL]
									</div>
									<div className="text-sm text-gray-700 dark:text-gray-300">
										{critical.module && critical.funcName && critical.lineno && (
											<span className="font-mono">
												{critical.module}:{critical.funcName}:{critical.lineno}
											</span>
										)}
									</div>
									<div className="text-sm text-gray-600 dark:text-gray-400 mt-1">
										{critical.message}
									</div>
									<div className="text-xs text-gray-500 dark:text-gray-500 mt-1">
										{critical.timestamp}
									</div>
								</div>
							))}

							{analysis.errors.map((error, index) => (
								<div
									key={`error-${index}`}
									className="bg-orange-50 dark:bg-orange-900/20 border-l-4 border-orange-500 dark:border-orange-400 p-3 cursor-pointer hover:bg-orange-100 dark:hover:bg-orange-900/30"
									onClick={() => setSelectedError({
										timestamp: error.timestamp,
										level: error.level,
										message: error.message,
										module: error.module ?? undefined,
										funcName: error.funcName ?? undefined,
										lineno: error.lineno ?? undefined,
									})}
								>
									<div className="font-semibold text-orange-800 dark:text-orange-200">
										[ERROR]
									</div>
									<div className="text-sm text-gray-700 dark:text-gray-300">
										{error.module && error.funcName && error.lineno && (
											<span className="font-mono">
												{error.module}:{error.funcName}:{error.lineno}
											</span>
										)}
									</div>
									<div className="text-sm text-gray-600 dark:text-gray-400 mt-1">
										{error.message}
									</div>
									<div className="text-xs text-gray-500 dark:text-gray-500 mt-1">
										{error.timestamp}
									</div>
								</div>
							))}
						</div>
					)}

					{/* 코드 분석 가이드 */}
					{analysis.code_analysis_guides && analysis.code_analysis_guides.length > 0 && (
						<div className="mt-6">
							<h4 className="font-semibold text-gray-800 dark:text-gray-100 mb-3">
								코드 분석 가이드
							</h4>
							<div className="space-y-3">
								{analysis.code_analysis_guides.map((guide, index) => (
									<div
										key={index}
										className="bg-blue-50 dark:bg-blue-900/20 border-l-4 border-blue-500 dark:border-blue-400 p-3"
									>
										<div className="text-sm font-semibold text-blue-800 dark:text-blue-200 mb-2">
											{guide.log_entry.module}:{guide.log_entry.funcName}:
											{guide.log_entry.lineno}
										</div>
										<div className="space-y-1">
											{guide.analysis_guides.map((g, gIndex) => (
												<div
													key={gIndex}
													className="text-xs text-gray-700 dark:text-gray-300"
												>
													<strong>{g.tool}</strong>: {g.description}
													{g.query && (
														<div className="ml-4 mt-1 font-mono text-xs text-gray-600 dark:text-gray-400">
															Query: {g.query}
														</div>
													)}
												</div>
											))}
										</div>
									</div>
								))}
							</div>
						</div>
					)}
				</div>
			)}

			{/* 에러 상세 모달 */}
			{selectedError && (
				<div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
					<div className="bg-white dark:bg-gray-800 rounded-lg p-6 max-w-2xl w-full mx-4">
						<div className="flex items-center justify-between mb-4">
							<h3 className="text-xl font-semibold text-gray-800 dark:text-gray-100">
								에러 상세 정보
							</h3>
							<button
								type="button"
								onClick={() => setSelectedError(null)}
								className="text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200"
							>
								✕
							</button>
						</div>
						<div className="space-y-4">
							<div>
								<div className="text-sm font-semibold text-gray-600 dark:text-gray-400">
									타임스탬프
								</div>
								<div className="text-gray-800 dark:text-gray-100">{selectedError.timestamp}</div>
							</div>
							<div>
								<div className="text-sm font-semibold text-gray-600 dark:text-gray-400">
									레벨
								</div>
								<div className="text-gray-800 dark:text-gray-100">{selectedError.level}</div>
							</div>
							{selectedError.module && (
								<div>
									<div className="text-sm font-semibold text-gray-600 dark:text-gray-400">
										위치
									</div>
									<div className="font-mono text-gray-800 dark:text-gray-100">
										{selectedError.module}
										{selectedError.lineno && `:${selectedError.lineno}`}
										{selectedError.funcName && ` in ${selectedError.funcName}()`}
									</div>
								</div>
							)}
							<div>
								<div className="text-sm font-semibold text-gray-600 dark:text-gray-400">
									메시지
								</div>
								<div className="text-gray-800 dark:text-gray-100">{selectedError.message}</div>
							</div>
							{analysis?.code_analysis_guides && (
								<div>
									<div className="text-sm font-semibold text-gray-600 dark:text-gray-400 mb-2">
										코드 분석 가이드
									</div>
									<div className="bg-blue-50 dark:bg-blue-900/20 p-4 rounded-lg space-y-2">
										{analysis.code_analysis_guides
											.filter(
												(g) =>
													g.log_entry.module === selectedError.module &&
													g.log_entry.lineno === selectedError.lineno
											)
											.map((guide, index) => (
												<div key={index} className="text-sm">
													{guide.analysis_guides.map((g, gIndex) => (
														<div
															key={gIndex}
															className="text-gray-700 dark:text-gray-300 mb-1"
														>
															<strong>{g.tool}</strong>: {g.description}
															{g.query && (
																<div className="ml-4 mt-1 font-mono text-xs text-gray-600 dark:text-gray-400">
																	{g.query}
																</div>
															)}
														</div>
													))}
												</div>
											))}
									</div>
								</div>
							)}
						</div>
					</div>
				</div>
			)}
		</div>
	);
}
