/**
 * AgentHub 컴포넌트 - Cybernetic Minimalism Theme
 * 에이전트 관리 대시보드 - 개별 에이전트 실행 및 실시간 결과 뷰어
 */

import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Play, FileText, CheckCircle2, XCircle, AlertCircle } from "lucide-react";
import { runAgent, runAgentStream, getSkillInstructions, type AgentRunRequest } from "@/lib/api";
import Sheet, { SheetMarkdown } from "./Sheet";
import Tooltip from "./Tooltip";

interface AgentStatus {
	name: string;
	id: string;
	status: "idle" | "running" | "completed" | "failed";
	lastRun?: Date;
	result?: any;
	logs: string[];
}

const SKILLS = [
	{
		id: "simplifier",
		name: "Code Simplifier",
		displayName: "Simplifier",
		description: "인지적 복잡도를 분석하고 불필요한 추상화나 중복을 찾아 리팩토링을 제안합니다.",
	},
	{
		id: "log-analyzer",
		name: "Log Analyzer",
		displayName: "Log Analyzer",
		description: "로컬 로그 분석 및 ERROR/CRITICAL 감지하여 Codanna/Serena MCP로 관련 코드를 정밀 분석합니다.",
	},
	{
		id: "security-audit",
		name: "Security Audit",
		displayName: "Security Audit",
		description: "스택별 보안 취약점 검사 (Python: safety, Node.js: npm/pnpm audit)를 수행합니다.",
	},
	{
		id: "visual-verifier",
		name: "Visual Verifier",
		displayName: "Visual Verifier",
		description: "웹 프로젝트 시각적 검증 (Chrome DevTools MCP 연계)을 통해 UI 렌더링과 콘솔 에러를 확인합니다.",
	},
];

