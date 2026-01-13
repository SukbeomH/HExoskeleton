/**
 * EnvDiagnosis 컴포넌트
 * 환경 진단 UI - Cybernetic Minimalism Theme
 */

import type { PostDiagnosis } from "@/lib/types";

interface EnvDiagnosisProps {
	diagnosis: PostDiagnosis | null;
}

export default function EnvDiagnosis({ diagnosis }: EnvDiagnosisProps) {
	if (!diagnosis) {
		return null;
	}

	return (
		<div className="mb-8">
			<h2 className="mb-4 text-2xl font-bold text-zinc-100">사후 진단</h2>

			{/* 환경 변수 체크 - 비활성화됨: 주입될 프로젝트마다 환경변수가 다를 수 있음 */}
			{/* 필요시 아래 주석을 해제하여 활성화 가능 */}
			{/* {diagnosis.env_check && (
				<div className="mb-4 rounded-lg border border-zinc-800 bg-zinc-900/30 p-4">
					<h3 className="mb-2 text-lg font-semibold text-zinc-100">환경 변수 체크</h3>
					{diagnosis.env_check.error ? (
						<div className="text-red-400">❌ {diagnosis.env_check.error}</div>
					) : (
						<div>
							<div className="mb-2">
								{diagnosis.env_check.has_env_sample ? (
									<span className="text-green-400">✅ .env_sample 파일 존재</span>
								) : (
									<span className="text-yellow-400">⚠️ .env_sample 파일 없음</span>
								)}
							</div>
							{diagnosis.env_check.has_missing_keys && (
								<div className="mt-2 text-yellow-400">
									⚠️ 누락된 환경 변수가 있습니다. check_env.sh를 실행하여 확인하세요.
								</div>
							)}
						</div>
					)}
				</div>
			)} */}

			{/* Git 상태 */}
			{diagnosis.git_status && (
				<div className="rounded-lg border border-zinc-800 bg-zinc-900/30 p-4">
					<h3 className="mb-2 text-lg font-semibold text-zinc-100">Git 상태</h3>
					{diagnosis.git_status.error ? (
						<div className="text-red-400">❌ {diagnosis.git_status.error}</div>
					) : diagnosis.git_status.is_git_repo ? (
						<div>
							<div className="mb-2">
								<span className="text-green-400">✅ Git 저장소</span>
								{diagnosis.git_status.current_branch && (
									<span className="ml-4 text-zinc-400">
										브랜치: {diagnosis.git_status.current_branch}
									</span>
								)}
							</div>
							{diagnosis.git_status.has_changes && diagnosis.git_status.changed_files && (
								<div className="mt-2">
									<div className="mb-1 text-yellow-400">
										⚠️ 변경된 파일: {diagnosis.git_status.changed_files.length}개
									</div>
									<div className="max-h-[100px] overflow-y-auto text-sm text-zinc-300">
										{diagnosis.git_status.changed_files.slice(0, 10).map((file, index) => (
											<div key={index}>{file}</div>
										))}
										{diagnosis.git_status.changed_files.length > 10 && (
											<div>
												... 외 {diagnosis.git_status.changed_files.length - 10}개
											</div>
										)}
									</div>
								</div>
							)}
						</div>
					) : (
						<div>
							<div className="mb-2 text-yellow-400">
								⚠️ {diagnosis.git_status.message || "Git 저장소가 아닙니다."}
							</div>
							<div className="text-sm text-zinc-400">
								권장:{" "}
								<code className="rounded bg-zinc-800 px-2 py-1 text-zinc-200">
									git init
								</code>
								을 실행하세요.
							</div>
						</div>
					)}
				</div>
			)}
		</div>
	);
}
