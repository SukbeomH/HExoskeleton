/**
 * StatusBadge 컴포넌트
 * 프로젝트 스택 및 환경 진단 상태를 표시하는 배지
 */

import type { StackInfo, PostDiagnosis } from "@/lib/types";
import { CheckCircle2, AlertCircle, XCircle } from "lucide-react";

interface StatusBadgeProps {
	stackInfo: StackInfo | null;
	diagnosis: PostDiagnosis | null;
}

export default function StatusBadge({ stackInfo, diagnosis }: StatusBadgeProps) {
	const getStackStatus = () => {
		if (!stackInfo || stackInfo.error) {
			return { status: "error", label: "스택 미감지", icon: XCircle };
		}
		if (stackInfo.stack) {
			return { status: "success", label: stackInfo.stack.toUpperCase(), icon: CheckCircle2 };
		}
		return { status: "warning", label: "감지 중", icon: AlertCircle };
	};

	const getEnvStatus = () => {
		if (!diagnosis?.env_check) {
			return null;
		}
		if (diagnosis.env_check.error) {
			return { status: "error", label: "환경 오류" };
		}
		if (diagnosis.env_check.has_missing_keys) {
			return { status: "warning", label: "환경 변수 누락" };
		}
		if (diagnosis.env_check.has_env_sample) {
			return { status: "success", label: "환경 정상" };
		}
		return { status: "warning", label: ".env_sample 없음" };
	};

	const stackStatus = getStackStatus();
	const envStatus = getEnvStatus();
	const StackIcon = stackStatus.icon;

	return (
		<div className="flex items-center gap-3">
			{/* 스택 상태 배지 */}
			<div
				className={`flex items-center gap-2 px-3 py-1.5 rounded-md border ${
					stackStatus.status === "success"
						? "bg-zinc-800/50 border-indigo-500/30 text-indigo-400"
						: stackStatus.status === "warning"
							? "bg-zinc-800/50 border-yellow-500/30 text-yellow-400"
							: "bg-zinc-800/50 border-red-500/30 text-red-400"
				}`}
			>
				<StackIcon className="w-4 h-4" />
				<span className="text-sm font-medium">{stackStatus.label}</span>
			</div>

			{/* 환경 상태 배지 */}
			{envStatus && (
				<div
					className={`flex items-center gap-2 px-3 py-1.5 rounded-md border ${
						envStatus.status === "success"
							? "bg-zinc-800/50 border-indigo-500/30 text-indigo-400"
							: envStatus.status === "warning"
								? "bg-zinc-800/50 border-yellow-500/30 text-yellow-400"
								: "bg-zinc-800/50 border-red-500/30 text-red-400"
					}`}
				>
					{envStatus.status === "success" ? (
						<CheckCircle2 className="w-4 h-4" />
					) : envStatus.status === "warning" ? (
						<AlertCircle className="w-4 h-4" />
					) : (
						<XCircle className="w-4 h-4" />
					)}
					<span className="text-sm font-medium">{envStatus.label}</span>
				</div>
			)}
		</div>
	);
}

