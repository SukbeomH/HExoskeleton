/**
 * ProgressReport 컴포넌트
 * 진행 리포트 UI - Cybernetic Minimalism Theme
 */

interface ProgressReportProps {
	progress: number; // 0-100
	logs: string[];
	error?: string | null;
}

export default function ProgressReport({ progress, logs, error }: ProgressReportProps) {
	return (
		<div className="mb-8">
			<h2 className="mb-4 text-2xl font-bold text-zinc-100">진행 리포트</h2>

			{/* 프로그레스 바 */}
			<div className="mb-4">
				<div className="h-6 w-full overflow-hidden rounded-full bg-zinc-800">
					<div
						className={`h-full transition-all duration-300 ${
							progress === 100 ? "bg-green-500" : "bg-indigo-500"
						}`}
						style={{ width: `${progress}%` }}
					/>
				</div>
				<div className="mt-2 text-right text-sm font-medium text-zinc-300">
					{progress}%
				</div>
			</div>

			{/* 로그 */}
			<div className="mb-4 max-h-[300px] overflow-y-auto rounded-lg border border-zinc-800 bg-zinc-950/50 p-4 font-mono text-sm text-zinc-200">
				{logs.length === 0 ? (
					<div className="text-zinc-500">로그가 없습니다.</div>
				) : (
					logs.map((log, index) => (
						<div key={index} className="mb-1 text-zinc-200">
							{log}
						</div>
					))
				)}
			</div>

			{/* 에러 메시지 */}
			{error && (
				<div className="rounded-lg border border-red-500/30 bg-red-500/10 p-4 text-red-400">
					<span className="font-semibold">❌</span> {error}
				</div>
			)}
		</div>
	);
}

