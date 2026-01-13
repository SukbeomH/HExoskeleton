/**
 * Tutorial 페이지 - Cybernetic Minimalism Theme
 * 인터랙티브 튜토리얼 - ai-onboarding.md의 핵심 3단계를 시각화
 */

import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ChevronLeft, ChevronRight, CheckCircle2, Circle, Play, Code, CheckCircle, ClipboardList, Search, Edit3 } from "lucide-react";
import Layout from "@/components/Layout";
import ToolChecker from "@/components/ToolChecker";
import Tooltip from "@/components/Tooltip";
import ToolReference from "@/components/ToolReference";
import PromptCopyCard from "@/components/PromptCopyCard";

interface TutorialStep {
	title: string;
	content: React.ReactNode;
	icon: React.ReactNode;
}

const WORKFLOW_STEPS = [
	{
		title: "Plan",
		subtitle: "설계 공유",
		description: "작업 시작 시 [MODE: PLAN]으로 시작하여 팀의 컨벤션과 spec.md를 이해했는지 확인합니다.",
		color: "indigo",
		icon: Code,
	},
	{
		title: "Execute",
		subtitle: "자동 구현",
		description: "계획이 승인되면 auto-accept 모드로 전환하여 AI가 코드를 작성하게 합니다.",
		color: "green",
		icon: Play,
	},
	{
		title: "Verify",
		subtitle: "자율 검증",
		description: "구현 직후 /verify-app 커맨드를 실행하여 AI가 스스로 검증하고 수정합니다.",
		color: "purple",
		icon: CheckCircle,
	},
];

