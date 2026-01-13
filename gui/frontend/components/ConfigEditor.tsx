/**
 * ConfigEditor 컴포넌트
 * CLAUDE.md 편집, 환경 변수 관리, uv 마이그레이션 UI
 */

import { useState, useEffect } from "react";
import {
	getClaudeSections,
	updateClaudeSection,
	checkEnv,
	updateEnv,
	checkTools,
	type ClaudeSections,
	type ToolStatus,
} from "@/lib/api";

export default function ConfigEditor() {
	const [activeTab, setActiveTab] = useState<"claude" | "env" | "migration">("claude");
	const [claudeSections, setClaudeSections] = useState<ClaudeSections | null>(null);
	const [editingSection, setEditingSection] = useState<"lessons_learned" | "team_standards" | null>(null);
	const [editContent, setEditContent] = useState("");
	const [saving, setSaving] = useState(false);
	const [targetPath, setTargetPath] = useState("");
	const [envVars, setEnvVars] = useState<Record<string, string>>({});
	const [envCheckResult, setEnvCheckResult] = useState<string>("");
	const [toolStatus, setToolStatus] = useState<ToolStatus | null>(null);
	const [migrationLogs, setMigrationLogs] = useState<string[]>([]);
	const [migrating, setMigrating] = useState(false);

	useEffect(() => {
		loadClaudeSections();
		loadToolStatus();
	}, []);

	const loadClaudeSections = async () => {
		try {
			const sections = await getClaudeSections();
			setClaudeSections(sections);
		} catch (error) {
			console.error("Failed to load CLAUDE sections:", error);
		}
	};

	const loadToolStatus = async () => {
		try {
			const status = await checkTools();
			setToolStatus(status);
		} catch (error) {
			console.error("Failed to check tools:", error);
		}
	};

	const handleEditSection = (section: "lessons_learned" | "team_standards") => {
		setEditingSection(section);
		setEditContent(claudeSections?.[section] || "");
	};

	const handleSaveSection = async () => {
		if (!editingSection) return;

		setSaving(true);
		try {
			await updateClaudeSection(editingSection, editContent, "replace");
			await loadClaudeSections();
			setEditingSection(null);
			setEditContent("");
		} catch (error) {
			console.error("Failed to save section:", error);
			alert("저장 실패: " + (error as Error).message);
		} finally {
			setSaving(false);
		}
	};

	const handleCheckEnv = async () => {
		if (!targetPath) {
			alert("대상 프로젝트 경로를 입력하세요.");
			return;
		}

		try {
			const result = await checkEnv(targetPath);
			setEnvCheckResult(result.output || result.error || "환경 변수 확인 완료");
		} catch (error) {
			console.error("Failed to check env:", error);
			setEnvCheckResult("환경 변수 확인 실패: " + (error as Error).message);
		}
	};

	const handleUpdateEnv = async () => {
		if (!targetPath) {
			alert("대상 프로젝트 경로를 입력하세요.");
			return;
		}

		try {
			await updateEnv(targetPath, envVars);
			alert("환경 변수가 업데이트되었습니다.");
			setEnvVars({});
		} catch (error) {
			console.error("Failed to update env:", error);
			alert("업데이트 실패: " + (error as Error).message);
		}
	};

	const handleMigrateToUv = async () => {
		if (!targetPath) {
			alert("대상 프로젝트 경로를 입력하세요.");
			return;
		}

		setMigrating(true);
		setMigrationLogs([]);

		try {
			const response = await fetch(
				`${process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000"}/api/v1/config/migrate/uv`,
				{
					method: "POST",
					headers: { "Content-Type": "application/json" },
					body: JSON.stringify({ target_path: targetPath }),
				}
			);

			if (!response.body) {
				throw new Error("No response body");
			}

			const reader = response.body.getReader();
			const decoder = new TextDecoder();

			while (true) {
				const { done, value } = await reader.read();
				if (done) break;

				const chunk = decoder.decode(value);
				const lines = chunk.split("\n");

				for (const line of lines) {
					if (line.startsWith("data: ")) {
						try {
							const data = JSON.parse(line.slice(6));
							if (data.type === "log") {
								setMigrationLogs((prev) => [...prev, data.message]);
							} else if (data.type === "success") {
								setMigrationLogs((prev) => [...prev, "✅ 마이그레이션 완료"]);
								setMigrating(false);
							} else if (data.type === "error") {
								setMigrationLogs((prev) => [...prev, `❌ 에러: ${data.message}`]);
								setMigrating(false);
							}
						} catch (e) {
							// JSON 파싱 실패 무시
						}
					}
				}
			}
		} catch (error) {
			console.error("Migration failed:", error);
			setMigrationLogs((prev) => [...prev, `❌ 마이그레이션 실패: ${error}`]);
			setMigrating(false);
		}
	};

	return (
		<div className="space-y-6">
			<div className="flex items-center justify-between">
				<h2 className="text-2xl font-bold text-zinc-100">
					설정 및 지식 편집기
				</h2>
			</div>

			{/* 탭 네비게이션 */}
			<div className="flex border-b border-zinc-800">
				<button
					type="button"
					onClick={() => setActiveTab("claude")}
					className={`px-6 py-3 font-semibold transition-colors ${
						activeTab === "claude"
							? "border-b-2 border-indigo-500 text-indigo-400"
							: "text-zinc-400 hover:text-zinc-200"
					}`}
				>
					CLAUDE.md 편집
				</button>
				<button
					type="button"
					onClick={() => setActiveTab("env")}
					className={`px-6 py-3 font-semibold transition-colors ${
						activeTab === "env"
							? "border-b-2 border-indigo-500 text-indigo-400"
							: "text-zinc-400 hover:text-zinc-200"
					}`}
				>
					환경 변수
				</button>
				<button
					type="button"
					onClick={() => setActiveTab("migration")}
					className={`px-6 py-3 font-semibold transition-colors ${
						activeTab === "migration"
							? "border-b-2 border-indigo-500 text-indigo-400"
							: "text-zinc-400 hover:text-zinc-200"
					}`}
				>
					uv 마이그레이션
				</button>
			</div>

			{/* CLAUDE.md 편집 탭 */}
			{activeTab === "claude" && (
				<div className="space-y-4">
					{/* 기능 설명 */}
					<div className="bg-zinc-900/50 border border-zinc-800 rounded-lg p-6">
						<h3 className="text-xl font-bold text-zinc-100 mb-4">📚 CLAUDE.md 지식 관리 시스템</h3>

						<div className="space-y-4 text-zinc-300">
							<div>
								<h4 className="text-lg font-semibold text-zinc-100 mb-2">CLAUDE.md란?</h4>
								<p className="text-sm leading-relaxed">
									<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">CLAUDE.md</code>는
									AI 에이전트의 행동 지침서이자 팀의 지식이 복리로 쌓이는 공간입니다.
									단순한 문서가 아닌, AI가 시간이 지날수록 더 똑똑해지는 <strong className="text-zinc-100">'뇌'</strong> 역할을 합니다.
								</p>
							</div>

							<div>
								<h4 className="text-lg font-semibold text-zinc-100 mb-2">핵심 개념: 지식의 복리화 (Compounding Knowledge)</h4>
								<p className="text-sm leading-relaxed mb-2">
									팀의 실전 경험이 축적되어 AI가 같은 실수를 반복하지 않도록 합니다:
								</p>
								<ul className="list-disc list-inside space-y-1 text-sm">
									<li>
										<strong className="text-zinc-100">Anti-patterns</strong>: AI가 잘못된 행동을 할 때마다 기록하여 다음에 방지
									</li>
									<li>
										<strong className="text-zinc-100">Lessons Learned</strong>: 작업 중 발견한 교훈과 개선 사항을 축적
									</li>
									<li>
										<strong className="text-zinc-100">Team Standards</strong>: 팀의 코딩 컨벤션, 아키텍처 원칙, 워크플로우 표준
									</li>
								</ul>
							</div>

							<div className="bg-indigo-500/10 border-l-4 border-indigo-500/50 p-4 rounded">
								<h4 className="text-sm font-semibold text-indigo-400 mb-2">💡 업데이트 시점</h4>
								<ul className="list-disc list-inside space-y-1 text-sm text-zinc-300">
									<li>AI가 특정 실수를 반복할 때</li>
									<li>새로운 팀 컨벤션이 결정되었을 때</li>
									<li>PR 리뷰 중 <code className="bg-zinc-800 px-1 rounded text-indigo-400">@.claude</code> 태그로 자동 반영</li>
									<li>검증 과정에서 발견한 개선 사항</li>
								</ul>
							</div>

							<div className="bg-yellow-500/10 border-l-4 border-yellow-500/50 p-4 rounded">
								<h4 className="text-sm font-semibold text-yellow-400 mb-2">⚠️ 주의사항</h4>
								<p className="text-sm text-zinc-300">
									CLAUDE.md를 한 번에 너무 크게 수정하지 마세요. AI가 컨텍스트 과부하를 느낄 수 있습니다.
									작은 단위로 점진적으로 업데이트하는 것이 효과적입니다.
								</p>
							</div>
						</div>
					</div>

					<div className="bg-zinc-900/50 border border-zinc-800 rounded-lg p-6">
						<h3 className="text-lg font-semibold text-zinc-100 mb-4">
							Lessons Learned
						</h3>
						<div className="mb-4 text-sm text-zinc-400">
							작업 중 발견한 교훈, 개선 사항, 실전 경험을 기록합니다. AI가 같은 실수를 반복하지 않도록 도와줍니다.
						</div>
						{editingSection === "lessons_learned" ? (
							<div className="space-y-4">
								<textarea
									value={editContent}
									onChange={(e) => setEditContent(e.target.value)}
									className="w-full h-64 p-4 border border-zinc-800 rounded-lg font-mono text-sm bg-zinc-950 text-zinc-100 placeholder:text-zinc-500 focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/20"
									placeholder="Lessons Learned 내용을 입력하세요..."
								/>
								<div className="flex gap-4">
									<button
										type="button"
										onClick={handleSaveSection}
										disabled={saving}
										className="px-6 py-2 bg-indigo-500 text-white rounded-lg hover:bg-indigo-600 active:scale-95 transition-all font-medium disabled:opacity-50 disabled:cursor-not-allowed"
									>
										{saving ? "저장 중..." : "저장"}
									</button>
									<button
										type="button"
										onClick={() => {
											setEditingSection(null);
											setEditContent("");
										}}
										className="px-6 py-2 bg-zinc-700 text-zinc-200 rounded-lg hover:bg-zinc-600 active:scale-95 transition-all font-medium"
									>
										취소
									</button>
								</div>
							</div>
						) : (
							<div>
								<pre className="bg-zinc-950 border border-zinc-800 p-4 rounded-lg text-sm text-zinc-200 font-mono whitespace-pre-wrap overflow-auto max-h-64">
									{claudeSections?.lessons_learned || "내용 없음"}
								</pre>
								<button
									type="button"
									onClick={() => handleEditSection("lessons_learned")}
									className="mt-4 px-6 py-2 bg-indigo-500 text-white rounded-lg hover:bg-indigo-600 active:scale-95 transition-all font-medium"
								>
									편집
								</button>
							</div>
						)}
					</div>

					<div className="bg-zinc-900/50 border border-zinc-800 rounded-lg p-6">
						<h3 className="text-lg font-semibold text-zinc-100 mb-4">
							Team Standards
						</h3>
						<div className="mb-4 text-sm text-zinc-400">
							팀의 코딩 컨벤션, 아키텍처 원칙, 워크플로우 표준을 정의합니다. AI가 팀의 스타일을 일관되게 따르도록 합니다.
						</div>
						{editingSection === "team_standards" ? (
							<div className="space-y-4">
								<textarea
									value={editContent}
									onChange={(e) => setEditContent(e.target.value)}
									className="w-full h-64 p-4 border border-zinc-800 rounded-lg font-mono text-sm bg-zinc-950 text-zinc-100 placeholder:text-zinc-500 focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/20"
									placeholder="Team Standards 내용을 입력하세요..."
								/>
								<div className="flex gap-4">
									<button
										type="button"
										onClick={handleSaveSection}
										disabled={saving}
										className="px-6 py-2 bg-indigo-500 text-white rounded-lg hover:bg-indigo-600 active:scale-95 transition-all font-medium disabled:opacity-50 disabled:cursor-not-allowed"
									>
										{saving ? "저장 중..." : "저장"}
									</button>
									<button
										type="button"
										onClick={() => {
											setEditingSection(null);
											setEditContent("");
										}}
										className="px-6 py-2 bg-zinc-700 text-zinc-200 rounded-lg hover:bg-zinc-600 active:scale-95 transition-all font-medium"
									>
										취소
									</button>
								</div>
							</div>
						) : (
							<div>
								<pre className="bg-zinc-950 border border-zinc-800 p-4 rounded-lg text-sm text-zinc-200 font-mono whitespace-pre-wrap overflow-auto max-h-64">
									{claudeSections?.team_standards || "내용 없음"}
								</pre>
								<button
									type="button"
									onClick={() => handleEditSection("team_standards")}
									className="mt-4 px-6 py-2 bg-indigo-500 text-white rounded-lg hover:bg-indigo-600 active:scale-95 transition-all font-medium"
								>
									편집
								</button>
							</div>
						)}
					</div>
				</div>
			)}

			{/* 환경 변수 탭 */}
			{activeTab === "env" && (
				<div className="space-y-4">
					{/* 기능 설명 */}
					<div className="bg-zinc-900/50 border border-zinc-800 rounded-lg p-6">
						<h3 className="text-xl font-bold text-zinc-100 mb-4">🔍 환경 변수 자가 진단 기능</h3>

						<div className="space-y-4 text-zinc-300">
							<div>
								<h4 className="text-lg font-semibold text-zinc-100 mb-2">기능 개요</h4>
								<p className="text-sm leading-relaxed">
									이 기능은 프로젝트의 <code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">.env_sample</code> 파일과
									<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">.env</code> 파일을 비교하여
									누락된 환경 변수를 감지합니다.
								</p>
							</div>

							<div className="bg-yellow-500/10 border-l-4 border-yellow-500/50 p-4 rounded">
								<h4 className="text-sm font-semibold text-yellow-400 mb-2">⚠️ 자동 체크 비활성화</h4>
								<p className="text-sm text-zinc-300">
									보일러플레이트 주입 시 환경 변수 자동 체크는 <strong>비활성화</strong>되어 있습니다.
									주입될 프로젝트마다 필요한 환경 변수가 다르기 때문입니다.
									필요한 경우 아래의 <strong>"환경 변수 확인"</strong> 버튼을 통해 수동으로 확인할 수 있습니다.
								</p>
							</div>

							<div>
								<h4 className="text-lg font-semibold text-zinc-100 mb-2">동작 방식</h4>
								<ol className="list-decimal list-inside space-y-2 text-sm">
									<li>
										<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">.env_sample</code> 파일에서
										필요한 환경 변수 KEY 목록을 추출합니다.
									</li>
									<li>
										<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">.env</code> 파일에서
										현재 설정된 환경 변수 KEY 목록을 추출합니다.
									</li>
									<li>
										두 목록을 비교하여 <code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">.env_sample</code>에 있지만
										<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">.env</code>에 없는 KEY를 찾아 보고합니다.
									</li>
									<li>
										누락된 환경 변수가 발견되면, Codanna/Serena MCP를 사용하여 소스 코드 내 해당 환경 변수 사용처를
										정밀 분석할 수 있도록 제안합니다.
									</li>
								</ol>
							</div>

							<div>
								<h4 className="text-lg font-semibold text-zinc-100 mb-2">보안 고려사항</h4>
								<ul className="list-disc list-inside space-y-1 text-sm">
									<li>
										<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">.env</code> 파일의
										<strong className="text-zinc-100"> 실제 값은 절대 로그에 노출되지 않습니다</strong>.
									</li>
									<li>
										KEY 이름만 비교하여 누락 여부를 확인합니다.
									</li>
									<li>
										모든 처리는 로컬에서 수행되며, 외부로 전송되지 않습니다.
									</li>
								</ul>
							</div>

							<div>
								<h4 className="text-lg font-semibold text-zinc-100 mb-2">MCP 연계 기능</h4>
								<p className="text-sm leading-relaxed mb-2">
									누락된 환경 변수가 발견되면, 다음 MCP 도구를 사용하여 코드베이스에서 사용처를 찾을 수 있습니다:
								</p>
								<ul className="list-disc list-inside space-y-1 text-sm">
									<li>
										<strong className="text-indigo-400">Codanna</strong>: 시맨틱 검색으로 환경 변수 사용처 찾기
									</li>
									<li>
										<strong className="text-indigo-400">Serena</strong>: 심볼 검색으로 정확한 위치 찾기
									</li>
								</ul>
							</div>

							<div className="bg-indigo-500/10 border-l-4 border-indigo-500/50 p-4 rounded">
								<h4 className="text-sm font-semibold text-indigo-400 mb-2">💡 사용 팁</h4>
								<p className="text-sm text-zinc-300">
									CLI에서 직접 실행하려면 프로젝트 루트에서
									<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">scripts/core/check_env.sh</code>를
									실행하세요. 대화형 모드에서는 누락된 환경 변수를 자동으로 복사할 수 있습니다.
								</p>
							</div>
						</div>
					</div>

					{/* 환경 변수 관리 UI */}
					<div className="bg-zinc-900/50 border border-zinc-800 rounded-lg p-6">
						<h3 className="text-lg font-semibold text-zinc-100 mb-4">
							환경 변수 관리
						</h3>
						<div className="space-y-4">
							<div>
								<label className="block text-sm font-medium text-zinc-300 mb-2">
									대상 프로젝트 경로
								</label>
								<input
									type="text"
									placeholder="/path/to/project"
									value={targetPath}
									onChange={(e) => setTargetPath(e.target.value)}
									className="w-full px-4 py-2 border border-zinc-800 rounded-lg bg-zinc-900/50 text-zinc-100 placeholder:text-zinc-500 focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/20"
								/>
							</div>
							<div className="flex gap-4">
								<button
									type="button"
									onClick={handleCheckEnv}
									className="px-6 py-2 bg-indigo-500 text-white rounded-lg hover:bg-indigo-600 active:scale-95 transition-all font-medium"
								>
									환경 변수 확인
								</button>
								<button
									type="button"
									onClick={handleUpdateEnv}
									className="px-6 py-2 bg-green-500 text-white rounded-lg hover:bg-green-600 active:scale-95 transition-all font-medium"
								>
									환경 변수 업데이트
								</button>
							</div>
							{envCheckResult && (
								<div className="mt-4">
									<h4 className="text-sm font-semibold text-zinc-300 mb-2">확인 결과</h4>
									<pre className="bg-zinc-950 border border-zinc-800 p-4 rounded-lg text-sm text-zinc-200 font-mono whitespace-pre-wrap overflow-auto max-h-64">
										{envCheckResult}
									</pre>
								</div>
							)}
						</div>
					</div>
				</div>
			)}

			{/* uv 마이그레이션 탭 */}
			{activeTab === "migration" && (
				<div className="space-y-4">
					{/* 기능 설명 */}
					<div className="bg-zinc-900/50 border border-zinc-800 rounded-lg p-6">
						<h3 className="text-xl font-bold text-zinc-100 mb-4">🔄 Poetry → uv 마이그레이션</h3>

						<div className="space-y-4 text-zinc-300">
							<div>
								<h4 className="text-lg font-semibold text-zinc-100 mb-2">uv란?</h4>
								<p className="text-sm leading-relaxed">
									<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">uv</code>는
									Rust로 작성된 초고속 Python 패키지 및 버전 관리자입니다.
									<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">pyenv</code>,
									<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">poetry</code>,
									<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">pip</code>를
									하나로 통합하여 환경 구축 시간을 단축하고, AI 에이전트가 의존성 충돌 없이 실행될 수 있는
									견고한 기반을 제공합니다.
								</p>
							</div>

							<div>
								<h4 className="text-lg font-semibold text-zinc-100 mb-2">마이그레이션 워크플로우</h4>
								<ol className="list-decimal list-inside space-y-2 text-sm">
									<li>
										<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">poetry.lock</code> 파일 감지
									</li>
									<li>
										<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">pyproject.toml</code>에서
										Python 버전 파싱
									</li>
									<li>
										<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">uv python install</code> 실행
									</li>
									<li>
										<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">uv sync</code>로
										<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">uv.lock</code>과
										<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">.venv</code> 생성
									</li>
									<li>
										성공 시 기존 파일 백업 (<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">.bak</code> 확장자)
									</li>
								</ol>
							</div>

							<div>
								<h4 className="text-lg font-semibold text-zinc-100 mb-2">마이그레이션의 장점</h4>
								<ul className="list-disc list-inside space-y-1 text-sm">
									<li>
										<strong className="text-zinc-100">속도</strong>: Rust 기반으로 매우 빠른 패키지 설치 및 해결
									</li>
									<li>
										<strong className="text-zinc-100">통합</strong>: Python 버전 관리, 패키지 관리, 가상 환경을 하나의 도구로 통합
									</li>
									<li>
										<strong className="text-zinc-100">호환성</strong>: Poetry의 <code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">pyproject.toml</code>과 호환
									</li>
									<li>
										<strong className="text-zinc-100">AI-Native</strong>: AI 에이전트가 의존성 충돌 없이 안정적으로 실행
									</li>
								</ul>
							</div>

							<div className="bg-yellow-500/10 border-l-4 border-yellow-500/50 p-4 rounded">
								<h4 className="text-sm font-semibold text-yellow-400 mb-2">⚠️ 주의사항</h4>
								<ul className="list-disc list-inside space-y-1 text-sm text-zinc-300">
									<li>
										마이그레이션 전에 <strong className="text-zinc-100">반드시 Git 커밋</strong>을 수행하세요.
									</li>
									<li>
										기존 <code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">poetry.lock</code>과
										<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">.venv</code>는
										자동으로 백업됩니다 (<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">.bak</code>).
									</li>
									<li>
										<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">poetry.lock</code>이 없는
										프로젝트는 마이그레이션이 건너뜁니다.
									</li>
									<li>
										마이그레이션 후 <code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">uv sync</code>로
										의존성을 설치하고 테스트를 실행하세요.
									</li>
								</ul>
							</div>

							<div className="bg-indigo-500/10 border-l-4 border-indigo-500/50 p-4 rounded">
								<h4 className="text-sm font-semibold text-indigo-400 mb-2">💡 사용 팁</h4>
								<p className="text-sm text-zinc-300 mb-2">
									CLI에서 직접 실행하려면:
								</p>
								<code className="block bg-zinc-950 border border-zinc-800 p-3 rounded text-sm text-zinc-200 font-mono">
									scripts/core/migrate_to_uv.sh [프로젝트 경로]
								</code>
							</div>
						</div>
					</div>

					{/* 마이그레이션 UI */}
					<div className="bg-zinc-900/50 border border-zinc-800 rounded-lg p-6">
						<h3 className="text-lg font-semibold text-zinc-100 mb-4">
							Poetry → uv 마이그레이션
						</h3>
						<div className="space-y-4">
							<div>
								<label className="block text-sm font-medium text-zinc-300 mb-2">
									대상 프로젝트 경로
								</label>
								<input
									type="text"
									placeholder="/path/to/project"
									value={targetPath}
									onChange={(e) => setTargetPath(e.target.value)}
									className="w-full px-4 py-2 border border-zinc-800 rounded-lg bg-zinc-900/50 text-zinc-100 placeholder:text-zinc-500 focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/20"
								/>
							</div>
							<button
								type="button"
								onClick={handleMigrateToUv}
								disabled={migrating}
								className={`px-6 py-2 rounded-lg font-semibold transition-all ${
									migrating
										? "bg-zinc-700 text-zinc-400 cursor-not-allowed"
										: "bg-indigo-500 text-white hover:bg-indigo-600 active:scale-95"
								}`}
							>
								{migrating ? "마이그레이션 중..." : "마이그레이션 시작"}
							</button>
							{migrationLogs.length > 0 && (
								<div className="mt-4">
									<h4 className="text-sm font-semibold text-zinc-300 mb-2">마이그레이션 로그</h4>
									<div className="bg-zinc-950 border border-zinc-800 text-green-400 p-4 rounded-lg font-mono text-sm max-h-96 overflow-auto">
										{migrationLogs.map((log, index) => (
											<div key={index}>{log}</div>
										))}
									</div>
								</div>
							)}
						</div>
					</div>

					{/* 도구 상태 */}
					{toolStatus && (
						<div className="bg-zinc-900/50 border border-zinc-800 rounded-lg p-6">
							<h3 className="text-lg font-semibold text-zinc-100 mb-4">
								도구 설치 상태
							</h3>
							<div className="mb-4 text-sm text-zinc-400">
								AI-Native 개발 환경에 필요한 필수 도구들의 설치 상태를 확인합니다.
							</div>
							<div className="grid grid-cols-3 gap-4">
								<div className={`p-4 rounded-lg border ${
									toolStatus.mise.installed
										? "bg-green-500/10 border-green-500/30"
										: "bg-red-500/10 border-red-500/30"
								}`}>
									<div className="font-semibold text-zinc-100 mb-1">mise</div>
									<div className="text-sm text-zinc-400">
										{toolStatus.mise.installed ? `✓ ${toolStatus.mise.version}` : "✗ 미설치"}
									</div>
									<div className="text-xs text-zinc-500 mt-1">툴체인 관리</div>
								</div>
								<div className={`p-4 rounded-lg border ${
									toolStatus.uv.installed
										? "bg-green-500/10 border-green-500/30"
										: "bg-red-500/10 border-red-500/30"
								}`}>
									<div className="font-semibold text-zinc-100 mb-1">uv</div>
									<div className="text-sm text-zinc-400">
										{toolStatus.uv.installed ? `✓ ${toolStatus.uv.version}` : "✗ 미설치"}
									</div>
									<div className="text-xs text-zinc-500 mt-1">Python 패키지 관리</div>
								</div>
								<div className={`p-4 rounded-lg border ${
									toolStatus.mcp.installed
										? "bg-green-500/10 border-green-500/30"
										: "bg-red-500/10 border-red-500/30"
								}`}>
									<div className="font-semibold text-zinc-100 mb-1">MCP</div>
									<div className="text-sm text-zinc-400">
										{toolStatus.mcp.installed ? "✓ 설정됨" : "✗ 미설정"}
									</div>
									<div className="text-xs text-zinc-500 mt-1">MCP 서버 설정</div>
								</div>
								{toolStatus.pnpm && (
									<div className={`p-4 rounded-lg border ${
										toolStatus.pnpm.installed
											? "bg-green-500/10 border-green-500/30"
											: "bg-red-500/10 border-red-500/30"
									}`}>
										<div className="font-semibold text-zinc-100 mb-1">pnpm</div>
										<div className="text-sm text-zinc-400">
											{toolStatus.pnpm.installed ? `✓ ${toolStatus.pnpm.version}` : "✗ 미설치"}
										</div>
										<div className="text-xs text-zinc-500 mt-1">Node.js 패키지 관리</div>
									</div>
								)}
								{toolStatus.gh && (
									<div className={`p-4 rounded-lg border ${
										toolStatus.gh.installed
											? "bg-green-500/10 border-green-500/30"
											: "bg-red-500/10 border-red-500/30"
									}`}>
										<div className="font-semibold text-zinc-100 mb-1">gh</div>
										<div className="text-sm text-zinc-400">
											{toolStatus.gh.installed ? `✓ ${toolStatus.gh.version}` : "✗ 미설치"}
										</div>
										<div className="text-xs text-zinc-500 mt-1">GitHub CLI</div>
									</div>
								)}
							</div>
						</div>
					)}
				</div>
			)}
		</div>
	);
}

