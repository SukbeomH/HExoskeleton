/**
 * Tutorial 페이지
 * 인터랙티브 튜토리얼 - ai-onboarding.md와 mcp-guide.md 내용을 단계별로 시각화
 */

import { useState, useEffect } from "react";
import StepIndicator from "@/components/StepIndicator";
import ToolChecker from "@/components/ToolChecker";
import ThemeToggle from "@/components/ThemeToggle";

interface TutorialStep {
	title: string;
	content: React.ReactNode;
	completed?: boolean;
}

export default function Tutorial() {
	const [currentStep, setCurrentStep] = useState(1);
	const [completedSteps, setCompletedSteps] = useState<Set<number>>(new Set());

	// localStorage에서 진행 상황 로드
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

	// 진행 상황 저장
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
			saveProgress(currentStep, true);
			setCurrentStep(currentStep + 1);
		}
	};

	const handlePrev = () => {
		if (currentStep > 1) {
			setCurrentStep(currentStep - 1);
		}
	};

	const handleStepClick = (step: number) => {
		setCurrentStep(step);
	};

	const steps: TutorialStep[] = [
		{
			title: "환경 설정",
			content: (
				<div className="space-y-4">
					<h2 className="text-2xl font-bold text-gray-800">초기 환경 설정</h2>
					<p className="text-gray-600">
						모든 개발 환경은 <code className="bg-gray-100 px-2 py-1 rounded">mise</code>를 통해 표준화되어 있습니다.
					</p>
					<div className="bg-blue-50 border-l-4 border-blue-500 p-4">
						<p className="font-semibold text-blue-800 mb-2">설치 명령어:</p>
						<pre className="bg-gray-800 text-green-400 p-4 rounded overflow-x-auto">
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
			content: (
				<div className="space-y-6">
					<h2 className="text-2xl font-bold text-gray-800">핵심 워크플로우: The 3-Step Loop</h2>
					
					<div className="grid grid-cols-1 md:grid-cols-3 gap-4">
						<div className="border-2 border-blue-500 rounded-lg p-4">
							<div className="text-3xl font-bold text-blue-500 mb-2">1</div>
							<h3 className="font-semibold text-lg mb-2">Plan (설계 공유)</h3>
							<p className="text-sm text-gray-600">
								작업 시작 시 <code className="bg-gray-100 px-1 rounded">[MODE: PLAN]</code>으로 시작하여
								팀의 컨벤션과 spec.md를 이해했는지 확인합니다.
							</p>
						</div>
						
						<div className="border-2 border-green-500 rounded-lg p-4">
							<div className="text-3xl font-bold text-green-500 mb-2">2</div>
							<h3 className="font-semibold text-lg mb-2">Build (자동 구현)</h3>
							<p className="text-sm text-gray-600">
								계획이 승인되면 <code className="bg-gray-100 px-1 rounded">auto-accept</code> 모드로 전환하여
								AI가 코드를 작성하게 합니다.
							</p>
						</div>
						
						<div className="border-2 border-purple-500 rounded-lg p-4">
							<div className="text-3xl font-bold text-purple-500 mb-2">3</div>
							<h3 className="font-semibold text-lg mb-2">Verify (자율 검증)</h3>
							<p className="text-sm text-gray-600">
								구현 직후 <code className="bg-gray-100 px-1 rounded">/verify-app</code> 커맨드를 실행하여
								AI가 스스로 검증하고 수정합니다.
							</p>
						</div>
					</div>
					
					<div className="bg-yellow-50 border-l-4 border-yellow-500 p-4">
						<p className="text-sm text-yellow-800">
							<strong>💡 팁:</strong> 계획 단계에서 충분히 다듬으면, 실행 단계에서 AI가 한 번에 완성할 수 있어 전체 시간이 단축됩니다.
						</p>
					</div>
				</div>
			),
		},
		{
			title: "CLAUDE.md",
			content: (
				<div className="space-y-4">
					<h2 className="text-2xl font-bold text-gray-800">팀의 뇌: CLAUDE.md 관리법</h2>
					<p className="text-gray-600">
						<code className="bg-gray-100 px-2 py-1 rounded">CLAUDE.md</code>는 우리 팀의 <strong>공유 메모리</strong>입니다.
						AI가 똑똑해지느냐 멍청해지느냐는 이 파일의 관리에 달렸습니다.
					</p>
					
					<div className="space-y-3">
						<div className="bg-gray-50 p-4 rounded-lg">
							<h3 className="font-semibold mb-2">언제 업데이트하나요?</h3>
							<ul className="list-disc list-inside text-sm text-gray-600 space-y-1">
								<li>AI가 특정 실수를 반복할 때</li>
								<li>새로운 팀 컨벤션이 결정되었을 때</li>
							</ul>
						</div>
						
						<div className="bg-gray-50 p-4 rounded-lg">
							<h3 className="font-semibold mb-2">PR 기반 업데이트</h3>
							<p className="text-sm text-gray-600">
								PR 리뷰 중 AI에게 가르칠 내용이 있다면 코멘트에{" "}
								<code className="bg-gray-100 px-1 rounded">@.claude</code> 태그를 남기세요.
								GitHub Action이 이를 요약하여 <code className="bg-gray-100 px-1 rounded">CLAUDE.md</code>에 자동 반영합니다.
							</p>
						</div>
						
						<div className="bg-red-50 border-l-4 border-red-500 p-4">
							<p className="text-sm text-red-800">
								<strong>⚠️ 금기 사항:</strong> CLAUDE.md를 한 번에 너무 크게 수정하지 마세요.
								AI가 컨텍스트 과부하를 느낄 수 있습니다.
							</p>
						</div>
					</div>
				</div>
			),
		},
		{
			title: "AI 에티켓",
			content: (
				<div className="space-y-4">
					<h2 className="text-2xl font-bold text-gray-800">AI 협업 에티켓</h2>
					<p className="text-gray-600">
						토큰을 아끼고 AI의 응답 정확도를 높이는 대화 매너입니다.
					</p>
					
					<div className="grid grid-cols-1 md:grid-cols-2 gap-4">
						<div className="border rounded-lg p-4">
							<h3 className="font-semibold mb-2">✅ 파일 참조 우선</h3>
							<p className="text-sm text-gray-600">
								코드를 복사해서 붙여넣지 마세요. <code className="bg-gray-100 px-1 rounded">@filename</code>을 사용하거나
								파일을 열어둔 채로 질문하세요.
							</p>
						</div>
						
						<div className="border rounded-lg p-4">
							<h3 className="font-semibold mb-2">✅ 스레드 집중</h3>
							<p className="text-sm text-gray-600">
								한 채팅에서 여러 주제를 다루지 마세요. 새로운 기능 작업 시에는 반드시 세션을 초기화합니다.
							</p>
						</div>
						
						<div className="border rounded-lg p-4">
							<h3 className="font-semibold mb-2">✅ 명확한 지시</h3>
							<p className="text-sm text-gray-600">
								모호하게 "좋아"라고 하지 마세요. "계획의 2번 항목은 좋으나 3번은 보안상 위험하니 수정해"와 같이
								구체적으로 지시하세요.
							</p>
						</div>
						
						<div className="border rounded-lg p-4">
							<h3 className="font-semibold mb-2">✅ 인색한 칭찬</h3>
							<p className="text-sm text-gray-600">
								토큰은 비용입니다. 효율적인 대화 방식은 비용을 절감하고 응답 품질을 향상시킵니다.
							</p>
						</div>
					</div>
				</div>
			),
		},
		{
			title: "MCP 설정",
			content: (
				<div className="space-y-4">
					<h2 className="text-2xl font-bold text-gray-800">MCP(Model Context Protocol) 설정</h2>
					<p className="text-gray-600">
						MCP는 AI의 감각 기관을 확장하여 <strong>검증 피드백 루프를 견고하게</strong> 만드는 핵심 도구입니다.
					</p>
					
					<div className="bg-blue-50 border-l-4 border-blue-500 p-4">
						<h3 className="font-semibold text-blue-800 mb-2">초기 구성 의무 (Initial Setup Mandate)</h3>
						<p className="text-sm text-blue-700 mb-3">
							코드를 한 줄이라도 작성하기 전에 다음 초기 구성 단계를 <strong>반드시</strong> 순서대로 완료해야 합니다.
						</p>
						<ol className="list-decimal list-inside space-y-2 text-sm text-blue-700">
							<li><strong>Shrimp Task Manager</strong> 초기화</li>
							<li><strong>Serena</strong> 활성화 및 온보딩</li>
							<li><strong>Codanna</strong> 프로파일 로드</li>
							<li>대규모 프로젝트 색인 확인</li>
						</ol>
					</div>
					
					<div className="grid grid-cols-1 md:grid-cols-2 gap-4">
						<div className="border rounded-lg p-4">
							<h3 className="font-semibold mb-2">🔍 Serena</h3>
							<p className="text-sm text-gray-600">
								심볼 기반 검색 및 정밀 편집 도구. IDE 수준의 정확도로 코드를 수정합니다.
							</p>
						</div>
						
						<div className="border rounded-lg p-4">
							<h3 className="font-semibold mb-2">🔎 Codanna</h3>
							<p className="text-sm text-gray-600">
								시맨틱 검색 및 사실 기반 분석 도구. X-ray vision으로 코드베이스를 분석합니다.
							</p>
						</div>
						
						<div className="border rounded-lg p-4">
							<h3 className="font-semibold mb-2">📋 Shrimp</h3>
							<p className="text-sm text-gray-600">
								구조화된 작업 관리 및 지속적 메모리 도구. SDD의 단일 진실 공급원 역할을 합니다.
							</p>
						</div>
						
						<div className="border rounded-lg p-4">
							<h3 className="font-semibold mb-2">🌐 Context7</h3>
							<p className="text-sm text-gray-600">
								대규모 코드베이스 컨텍스트 최적화 도구. 라이브러리 문서를 효율적으로 검색합니다.
							</p>
						</div>
					</div>
				</div>
			),
		},
		{
			title: "Git Flow",
			content: (
				<div className="space-y-4">
					<h2 className="text-2xl font-bold text-gray-800">팀 Git Flow 및 Python 표준</h2>
					
					<div className="bg-gray-50 p-4 rounded-lg">
						<h3 className="font-semibold mb-3">Git Flow 워크플로우</h3>
						<ol className="list-decimal list-inside space-y-2 text-sm text-gray-700">
							<li><strong>이슈 선행 생성:</strong> 모든 변경사항은 반드시 GitHub Issue를 먼저 생성</li>
							<li><strong>브랜치 생성:</strong> <code className="bg-gray-100 px-1 rounded">feature/&#123;issue_number&#125;-&#123;description&#125;</code> 또는 <code className="bg-gray-100 px-1 rounded">bugfix/&#123;issue_number&#125;-&#123;description&#125;</code></li>
							<li><strong>커밋 메시지:</strong> <code className="bg-gray-100 px-1 rounded">Resolved #&#123;Issue No&#125; - &#123;Description&#125;</code> 형식 강제</li>
							<li><strong>PR 병합:</strong> <code className="bg-gray-100 px-1 rounded">feature/bugfix</code> → <code className="bg-gray-100 px-1 rounded">develop</code>: 반드시 <strong>Squash and merge</strong></li>
						</ol>
					</div>
					
					<div className="bg-gray-50 p-4 rounded-lg">
						<h3 className="font-semibold mb-3">Python 프로젝트 표준</h3>
						<div className="space-y-2 text-sm text-gray-700">
							<div>
								<strong>uv 설정:</strong>
								<pre className="bg-gray-800 text-green-400 p-3 rounded mt-1 overflow-x-auto">
									<code>{`uv python install 3.11
uv sync
uv run pytest`}</code>
								</pre>
							</div>
							<div>
								<strong>로깅:</strong> 프로젝트 루트의 <code className="bg-gray-100 px-1 rounded">logging.conf</code> 파일 사용
							</div>
							<div>
								<strong>Pre-commit:</strong> <code className="bg-gray-100 px-1 rounded">uv run pre-commit run --all-files</code>
							</div>
							<div>
								<strong>Ruff:</strong> <code className="bg-gray-100 px-1 rounded">uv run ruff format</code>, <code className="bg-gray-100 px-1 rounded">uv run ruff check --fix</code>
							</div>
						</div>
					</div>
				</div>
			),
		},
	];

	const stepTitles = steps.map((step) => ({ title: step.title }));

	return (
		<div className="min-h-screen bg-gray-50 dark:bg-gray-900 py-8">
			<div className="max-w-5xl mx-auto px-4">
				<div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-8">
					<div className="flex items-center justify-between mb-8">
						<h1 className="text-3xl font-bold text-gray-800 dark:text-gray-100">
							🚀 AI-Native 팀 온보딩 튜토리얼
						</h1>
						<ThemeToggle />
					</div>
					
					<StepIndicator
						currentStep={currentStep}
						totalSteps={steps.length}
						steps={stepTitles}
						onStepClick={handleStepClick}
						completedSteps={Array.from(completedSteps)}
					/>
					
					<div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-6 mb-6 min-h-[400px]">
						{steps[currentStep - 1]?.content}
					</div>
					
					<div className="flex justify-between items-center">
						<button
							type="button"
							onClick={handlePrev}
							disabled={currentStep === 1}
							className={`px-6 py-2 rounded-lg font-semibold ${
								currentStep === 1
									? "bg-gray-300 dark:bg-gray-600 text-gray-500 dark:text-gray-400 cursor-not-allowed"
									: "bg-gray-600 dark:bg-gray-700 text-white hover:bg-gray-700 dark:hover:bg-gray-600"
							}`}
						>
							← 이전
						</button>
						
						<div className="text-sm text-gray-600 dark:text-gray-400">
							{completedSteps.size} / {steps.length} 단계 완료
						</div>
						
						<button
							type="button"
							onClick={handleNext}
							disabled={currentStep === steps.length}
							className={`px-6 py-2 rounded-lg font-semibold ${
								currentStep === steps.length
									? "bg-gray-300 dark:bg-gray-600 text-gray-500 dark:text-gray-400 cursor-not-allowed"
									: "bg-blue-600 dark:bg-blue-500 text-white hover:bg-blue-700 dark:hover:bg-blue-600"
							}`}
						>
							다음 →
						</button>
					</div>
					
					<div className="mt-8 text-center">
						<a
							href="/"
							className="text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 underline"
						>
							← Boilerplate Injector로 돌아가기
						</a>
					</div>
				</div>
			</div>
		</div>
	);
}

