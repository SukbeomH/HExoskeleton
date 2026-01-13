/**
 * 메인 페이지 - Cybernetic Minimalism Theme
 */

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import Layout from "@/components/Layout";
import InjectorStep from "@/components/InjectorStep";
import AgentHub from "@/components/AgentHub";
import LogMonitor from "@/components/LogMonitor";
import ConfigEditor from "@/components/ConfigEditor";
import KnowledgeTimeline from "@/components/KnowledgeTimeline";
import type { StackInfo, PostDiagnosis } from "@/lib/types";

type TabType = "injector" | "agents" | "logs" | "config" | "knowledge";

export default function Home() {
	const [activeTab, setActiveTab] = useState<TabType>("injector");
	const [stackInfo, setStackInfo] = useState<StackInfo | null>(null);
	const [diagnosis, setDiagnosis] = useState<PostDiagnosis | null>(null);

	const tabs = [
		{ id: "injector" as TabType, label: "Boilerplate Injector" },
		{ id: "agents" as TabType, label: "에이전트 관리" },
		{ id: "logs" as TabType, label: "로그 모니터" },
		{ id: "config" as TabType, label: "설정 편집기" },
		{ id: "knowledge" as TabType, label: "Knowledge" },
	];

	return (
		<Layout stackInfo={stackInfo} diagnosis={diagnosis}>
			<div className="min-h-screen">
				{/* 탭 네비게이션 */}
				<div className="border-b border-zinc-800 bg-zinc-900/30 backdrop-blur-sm">
					<div className="max-w-7xl mx-auto px-4 md:px-6">
						<div className="flex space-x-1 overflow-x-auto">
							{tabs.map((tab) => (
								<button
									key={tab.id}
									type="button"
									onClick={() => setActiveTab(tab.id)}
									className={`relative px-6 py-4 text-sm font-medium transition-colors ${
										activeTab === tab.id
											? "text-indigo-400"
											: "text-zinc-400 hover:text-zinc-200"
									}`}
								>
									{tab.label}
									{activeTab === tab.id && (
										<motion.div
											layoutId="activeTab"
											className="absolute bottom-0 left-0 right-0 h-0.5 bg-indigo-500"
											initial={false}
											transition={{ type: "spring", stiffness: 500, damping: 30 }}
										/>
									)}
								</button>
							))}
						</div>
					</div>
				</div>

				{/* 컨텐츠 영역 */}
				<div className="max-w-7xl mx-auto px-4 md:px-6 py-8">
					<AnimatePresence mode="wait">
						<motion.div
							key={activeTab}
							initial={{ opacity: 0, y: 20 }}
							animate={{ opacity: 1, y: 0 }}
							exit={{ opacity: 0, y: -20 }}
							transition={{ duration: 0.2 }}
						>
							{activeTab === "injector" && (
								<div className="grid gap-6 md:grid-cols-1 lg:grid-cols-3">
									{/* 메인 인젝터 카드 */}
									<div className="lg:col-span-2">
										<motion.div
											initial={{ opacity: 0, scale: 0.95 }}
											animate={{ opacity: 1, scale: 1 }}
											transition={{ delay: 0.1 }}
											className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-6 backdrop-blur-sm cyber-glow"
										>
											<InjectorStep
												onStackDetected={setStackInfo}
												onDiagnosisUpdate={setDiagnosis}
											/>
										</motion.div>
									</div>

									{/* 사이드바 정보 카드 */}
									<div className="space-y-6">
										<motion.div
											initial={{ opacity: 0, x: 20 }}
											animate={{ opacity: 1, x: 0 }}
											transition={{ delay: 0.2 }}
											className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-6 backdrop-blur-sm"
										>
											<h3 className="mb-4 text-sm font-semibold text-zinc-300">시스템 상태</h3>
											<div className="space-y-3">
												{stackInfo && (
													<div className="text-sm">
														<div className="text-zinc-400">감지된 스택</div>
														<div className="mt-1 font-mono text-indigo-400">
															{stackInfo.stack?.toUpperCase() || "N/A"}
														</div>
													</div>
												)}
											</div>
										</motion.div>
									</div>
								</div>
							)}

							{activeTab === "agents" && (
								<motion.div
									initial={{ opacity: 0, scale: 0.95 }}
									animate={{ opacity: 1, scale: 1 }}
									transition={{ delay: 0.1 }}
									className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-6 backdrop-blur-sm"
								>
									<AgentHub />
								</motion.div>
							)}

							{activeTab === "logs" && (
								<motion.div
									initial={{ opacity: 0, scale: 0.95 }}
									animate={{ opacity: 1, scale: 1 }}
									transition={{ delay: 0.1 }}
									className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-6 backdrop-blur-sm"
								>
									<LogMonitor />
								</motion.div>
							)}

							{activeTab === "config" && (
								<motion.div
									initial={{ opacity: 0, scale: 0.95 }}
									animate={{ opacity: 1, scale: 1 }}
									transition={{ delay: 0.1 }}
									className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-6 backdrop-blur-sm"
								>
									<ConfigEditor />
								</motion.div>
							)}

							{activeTab === "knowledge" && (
								<motion.div
									initial={{ opacity: 0, scale: 0.95 }}
									animate={{ opacity: 1, scale: 1 }}
									transition={{ delay: 0.1 }}
									className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-6 backdrop-blur-sm"
								>
									<KnowledgeTimeline />
								</motion.div>
							)}
						</motion.div>
					</AnimatePresence>
				</div>
			</div>
		</Layout>
	);
}

