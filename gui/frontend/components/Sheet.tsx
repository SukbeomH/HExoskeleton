/**
 * Sheet 컴포넌트
 * 슬라이드 패널 (Shadcn/UI 스타일)
 */

import { motion, AnimatePresence } from "framer-motion";
import { X } from "lucide-react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";

interface SheetProps {
	open: boolean;
	onOpenChange: (open: boolean) => void;
	title: string;
	children: React.ReactNode;
}

export default function Sheet({ open, onOpenChange, title, children }: SheetProps) {
	return (
		<AnimatePresence>
			{open && (
				<>
					{/* 오버레이 */}
					<motion.div
						initial={{ opacity: 0 }}
						animate={{ opacity: 1 }}
						exit={{ opacity: 0 }}
						onClick={() => onOpenChange(false)}
						className="fixed inset-0 z-40 bg-black/50 backdrop-blur-sm"
					/>

					{/* Sheet 패널 */}
					<motion.div
						initial={{ x: "100%" }}
						animate={{ x: 0 }}
						exit={{ x: "100%" }}
						transition={{ type: "spring", damping: 25, stiffness: 200 }}
						className="fixed inset-y-0 right-0 z-50 w-full max-w-2xl bg-zinc-900 border-l border-zinc-800 shadow-xl"
					>
						<div className="flex h-full flex-col">
							{/* 헤더 */}
							<div className="flex h-16 items-center justify-between border-b border-zinc-800 px-6">
								<h2 className="text-lg font-semibold text-zinc-100">{title}</h2>
								<button
									onClick={() => onOpenChange(false)}
									className="p-2 rounded-lg hover:bg-zinc-800 text-zinc-400 hover:text-zinc-100 transition-colors"
								>
									<X className="h-5 w-5" />
								</button>
							</div>

							{/* 컨텐츠 */}
							<div className="flex-1 overflow-y-auto p-6">
								{children}
							</div>
						</div>
					</motion.div>
				</>
			)}
		</AnimatePresence>
	);
}

interface SheetContentProps {
	children: React.ReactNode;
}

export function SheetContent({ children }: SheetContentProps) {
	return <div className="prose prose-invert max-w-none">{children}</div>;
}

interface SheetMarkdownProps {
	content: string;
}

export function SheetMarkdown({ content }: SheetMarkdownProps) {
	return (
		<div className="prose prose-invert prose-zinc max-w-none">
			<style jsx global>{`
				.prose h1,
				.prose h2,
				.prose h3,
				.prose h4 {
					color: rgb(244 244 245);
					font-weight: 600;
				}
				.prose p {
					color: rgb(212 212 216);
				}
				.prose code {
					background-color: rgb(39 39 42);
					color: rgb(196 181 253);
					padding: 0.125rem 0.375rem;
					border-radius: 0.25rem;
					font-size: 0.875em;
				}
				.prose pre {
					background-color: rgb(24 24 27);
					border: 1px solid rgb(39 39 42);
					border-radius: 0.5rem;
					padding: 1rem;
				}
				.prose pre code {
					background-color: transparent;
					padding: 0;
				}
				.prose ul,
				.prose ol {
					color: rgb(212 212 216);
				}
				.prose a {
					color: rgb(129 140 248);
				}
				.prose a:hover {
					color: rgb(165 180 252);
				}
				.prose strong {
					color: rgb(244 244 245);
					font-weight: 600;
				}
			`}</style>
			<ReactMarkdown remarkPlugins={[remarkGfm]}>{content}</ReactMarkdown>
		</div>
	);
}

