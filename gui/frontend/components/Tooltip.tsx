/**
 * Tooltip 컴포넌트
 * 호버 시 정보를 표시하는 툴팁
 */

import { useState, ReactNode } from "react";
import { motion, AnimatePresence } from "framer-motion";

interface TooltipProps {
	content: string;
	children: ReactNode;
	side?: "top" | "bottom" | "left" | "right";
}

export default function Tooltip({ content, children, side = "top" }: TooltipProps) {
	const [isVisible, setIsVisible] = useState(false);

	const sideClasses = {
		top: "bottom-full left-1/2 -translate-x-1/2 mb-2",
		bottom: "top-full left-1/2 -translate-x-1/2 mt-2",
		left: "right-full top-1/2 -translate-y-1/2 mr-2",
		right: "left-full top-1/2 -translate-y-1/2 ml-2",
	};

	const arrowClasses = {
		top: "top-full left-1/2 -translate-x-1/2 border-t-zinc-800 border-l-transparent border-r-transparent border-b-transparent",
		bottom: "bottom-full left-1/2 -translate-x-1/2 border-b-zinc-800 border-l-transparent border-r-transparent border-t-transparent",
		left: "left-full top-1/2 -translate-y-1/2 border-l-zinc-800 border-t-transparent border-b-transparent border-r-transparent",
		right: "right-full top-1/2 -translate-y-1/2 border-r-zinc-800 border-t-transparent border-b-transparent border-l-transparent",
	};

	return (
		<div
			className="relative inline-block"
			onMouseEnter={() => setIsVisible(true)}
			onMouseLeave={() => setIsVisible(false)}
		>
			{children}
			<AnimatePresence>
				{isVisible && (
					<motion.div
						initial={{ opacity: 0, scale: 0.95 }}
						animate={{ opacity: 1, scale: 1 }}
						exit={{ opacity: 0, scale: 0.95 }}
						transition={{ duration: 0.15 }}
						className={`absolute z-50 ${sideClasses[side]}`}
					>
						<div className="bg-zinc-800 text-zinc-100 text-sm px-3 py-2 rounded-lg border border-zinc-700 shadow-lg max-w-xs">
							{content}
						</div>
						<div className={`absolute w-0 h-0 border-4 ${arrowClasses[side]}`} />
					</motion.div>
				)}
			</AnimatePresence>
		</div>
	);
}

