/**
 * StackDetection 컴포넌트
 * 스택 감지 UI
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
		<div style={{ marginBottom: "2rem" }}>
			<h2 style={{ marginBottom: "1rem", fontSize: "1.5rem", fontWeight: "bold" }}>
				프로젝트 감지
			</h2>

			<div style={{ display: "flex", gap: "0.5rem", marginBottom: "1rem" }}>
			<input
				type="text"
				value={targetPath}
				onChange={(e) => {
					setTargetPath(e.target.value);
					onPathChange?.(e.target.value);
				}}
					placeholder="/path/to/project"
					style={{
						flex: 1,
						padding: "0.5rem",
						border: "1px solid #ccc",
						borderRadius: "4px",
						fontSize: "1rem",
					}}
					onKeyPress={(e) => e.key === "Enter" && handleDetect()}
				/>
				<button
					onClick={handleDetect}
					disabled={loading}
					style={{
						padding: "0.5rem 1rem",
						backgroundColor: "#0070f3",
						color: "white",
						border: "none",
						borderRadius: "4px",
						cursor: loading ? "not-allowed" : "pointer",
						fontSize: "1rem",
					}}
				>
					{loading ? "감지 중..." : "Detect"}
				</button>
			</div>

			{error && (
				<div
					style={{
						padding: "1rem",
						backgroundColor: "#fee",
						color: "#c33",
						borderRadius: "4px",
						marginBottom: "1rem",
					}}
				>
					❌ {error}
				</div>
			)}

			{stackInfo && (
				<div
					style={{
						padding: "1rem",
						backgroundColor: stackInfo.stack ? "#f5f5f5" : "#fff8e1",
						borderRadius: "4px",
						border: `1px solid ${stackInfo.stack ? "#ddd" : "#ffc107"}`,
					}}
				>
					{stackInfo.error && !stackInfo.stack ? (
						<div style={{ color: "#f57c00", display: "flex", alignItems: "center", gap: "0.5rem" }}>
							<span style={{ fontSize: "1.5rem" }}>⚠️</span>
							<div>
								<div style={{ fontWeight: "bold", marginBottom: "0.25rem" }}>
									스택을 감지하지 못했습니다
								</div>
								<div style={{ fontSize: "0.9rem", color: "#666" }}>
									{stackInfo.error}
								</div>
								<div style={{ fontSize: "0.85rem", color: "#666", marginTop: "0.5rem" }}>
									💡 일부 기능이 제한될 수 있지만, 보일러플레이트 주입은 계속 진행할 수 있습니다.
								</div>
							</div>
						</div>
					) : stackInfo.stack ? (
						<div>
							<div style={{ display: "flex", alignItems: "center", gap: "0.5rem", marginBottom: "0.5rem" }}>
								<span style={{ fontSize: "2rem" }}>{STACK_ICONS[stackInfo.stack] || "📁"}</span>
								<div>
									<div style={{ fontWeight: "bold", fontSize: "1.2rem" }}>
										{stackInfo.stack.toUpperCase()}
									</div>
									{stackInfo.package_manager && (
										<div style={{ color: "#666" }}>Package Manager: {stackInfo.package_manager}</div>
									)}
								</div>
							</div>
							{stackInfo.detected_files.length > 0 && (
								<div style={{ marginTop: "0.5rem", fontSize: "0.9rem", color: "#666" }}>
									감지된 파일: {stackInfo.detected_files.join(", ")}
								</div>
							)}
							{stackInfo.error && (
								<div style={{ marginTop: "0.5rem", padding: "0.5rem", backgroundColor: "#fff8e1", borderRadius: "4px", fontSize: "0.9rem", color: "#f57c00" }}>
									⚠️ 경고: {stackInfo.error}
								</div>
							)}
						</div>
					) : (
						<div style={{ color: "#f57c00", display: "flex", alignItems: "center", gap: "0.5rem" }}>
							<span style={{ fontSize: "1.5rem" }}>⚠️</span>
							<div>
								<div style={{ fontWeight: "bold", marginBottom: "0.25rem" }}>
									스택을 감지하지 못했습니다
								</div>
								<div style={{ fontSize: "0.85rem", color: "#666", marginTop: "0.5rem" }}>
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

