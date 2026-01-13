/**
 * Toast 컴포넌트
 * 알림 메시지를 표시하는 Toast 컴포넌트
 */

import { motion, AnimatePresence } from "framer-motion";
import { CheckCircle2, XCircle, Info, X } from "lucide-react";
import { useEffect, useState } from "react";

export type ToastType = "success" | "error" | "info";

interface ToastProps {
	message: string;
	type?: ToastType;
	duration?: number;
	onClose?: () => void;
}

export default function Toast({ message, type = "info", duration = 3000, onClose }: ToastProps) {
	const [isVisible, setIsVisible] = useState(true);

	useEffect(() => {
		if (duration > 0) {
			const timer = setTimeout(() => {
				setIsVisible(false);
				setTimeout(() => onClose?.(), 300); // 애니메이션 완료 후 제거
			}, duration);

			return () => clearTimeout(timer);
		}
	}, [duration, onClose]);

	const icons = {
		success: CheckCircle2,
		error: XCircle,
		info: Info,
	};

	const colors = {
		success: "bg-green-500/10 border-green-500/30 text-green-400",
		error: "bg-red-500/10 border-red-500/30 text-red-400",
		info: "bg-indigo-500/10 border-indigo-500/30 text-indigo-400",
	};

	const Icon = icons[type];

	return (
		<AnimatePresence>
			{isVisible && (
				<motion.div
					initial={{ opacity: 0, y: 20 }}
					animate={{ opacity: 1, y: 0 }}
					exit={{ opacity: 0, y: -20 }}
					transition={{ duration: 0.2 }}
					className={`fixed bottom-4 left-1/2 -translate-x-1/2 z-50 flex items-center gap-3 px-4 py-3 rounded-lg border backdrop-blur-sm ${colors[type]} shadow-lg`}
				>
					<Icon className="h-5 w-5 flex-shrink-0" />
					<span className="text-sm font-semibold">{message}</span>
					{onClose && (
						<button
							onClick={() => {
								setIsVisible(false);
								setTimeout(() => onClose(), 300);
							}}
							className="ml-2 p-1 rounded hover:bg-white/10 transition-colors"
						>
							<X className="h-4 w-4" />
						</button>
					)}
				</motion.div>
			)}
		</AnimatePresence>
	);
}