export default function Tutorial() {
	const [currentStep, setCurrentStep] = useState(1);
	const [completedSteps, setCompletedSteps] = useState<Set<number>>(new Set());
	const [direction, setDirection] = useState<number>(1);

	useEffect(() => {
		const saved = localStorage.getItem("tutorial_progress");
		if (saved) {
			try {
				const progress = JSON.parse(saved);
				setCurrentStep(progress.currentStep || 1);
				setCompletedSteps(new Set(progress.completedSteps || []));
			} catch (e) {
				console.error("Failed to load tutorial progress:", e);
			}
		}
	}, []);

	const saveProgress = (step: number, completed: boolean) => {
		const newCompleted = new Set(completedSteps);
		if (completed) {
			newCompleted.add(step);
		} else {
			newCompleted.delete(step);
		}
		setCompletedSteps(newCompleted);
		localStorage.setItem(
			"tutorial_progress",
			JSON.stringify({
				currentStep,
				completedSteps: Array.from(newCompleted),
			})
		);
	};

	const handleNext = () => {
		if (currentStep < steps.length) {
			setDirection(1);
			saveProgress(currentStep, true);
			setCurrentStep(currentStep + 1);
		}
	};

	const handlePrev = () => {
		if (currentStep > 1) {
			setDirection(-1);
			setCurrentStep(currentStep - 1);
		}
	};

	const handleStepClick = (step: number) => {
		setDirection(step > currentStep ? 1 : -1);
		setCurrentStep(step);
	};

	const steps: TutorialStep[] = [
		{
			title: "환경 설정",
			icon: <Circle className="w-6 h-6" />,
			content: (
				<div className="space-y-6">
					<h2 className="text-2xl font-bold text-zinc-100">초기 환경 설정</h2>
					<p className="text-zinc-400">
						모든 개발 환경은 <code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">mise</code>를 통해 표준화되어 있습니다.
					</p>
					<div className="bg-indigo-500/10 border-l-4 border-indigo-500 p-4 rounded">
						<p className="font-semibold text-indigo-400 mb-2">설치 명령어:</p>
						<pre className="bg-black text-green-400 p-4 rounded overflow-x-auto font-mono text-sm">
							<code>{`# 1. 툴체인 자동 설치
mise install

# 2. 보일러플레이트 초기화
./scripts/setup-boilerplate.sh`}</code>
						</pre>
					</div>
					<ToolChecker />
				</div>
			),
		},
		{
			title: "3-Step Loop",
			icon: <Play className="w-6 h-6" />,
			content: (
				<div className="space-y-6">
					<h2 className="text-2xl font-bold text-zinc-100">핵심 워크플로우: The 3-Step Loop</h2>

					{/* 워크플로우 시각화 */}
					<div className="grid grid-cols-1 md:grid-cols-3 gap-6">
						{WORKFLOW_STEPS.map((step, index) => {
							const Icon = step.icon;
							const relatedTools = [
								{
									name: "Plan",
									tool: "Shrimp",
									icon: <ClipboardList className="w-4 h-4" />,
									description: "구조화된 작업 관리 및 계획 수립",
								},
								{
									name: "Execute",
									tool: "Serena",
									icon: <Edit3 className="w-4 h-4" />,
									description: "IDE 수준의 정밀도로 코드 수정",
								},
								{
									name: "Verify",
									tool: "Skills",
									icon: <Search className="w-4 h-4" />,
									description: "simplifier, log-analyzer, security-audit 등",
								},
							][index];

							return (
								<motion.div
									key={step.title}
									initial={{ opacity: 0, y: 20 }}
									animate={{ opacity: 1, y: 0 }}
									transition={{ delay: index * 0.1 }}
									className={`border-2 rounded-lg p-6 ${
										step.color === "indigo"
											? "border-indigo-500/50 bg-indigo-500/10"
											: step.color === "green"
											? "border-green-500/50 bg-green-500/10"
											: "border-purple-500/50 bg-purple-500/10"
									}`}
								>
									<div className="flex items-center gap-3 mb-4">
										<div
											className={`p-3 rounded-lg ${
												step.color === "indigo"
													? "bg-indigo-500/20 text-indigo-400"
													: step.color === "green"
													? "bg-green-500/20 text-green-400"
													: "bg-purple-500/20 text-purple-400"
											}`}
										>
											<Icon className="w-6 h-6" />
										</div>
										<div>
											<div className="text-2xl font-bold text-zinc-100">{index + 1}</div>
											<div className="text-sm text-zinc-400">{step.subtitle}</div>
										</div>
									</div>
									<h3 className="font-semibold text-lg mb-2 text-zinc-100">{step.title}</h3>
									<p className="text-sm text-zinc-400 mb-4">{step.description}</p>

									{/* 관련 도구 카드 */}
									<Tooltip content={relatedTools.description}>
										<div className="mt-4 p-3 rounded-lg bg-zinc-900/50 border border-zinc-800 cursor-help">
											<div className="flex items-center gap-2 text-xs text-zinc-400 mb-1">
												{relatedTools.icon}
												<span>관련 도구</span>
											</div>
											<div className="text-sm font-medium text-zinc-200">{relatedTools.tool}</div>
										</div>
									</Tooltip>
								</motion.div>
							);
						})}
					</div>

					<div className="bg-yellow-500/10 border-l-4 border-yellow-500 p-4 rounded">
						<p className="text-sm text-yellow-400">
							<strong>💡 팁:</strong> 계획 단계에서 충분히 다듬으면, 실행 단계에서 AI가 한 번에 완성할 수 있어 전체 시간이 단축됩니다.
						</p>
					</div>
				</div>
			),
		},
		{
			title: "CLAUDE.md",
			icon: <Code className="w-6 h-6" />,
			content: (
				<div className="space-y-4">
					<h2 className="text-2xl font-bold text-zinc-100">팀의 뇌: CLAUDE.md 관리법</h2>
					<p className="text-zinc-400">
						<code className="bg-zinc-800 px-2 py-1 rounded text-indigo-400">CLAUDE.md</code>는 우리 팀의 <strong className="text-zinc-100">공유 메모리</strong>입니다.
						AI가 똑똑해지느냐 멍청해지느냐는 이 파일의 관리에 달렸습니다.
					</p>

					<div className="space-y-3">
						<div className="bg-zinc-900/50 p-4 rounded-lg border border-zinc-800">
							<h3 className="font-semibold mb-2 text-zinc-100">언제 업데이트하나요?</h3>
							<ul className="list-disc list-inside text-sm text-zinc-400 space-y-1">
								<li>AI가 특정 실수를 반복할 때</li>
								<li>새로운 팀 컨벤션이 결정되었을 때</li>
							</ul>
						</div>

						<div className="bg-zinc-900/50 p-4 rounded-lg border border-zinc-800">
							<h3 className="font-semibold mb-2 text-zinc-100">PR 기반 업데이트</h3>
							<p className="text-sm text-zinc-400">
								PR 리뷰 중 AI에게 가르칠 내용이 있다면 코멘트에{" "}
								<code className="bg-zinc-800 px-1 rounded text-indigo-400">@.claude</code> 태그를 남기세요.
								GitHub Action이 이를 요약하여 <code className="bg-zinc-800 px-1 rounded text-indigo-400">CLAUDE.md</code>에 자동 반영합니다.
							</p>
						</div>

						<div className="bg-red-500/10 border-l-4 border-red-500 p-4 rounded">
							<p className="text-sm text-red-400">
								<strong>⚠️ 금기 사항:</strong> CLAUDE.md를 한 번에 너무 크게 수정하지 마세요.
								AI가 컨텍스트 과부하를 느낄 수 있습니다.
							</p>
						</div>
					</div>
				</div>
			),
		},
	];

	const stepVariants = {
		enter: (direction: number) => ({
			x: direction > 0 ? 300 : -300,
			opacity: 0,
		}),
		center: {
			x: 0,
			opacity: 1,
		},
		exit: (direction: number) => ({
			x: direction > 0 ? -300 : 300,
			opacity: 0,
		}),
	};

	return (
		<Layout>
			<div className="min-h-screen py-8">
				<div className="max-w-5xl mx-auto px-4 md:px-6">
					<div className="bg-zinc-900/50 rounded-lg border border-zinc-800 p-8 backdrop-blur-sm">
						<div className="flex items-center justify-between mb-8">
							<h1 className="text-3xl font-bold text-zinc-100">🚀 AI-Native 팀 온보딩 튜토리얼</h1>
						</div>

						{/* 스텝 인디케이터 */}
						<div className="flex items-center justify-between mb-8">
							{steps.map((step, index) => {
								const stepNum = index + 1;
								const isActive = stepNum === currentStep;
								const isCompleted = completedSteps.has(stepNum);

								return (
									<div key={stepNum} className="flex items-center flex-1">
										<button
											type="button"
											onClick={() => handleStepClick(stepNum)}
											className={`flex items-center gap-2 px-4 py-2 rounded-lg transition-all ${
												isActive
													? "bg-indigo-500/20 text-indigo-400 border border-indigo-500/50"
													: isCompleted
													? "bg-green-500/10 text-green-400 border border-green-500/30"
													: "bg-zinc-800 text-zinc-500 border border-zinc-700"
											}`}
										>
											{isCompleted ? (
												<CheckCircle2 className="w-5 h-5" />
											) : (
												<Circle className="w-5 h-5" />
											)}
											<span className="font-medium">{step.title}</span>
										</button>
										{stepNum < steps.length && (
											<div className="flex-1 h-px bg-zinc-800 mx-2" />
										)}
									</div>
								);
							})}
						</div>

						{/* 컨텐츠 영역 */}
						<div className="bg-zinc-900/30 rounded-lg p-6 mb-6 min-h-[400px] relative overflow-hidden">
							<AnimatePresence mode="wait" custom={direction}>
								<motion.div
									key={currentStep}
									custom={direction}
									variants={stepVariants}
									initial="enter"
									animate="center"
									exit="exit"
									transition={{ duration: 0.3 }}
									className="absolute inset-0 p-6"
								>
									{steps[currentStep - 1]?.content}
								</motion.div>
							</AnimatePresence>
						</div>

						{/* 네비게이션 */}
						<div className="flex justify-between items-center">
							<button
								type="button"
								onClick={handlePrev}
								disabled={currentStep === 1}
								className={`flex items-center gap-2 px-6 py-2 rounded-lg font-semibold transition-all ${
									currentStep === 1
										? "bg-zinc-800 text-zinc-500 cursor-not-allowed"
										: "bg-zinc-800 text-zinc-300 hover:bg-zinc-700 active:scale-95"
								}`}
							>
								<ChevronLeft className="w-5 h-5" />
								이전
							</button>

							<div className="text-sm text-zinc-400">
								{completedSteps.size} / {steps.length} 단계 완료
							</div>

							<button
								type="button"
								onClick={handleNext}
								disabled={currentStep === steps.length}
								className={`flex items-center gap-2 px-6 py-2 rounded-lg font-semibold transition-all ${
									currentStep === steps.length
										? "bg-zinc-800 text-zinc-500 cursor-not-allowed"
										: "bg-indigo-500 text-white hover:bg-indigo-600 active:scale-95"
								}`}
							>
								다음
								<ChevronRight className="w-5 h-5" />
							</button>
						</div>

						<div className="mt-8 text-center">
							<a
								href="/"
								className="text-indigo-400 hover:text-indigo-300 underline"
							>
								← Boilerplate Injector로 돌아가기
							</a>
						</div>
					</div>

					{/* AI와 첫 대화 시작하기 */}
					{currentStep === steps.length && (
						<motion.div
							initial={{ opacity: 0, y: 20 }}
							animate={{ opacity: 1, y: 0 }}
							transition={{ delay: 0.3 }}
							className="mt-8 bg-zinc-900/50 rounded-lg border border-zinc-800 p-8 backdrop-blur-sm"
						>
							<h2 className="text-2xl font-bold text-zinc-100 mb-4">🤖 AI와 첫 대화 시작하기</h2>
							<p className="text-zinc-400 mb-6">
								보일러플레이트 주입이 완료되었다면, 이제 AI 어시스턴트에게 프로젝트 환경을 설명할 차례입니다.
								아래 프롬프트를 복사하여 Cursor 또는 Claude Code 터미널에 붙여넣으세요.
							</p>

							<div className="space-y-4 mb-6">
								<div className="bg-indigo-500/10 border-l-4 border-indigo-500 p-4 rounded">
									<h3 className="font-semibold text-indigo-400 mb-2">단계별 가이드</h3>
									<ol className="list-decimal list-inside space-y-2 text-sm text-zinc-300">
										<li>아래 프롬프트를 복사합니다</li>
										<li>Cursor 또는 Claude Code의 채팅 터미널을 엽니다</li>
										<li>프롬프트를 붙여넣고 Enter를 누릅니다</li>
										<li>AI가 프로젝트 스택을 감지하는 과정을 관찰합니다</li>
									</ol>
								</div>
							</div>

							<PromptCopyCard
								prompt={`너는 이제부터 이 프로젝트의 **Senior AI-Native Software Engineer**로서 행동하라.
이 프로젝트에는 방금 **AI-Native Boilerplate**가 주입되었다.

**1. 지식 베이스 확인**: 프로젝트 루트의 \`CLAUDE.md\`를 먼저 읽고, 그곳에 정의된 AI Role, Persona, Anti-patterns, Team Standards를 완벽히 숙지하라.

**2. 프로토콜 준수**: 모든 작업은 \`RIPER-5\` 프로토콜(Research → Innovate → Plan → Execute → Review)을 엄격히 따라야 한다. 계획 수립 전에는 반드시 \`spec.md\`를 작성하거나 업데이트하라.

**3. MCP 도구 활용**: 사실 기반 분석을 위해 \`Codanna\`를, 정밀 편집을 위해 \`Serena\`를, 작업 관리를 위해 \`Shrimp\` MCP를 적극 활용하라.

**4. 환경 표준**: 이 프로젝트는 표준 패키지 관리자를 사용하며, 모든 검증은 \`mise run verify\` 또는 \`scripts/verify-feedback-loop.js\`를 통해 수행한다.

**5. 프로젝트 스택**: 현재 프로젝트의 스택 정보를 확인하기 위해 \`scripts/core/detect_stack.sh\`를 실행하세요.

이제 첫 번째 작업으로, \`scripts/core/detect_stack.sh\`를 실행하여 현재 프로젝트의 스택을 확인하고 보고하라.`}
							/>
						</motion.div>
					)}
				</div>
			</div>
		</Layout>
	);
}
