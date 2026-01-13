/**
 * StackDetection 컴포넌트
 * 스택 감지 UI - Cybernetic Minimalism Theme
 */

import { useState } from "react";
import { detectStack } from "@/lib/api";
import type { StackInfo } from "@/lib/types";

interface StackDetectionProps {
	onDetected: (stackInfo: StackInfo) => void;
	onPathChange?: (path: string) => void;
}

const STACK_ICONS: Record<string, string> = {
	python: "🐍",
	node: "📦",
	go: "🐹",
	rust: "🦀",
};

export default function StackDetection({ onDetected, onPathChange }: StackDetectionProps) {
	const [targetPath, setTargetPath] = useState("");
	const [loading, setLoading] = useState(false);
	const [stackInfo, setStackInfo] = useState<StackInfo | null>(null);
	const [error, setError] = useState<string | null>(null);

	const handleDetect = async () => {
		if (!targetPath.trim()) {
			setError("경로를 입력해주세요.");
			return;
		}

		setLoading(true);
		setError(null);

		try {
			const result = await detectStack(targetPath);
			setStackInfo(result);
			onDetected(result);
		} catch (err: any) {
			setError(err.response?.data?.detail || err.message || "스택 감지에 실패했습니다.");
			setStackInfo(null);
		} finally {
			setLoading(false);
		}
	};

	return (
		<div className="mb-8">
			<h2 className="mb-4 text-2xl font-bold text-zinc-100">프로젝트 감지</h2>

			<div className="mb-4 flex gap-2">
				<input
					type="text"
					value={targetPath}
					onChange={(e) => {
						setTargetPath(e.target.value);
						onPathChange?.(e.target.value);
					}}
					placeholder="/path/to/project"
					className="flex-1 rounded-lg border border-zinc-800 bg-zinc-900/50 px-4 py-2 text-zinc-100 placeholder:text-zinc-500 focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/20"
					onKeyPress={(e) => e.key === "Enter" && handleDetect()}
				/>
				<button
					onClick={handleDetect}
					disabled={loading}
					className={`rounded-lg px-6 py-2 font-medium transition-all ${
						loading
							? "cursor-not-allowed bg-zinc-700 text-zinc-400"
							: "bg-indigo-500 text-white hover:bg-indigo-600 active:scale-95"
					}`}
				>
					{loading ? "감지 중..." : "Detect"}
				</button>
			</div>

			{error && (
				<div className="mb-4 rounded-lg border border-red-500/30 bg-red-500/10 p-4 text-red-400">
					<span className="font-semibold">❌</span> {error}
				</div>
			)}

			{stackInfo && (
				<div
					className={`rounded-lg border p-4 ${
						stackInfo.stack
							? "border-zinc-800 bg-zinc-900/30"
							: "border-yellow-500/30 bg-yellow-500/10"
					}`}
				>
					{stackInfo.error && !stackInfo.stack ? (
						<div className="flex items-center gap-2 text-yellow-400">
							<span className="text-2xl">⚠️</span>
							<div>
								<div className="mb-1 font-bold">스택을 감지하지 못했습니다</div>
								<div className="text-sm text-zinc-300">{stackInfo.error}</div>
								<div className="mt-2 text-xs text-zinc-400">
									💡 일부 기능이 제한될 수 있지만, 보일러플레이트 주입은 계속 진행할 수 있습니다.
								</div>
							</div>
						</div>
					) : stackInfo.stack ? (
						<div>
							<div className="mb-2 flex items-center gap-2">
								<span className="text-3xl">{STACK_ICONS[stackInfo.stack] || "📁"}</span>
								<div>
									<div className="text-xl font-bold text-zinc-100">
										{stackInfo.stack.toUpperCase()}
									</div>
									{stackInfo.package_manager && (
										<div className="text-sm text-zinc-400">
											Package Manager: {stackInfo.package_manager}
										</div>
									)}
								</div>
							</div>
							{stackInfo.detected_files.length > 0 && (
								<div className="mt-2 text-sm text-zinc-300">
									감지된 파일: {stackInfo.detected_files.join(", ")}
								</div>
							)}
							{stackInfo.error && (
								<div className="mt-2 rounded-lg bg-yellow-500/10 p-2 text-sm text-yellow-400">
									⚠️ 경고: {stackInfo.error}
								</div>
							)}
						</div>
					) : (
						<div className="flex items-center gap-2 text-yellow-400">
							<span className="text-2xl">⚠️</span>
							<div>
								<div className="mb-1 font-bold">스택을 감지하지 못했습니다</div>
								<div className="mt-2 text-xs text-zinc-400">
									💡 일부 기능이 제한될 수 있지만, 보일러플레이트 주입은 계속 진행할 수 있습니다.
								</div>
							</div>
						</div>
					)}
				</div>
			)}
		</div>
	);
}
