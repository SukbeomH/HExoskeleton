/**
 * ApprovalModal 컴포넌트
 * verify-feedback-loop.js 실행 시 사용자 승인 요청을 처리하는 모달
 */

import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import Confetti from "react-confetti";
import { CheckCircle2, XCircle, AlertTriangle } from "lucide-react";

interface ApprovalRequest {
	title: string;
	message: string;
	details?: string[];
	severity?: "info" | "warning" | "error";
}

interface ApprovalModalProps {
	open: boolean;
	request: ApprovalRequest | null;
	onApprove: () => void;
	onReject: () => void;
}

export default function ApprovalModal({ open, request, onApprove, onReject }: ApprovalModalProps) {
	const [showConfetti, setShowConfetti] = useState(false);
	const [windowSize, setWindowSize] = useState({ width: 0, height: 0 });

	useEffect(() => {
		if (typeof window !== "undefined") {
			setWindowSize({ width: window.innerWidth, height: window.innerHeight });
		}
	}, []);

	const handleApprove = () => {
		setShowConfetti(true);
		setTimeout(() => {
			setShowConfetti(false);
			onApprove();
		}, 2000);
	};

	if (!request) return null;

	const severityColors = {
		info: "border-indigo-500/50 bg-indigo-500/10",
		warning: "border-yellow-500/50 bg-yellow-500/10",
		error: "border-red-500/50 bg-red-500/10",
	};

	const severityIcons = {
		info: CheckCircle2,
		warning: AlertTriangle,
		error: XCircle,
	};

	const Icon = severityIcons[request.severity || "info"];

	return (
		<AnimatePresence>
			{open && (
				<>
					{showConfetti && (
						<Confetti
							width={windowSize.width}
							height={windowSize.height}
							recycle={false}
							numberOfPieces={200}
							colors={["#6366f1", "#8b5cf6", "#ec4899", "#f59e0b"]}
						/>
					)}

					{/* 오버레이 */}
					<motion.div
						initial={{ opacity: 0 }}
						animate={{ opacity: 1 }}
						exit={{ opacity: 0 }}
						onClick={onReject}
						className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm"
					/>

					{/* 모달 */}
					<motion.div
						initial={{ opacity: 0, scale: 0.95, y: 20 }}
						animate={{ opacity: 1, scale: 1, y: 0 }}
						exit={{ opacity: 0, scale: 0.95, y: 20 }}
						className="fixed inset-0 z-50 flex items-center justify-center p-4"
					>
						<div
							onClick={(e) => e.stopPropagation()}
							className={`relative w-full max-w-lg rounded-lg border p-6 backdrop-blur-sm ${
								severityColors[request.severity || "info"]
							}`}
						>
							{/* 헤더 */}
							<div className="flex items-start gap-4 mb-4">
								<div className={`p-3 rounded-lg ${
									request.severity === "error"
										? "bg-red-500/20 text-red-400"
										: request.severity === "warning"
										? "bg-yellow-500/20 text-yellow-400"
										: "bg-indigo-500/20 text-indigo-400"
								}`}>
									<Icon className="w-6 h-6" />
								</div>
								<div className="flex-1">
									<h3 className="text-xl font-bold text-zinc-100 mb-1">{request.title}</h3>
									<p className="text-zinc-400">{request.message}</p>
								</div>
							</div>

							{/* 상세 정보 */}
							{request.details && request.details.length > 0 && (
								<div className="mb-6 space-y-2">
									{request.details.map((detail, index) => (
										<div
											key={index}
											className="text-sm text-zinc-300 bg-zinc-900/50 p-3 rounded border border-zinc-800"
										>
											{detail}
										</div>
									))}
								</div>
							)}

							{/* 액션 버튼 */}
							<div className="flex gap-3">
								<button
									type="button"
									onClick={onReject}
									className="flex-1 px-4 py-2 rounded-lg font-medium bg-zinc-800 text-zinc-300 hover:bg-zinc-700 active:scale-95 transition-all"
								>
									거부
								</button>
								<button
									type="button"
									onClick={handleApprove}
									className="flex-1 px-4 py-2 rounded-lg font-medium bg-indigo-500 text-white hover:bg-indigo-600 active:scale-95 transition-all"
								>
									승인
								</button>
							</div>
						</div>
					</motion.div>
				</>
			)}
		</AnimatePresence>
	);
}