export default function AgentHub() {
	const [agents, setAgents] = useState<AgentStatus[]>(
		SKILLS.map((skill) => ({
			name: skill.name,
			id: skill.id,
			status: "idle" as const,
			logs: [],
		}))
	);

	const [loading, setLoading] = useState(false);
	const [targetPath, setTargetPath] = useState<string>("");
	const [selectedSkill, setSelectedSkill] = useState<string | null>(null);
	const [instructionsContent, setInstructionsContent] = useState<string>("");
	const [instructionsLoading, setInstructionsLoading] = useState(false);

	const runSingleAgent = async (agentId: string) => {
		const agent = agents.find((a) => a.id === agentId);
		if (!agent) return;

		// API에서 사용하는 agent_name 형식으로 변환
		const apiAgentName = agentId.replace("-", "_") as "simplifier" | "visual_verifier" | "security_audit" | "log_analyzer";

		setAgents((prev) =>
			prev.map((a) =>
				a.id === agentId ? { ...a, status: "running" as const, logs: [] } : a
			)
		);

		try {
			const request: AgentRunRequest = {
				agent_name: apiAgentName,
				target_path: targetPath || undefined,
			};

			// 실시간 스트리밍
			const eventSource = runAgentStream(request, (data) => {
				if (data.type === "log") {
					setAgents((prev) =>
						prev.map((a) =>
							a.id === agentId
								? { ...a, logs: [...a.logs, data.message] }
								: a
						)
					);
				} else if (data.type === "success") {
					setAgents((prev) =>
						prev.map((a) =>
							a.id === agentId
								? {
										...a,
										status: "completed" as const,
										lastRun: new Date(),
									}
								: a
						)
					);
					eventSource.close();
				} else if (data.type === "error") {
					setAgents((prev) =>
						prev.map((a) =>
							a.id === agentId
								? {
										...a,
										status: "failed" as const,
										lastRun: new Date(),
									}
								: a
						)
					);
					eventSource.close();
				}
			});

			// 결과도 가져오기
			const result = await runAgent(request);
			if (result.status === "success" && result.result) {
				setAgents((prev) =>
					prev.map((a) =>
						a.id === agentId ? { ...a, result: result.result } : a
					)
				);
			}
		} catch (error) {
			console.error(`Agent ${agentId} failed:`, error);
			setAgents((prev) =>
				prev.map((a) =>
					a.id === agentId
						? { ...a, status: "failed" as const, lastRun: new Date() }
						: a
				)
			);
		}
	};

	const handleViewInstructions = async (skillId: string) => {
		setSelectedSkill(skillId);
		setInstructionsLoading(true);
		try {
			const instructions = await getSkillInstructions(skillId);
			setInstructionsContent(instructions.content);
		} catch (error) {
			console.error("Failed to load instructions:", error);
			setInstructionsContent("Failed to load instructions.");
		} finally {
			setInstructionsLoading(false);
		}
	};

	const getStatusColor = (status: AgentStatus["status"]) => {
		switch (status) {
			case "completed":
				return "text-green-400";
			case "running":
				return "text-indigo-400";
			case "failed":
				return "text-red-400";
			default:
				return "text-zinc-400";
		}
	};

	const getResultBadges = (result: any) => {
		const badges = [];
		if (result?.suggestions !== undefined) {
			badges.push({ label: "Suggestions", value: result.suggestions, color: "indigo" });
		}
		if (result?.vulnerabilities !== undefined) {
			badges.push({ label: "Vulnerabilities", value: result.vulnerabilities, color: result.vulnerabilities === 0 ? "green" : "red" });
		}
		if (result?.complexity !== undefined) {
			badges.push({ label: "Complexity", value: result.complexity, color: "purple" });
		}
		if (result?.errors && result.errors.length > 0) {
			badges.push({ label: "Errors", value: result.errors.length, color: "red" });
		}
		return badges;
	};

	return (
		<div className="space-y-6">
			<div className="flex items-center justify-between">
				<h2 className="text-2xl font-bold text-zinc-100">Agent Skills Hub</h2>
				<div className="flex gap-4">
					<input
						type="text"
						placeholder="대상 프로젝트 경로 (선택사항)"
						value={targetPath}
						onChange={(e) => setTargetPath(e.target.value)}
						className="px-4 py-2 rounded-lg border border-zinc-800 bg-zinc-900 text-zinc-100 placeholder-zinc-500 focus:outline-none focus:ring-2 focus:ring-indigo-500"
					/>
				</div>
			</div>

			{/* 에이전트 카드 그리드 */}
			<div className="grid grid-cols-1 md:grid-cols-2 gap-6">
				{agents.map((agent) => {
					const skill = SKILLS.find((s) => s.id === agent.id);
					const badges = agent.result ? getResultBadges(agent.result) : [];
					const isRunning = agent.status === "running";

					return (
						<motion.div
							key={agent.id}
							layout
							initial={{ opacity: 0, scale: 0.95 }}
							animate={{ opacity: 1, scale: 1 }}
							transition={{ duration: 0.2 }}
							className="relative rounded-lg border border-zinc-800 bg-zinc-900/50 p-6 backdrop-blur-sm hover:border-indigo-500/50 transition-colors"
						>
							{/* Status Ping 애니메이션 */}
							<div className="absolute top-4 right-4">
								{isRunning && (
									<div className="relative">
										<motion.div
											animate={{ scale: [1, 1.5, 1], opacity: [1, 0, 1] }}
											transition={{ duration: 2, repeat: Infinity }}
											className="absolute inset-0 rounded-full bg-indigo-500"
										/>
										<div className="relative w-3 h-3 rounded-full bg-indigo-500" />
									</div>
								)}
								{agent.status === "completed" && (
									<CheckCircle2 className="w-5 h-5 text-green-400" />
								)}
								{agent.status === "failed" && (
									<XCircle className="w-5 h-5 text-red-400" />
								)}
								{agent.status === "idle" && (
									<AlertCircle className="w-5 h-5 text-zinc-400" />
								)}
							</div>

							{/* 카드 헤더 */}
							<div className="mb-4">
								<Tooltip content={skill?.description || ""}>
									<h3 className="text-lg font-semibold text-zinc-100 mb-1 cursor-help">
										{skill?.displayName || agent.name}
									</h3>
								</Tooltip>
								<div className="flex items-center gap-2">
									<span className={`text-sm font-medium ${getStatusColor(agent.status)}`}>
										{agent.status === "completed"
											? "Completed"
											: agent.status === "running"
											? "Running"
											: agent.status === "failed"
											? "Failed"
											: "Idle"}
									</span>
									{agent.lastRun && (
										<span className="text-xs text-zinc-500">
											{agent.lastRun.toLocaleTimeString()}
										</span>
									)}
								</div>
							</div>

							{/* 결과 배지 */}
							{badges.length > 0 && (
								<div className="mb-4 flex flex-wrap gap-2">
									{badges.map((badge, index) => (
										<span
											key={index}
											className={`px-2 py-1 rounded text-xs font-medium ${
												badge.color === "green"
													? "bg-green-500/20 text-green-400 border border-green-500/30"
													: badge.color === "red"
													? "bg-red-500/20 text-red-400 border border-red-500/30"
													: badge.color === "purple"
													? "bg-purple-500/20 text-purple-400 border border-purple-500/30"
													: "bg-indigo-500/20 text-indigo-400 border border-indigo-500/30"
											}`}
										>
											{badge.label}: {badge.value}
										</span>
									))}
								</div>
							)}

							{/* 액션 버튼 */}
							<div className="flex gap-2">
								<button
									type="button"
									onClick={() => runSingleAgent(agent.id)}
									disabled={isRunning}
									className={`flex-1 flex items-center justify-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all ${
										isRunning
											? "bg-zinc-800 text-zinc-500 cursor-not-allowed"
											: "bg-indigo-500 text-white hover:bg-indigo-600 active:scale-95"
									}`}
								>
									<Play className="w-4 h-4" />
									{isRunning ? "Running..." : "Run"}
								</button>
								<button
									type="button"
									onClick={() => handleViewInstructions(agent.id)}
									className="flex items-center justify-center gap-2 px-4 py-2 rounded-lg text-sm font-medium bg-zinc-800 text-zinc-300 hover:bg-zinc-700 active:scale-95 transition-all"
								>
									<FileText className="w-4 h-4" />
									Instructions
								</button>
							</div>
						</motion.div>
					);
				})}
			</div>

			{/* Instructions Sheet */}
			<Sheet
				open={selectedSkill !== null}
				onOpenChange={(open) => !open && setSelectedSkill(null)}
				title={selectedSkill ? SKILLS.find((s) => s.id === selectedSkill)?.name || "Instructions" : "Instructions"}
			>
				{instructionsLoading ? (
					<div className="text-zinc-400">Loading instructions...</div>
				) : (
					<SheetMarkdown content={instructionsContent} />
				)}
			</Sheet>
		</div>
	);
}
