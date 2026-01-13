/**
 * InitialSync 컴포넌트
 * 초기 분석 상태바 - Codanna 분석, 스택 감지, MCP 활성화 단계를 시각화
 */

import { motion } from "framer-motion";
import { CheckCircle2, Circle, Loader2 } from "lucide-react";

interface SyncStep {
	id: string;
	label: string;
	description: string;
	status: "pending" | "in_progress" | "completed";
}

interface InitialSyncProps {
	steps?: SyncStep[];
	currentStep?: number;
}

const defaultSteps: SyncStep[] = [
	{
		id: "codanna",
		label: "Codanna 전수 분석",
		description: "프로젝트 전체 구조 및 보일러플레이트 통합 분석",
		status: "pending",
	},
	{
		id: "stack",
		label: "스택 및 도구 감지",
		description: "기술 스택 확정 및 패키지 매니저 준비",
		status: "pending",
	},
	{
		id: "mcp",
		label: "MCP 서버 활성화",
		description: "필수 MCP 서버 상태 점검 및 활성화",
		status: "pending",
	},
	{
		id: "knowledge",
		label: "지식 베이스 동기화",
		description: "CLAUDE.md 규칙 숙지 및 프로젝트 특이사항 기록",
		status: "pending",
	},
];

export default function InitialSync({ steps = defaultSteps, currentStep = 0 }: InitialSyncProps) {
	const getStepIcon = (step: SyncStep, index: number) => {
		if (index < currentStep || step.status === "completed") {
			return <CheckCircle2 className="h-5 w-5 text-green-400" />;
		}
		if (index === currentStep || step.status === "in_progress") {
			return <Loader2 className="h-5 w-5 text-indigo-400 animate-spin" />;
		}
		return <Circle className="h-5 w-5 text-zinc-600" />;
	};

	const getStepStatusColor = (step: SyncStep, index: number) => {
		if (index < currentStep || step.status === "completed") {
			return "text-green-400 border-green-500/30 bg-green-500/10";
		}
		if (index === currentStep || step.status === "in_progress") {
			return "text-indigo-400 border-indigo-500/30 bg-indigo-500/10";
		}
		return "text-zinc-400 border-zinc-800 bg-zinc-900/30";
	};

	return (
		<div className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-6 backdrop-blur-sm">
			<div className="mb-6">
				<h3 className="text-lg font-semibold text-zinc-100 mb-2">초기 분석 및 구성</h3>
				<p className="text-sm text-zinc-400">
					AI가 Codanna를 통해 프로젝트를 분석하고 MCP 서버를 활성화하는 과정입니다.
				</p>
			</div>

			<div className="space-y-4">
				{steps.map((step, index) => (
					<motion.div
						key={step.id}
						initial={{ opacity: 0, x: -20 }}
						animate={{ opacity: 1, x: 0 }}
						transition={{ duration: 0.2, delay: index * 0.1 }}
						className={`flex items-start gap-4 rounded-lg border p-4 transition-colors ${getStepStatusColor(step, index)}`}
					>
						<div className="mt-0.5 flex-shrink-0">{getStepIcon(step, index)}</div>
						<div className="flex-1">
							<div className="font-semibold text-zinc-100 mb-1">{step.label}</div>
							<div className="text-sm text-zinc-400">{step.description}</div>
						</div>
					</motion.div>
				))}
			</div>

			<div className="mt-6 pt-4 border-t border-zinc-800">
				<p className="text-xs text-zinc-500">
					💡 이 단계들은 AI가 프롬프트를 받은 후 자동으로 수행합니다. 각 단계가 완료되면 AI가 보고합니다.
				</p>
			</div>
		</div>
	);
}

