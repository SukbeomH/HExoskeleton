/**
 * InjectorStep 컴포넌트
 * 메인 인젝터 컴포넌트
 */

import { useState } from "react";
import StackDetection from "./StackDetection";
import AssetSelection from "./AssetSelection";
import ProgressReport from "./ProgressReport";
import EnvDiagnosis from "./EnvDiagnosis";
import PromptCopyCard from "./PromptCopyCard";
import { injectBoilerplate } from "@/lib/api";
import type { StackInfo, InjectResponse, InjectionOptions, PostDiagnosis } from "@/lib/types";

interface InjectorStepProps {
	onStackDetected?: (stackInfo: StackInfo | null) => void;
	onDiagnosisUpdate?: (diagnosis: PostDiagnosis | null) => void;
}

export default function InjectorStep({ onStackDetected, onDiagnosisUpdate }: InjectorStepProps) {
	const [targetPath, setTargetPath] = useState("");
	const [stackInfo, setStackInfo] = useState<StackInfo | null>(null);

	// StackDetection에서 경로를 받아오는 콜백
	const handlePathChange = (path: string) => {
		setTargetPath(path);
	};
	const [selectedAssets, setSelectedAssets] = useState<string[]>([]);
	const [injectionOptions, setInjectionOptions] = useState<InjectionOptions>({
		backup_existing: true,
		merge_claude_config: false,
		skip_existing: false,
	});
	const [progress, setProgress] = useState(0);
	const [logs, setLogs] = useState<string[]>([]);
	const [injectResult, setInjectResult] = useState<InjectResponse | null>(null);
	const [loading, setLoading] = useState(false);

	const handleDetected = (info: StackInfo) => {
		setStackInfo(info);
		onStackDetected?.(info);
		// targetPath는 사용자가 입력한 경로이므로 변경하지 않음
	};

	const handleApply = async () => {
		if (!targetPath.trim()) {
			alert("대상 경로를 입력하고 스택을 감지해주세요.");
			return;
		}

		if (selectedAssets.length === 0) {
			alert("주입할 자산을 선택해주세요.");
			return;
		}

		setLoading(true);
		setProgress(0);
		setLogs([]);
		setInjectResult(null);

		try {
			setLogs((prev) => [...prev, "주입 프로세스 시작..."]);
			setProgress(10);

			setLogs((prev) => [...prev, `대상 경로: ${targetPath}`]);
			setProgress(20);

			setLogs((prev) => [...prev, `선택된 자산: ${selectedAssets.join(", ")}`]);
			setProgress(30);

			const result = await injectBoilerplate(targetPath, selectedAssets, injectionOptions);

			setLogs((prev) => [...prev, "주입 완료"]);
			setProgress(100);

			if (result.injected_files.length > 0) {
				setLogs((prev) => [...prev, `✅ 주입된 파일: ${result.injected_files.length}개`]);
			}
			if (result.backed_up_files.length > 0) {
				setLogs((prev) => [...prev, `📦 백업된 파일: ${result.backed_up_files.length}개`]);
			}
			if (result.skipped_files.length > 0) {
				setLogs((prev) => [...prev, `⏭️ 건너뛴 파일: ${result.skipped_files.length}개`]);
			}
			if (result.merged_files.length > 0) {
				setLogs((prev) => [...prev, `🔀 병합된 파일: ${result.merged_files.length}개`]);
			}

			setInjectResult(result);
			if (result.post_diagnosis) {
				onDiagnosisUpdate?.(result.post_diagnosis);
			}
		} catch (error: any) {
			setLogs((prev) => [...prev, `❌ 에러: ${error.message}`]);
			setProgress(0);
		} finally {
			setLoading(false);
		}
	};

	return (
		<div className="space-y-6">
			<h1 className="mb-8 text-2xl font-bold text-zinc-100">AI-Native Boilerplate Injector</h1>

			{/* 스택 감지 */}
			<StackDetection onDetected={handleDetected} onPathChange={handlePathChange} />

			{/* 자산 선택 */}
			{stackInfo && <AssetSelection onSelectionChange={setSelectedAssets} />}

			{/* 주입 옵션 */}
			{selectedAssets.length > 0 && (
				<div className="mb-8 rounded-lg border border-zinc-800 bg-zinc-900/30 p-6">
					<h2 className="mb-4 text-xl font-bold text-zinc-100">주입 옵션</h2>
					<div className="flex flex-col gap-3">
						<label className="flex items-center gap-3 text-zinc-300">
							<input
								type="checkbox"
								checked={injectionOptions.backup_existing}
								onChange={(e) =>
									setInjectionOptions({ ...injectionOptions, backup_existing: e.target.checked })
								}
								className="h-4 w-4 rounded border-zinc-700 bg-zinc-800 text-indigo-500 focus:ring-2 focus:ring-indigo-500"
							/>
							<span>기존 파일 백업 (.bak 파일 생성)</span>
						</label>
						<label className="flex items-center gap-3 text-zinc-300">
							<input
								type="checkbox"
								checked={injectionOptions.merge_claude_config}
								onChange={(e) =>
									setInjectionOptions({ ...injectionOptions, merge_claude_config: e.target.checked })
								}
								className="h-4 w-4 rounded border-zinc-700 bg-zinc-800 text-indigo-500 focus:ring-2 focus:ring-indigo-500"
							/>
							<span>.claude/ 설정 병합 (기존 설정과 합성)</span>
						</label>
						<label className="flex items-center gap-3 text-zinc-300">
							<input
								type="checkbox"
								checked={injectionOptions.skip_existing}
								onChange={(e) =>
									setInjectionOptions({ ...injectionOptions, skip_existing: e.target.checked })
								}
								className="h-4 w-4 rounded border-zinc-700 bg-zinc-800 text-indigo-500 focus:ring-2 focus:ring-indigo-500"
							/>
							<span>기존 파일 건너뛰기</span>
						</label>
					</div>
				</div>
			)}

			{/* Apply 버튼 */}
			{selectedAssets.length > 0 && (
				<div className="mb-8">
					<button
						onClick={handleApply}
						disabled={loading}
						className={`rounded-lg px-8 py-3 text-lg font-bold transition-all ${
							loading
								? "cursor-not-allowed bg-zinc-700 text-zinc-400"
								: "bg-indigo-500 text-white hover:bg-indigo-600 hover:shadow-lg hover:shadow-indigo-500/50 active:scale-95"
						}`}
					>
						{loading ? "주입 중..." : "Apply AI-Native Standards"}
					</button>
				</div>
			)}

			{/* 진행 리포트 */}
			{(loading || injectResult) && (
				<ProgressReport progress={progress} logs={logs} error={injectResult?.error || null} />
			)}

			{/* 프롬프트 복사 카드 (인젝션 성공 시) */}
			{injectResult?.status === "success" && injectResult?.setup_prompt && (
				<PromptCopyCard prompt={injectResult.setup_prompt} />
			)}

			{/* 사후 진단 */}
			{injectResult?.post_diagnosis && <EnvDiagnosis diagnosis={injectResult.post_diagnosis} />}
		</div>
	);
}

