/**
 * PromptCopyCard 컴포넌트
 * LLM 어시스턴트 초기 동기화 프롬프트를 표시하고 복사할 수 있는 카드
 * InitialSync와 McpStatus 컴포넌트를 통합
 */

import { useState } from "react";
import { motion } from "framer-motion";
import { Copy, Check, ChevronDown, ChevronUp } from "lucide-react";
import { useToast } from "./ToastProvider";
import InitialSync from "./InitialSync";
import McpStatus from "./McpStatus";

interface PromptCopyCardProps {
	prompt: string;
	onCopy?: () => void;
}

export default function PromptCopyCard({ prompt, onCopy }: PromptCopyCardProps) {
	const [copied, setCopied] = useState(false);
	const [showDetails, setShowDetails] = useState(true);
	const { showToast } = useToast();

	const handleCopy = async () => {
		try {
			await navigator.clipboard.writeText(prompt);
			setCopied(true);
			showToast("프롬프트가 클립보드에 복사되었습니다", "success");
			onCopy?.();

			// 2초 후 복사 상태 초기화
			setTimeout(() => setCopied(false), 2000);
		} catch (error) {
			showToast("복사에 실패했습니다", "error");
		}
	};

	return (
		<div className="space-y-6">
			{/* 초기 분석 및 구성 단계 */}
			<InitialSync />

			{/* MCP 서버 상태 */}
			<McpStatus />

			{/* 프롬프트 복사 카드 */}
			<motion.div
				initial={{ opacity: 0, y: 20 }}
				animate={{ opacity: 1, y: 0 }}
				transition={{ duration: 0.2 }}
				className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-6 backdrop-blur-sm"
			>
				<div className="mb-4 flex items-center justify-between">
					<h3 className="text-lg font-semibold text-zinc-100">🚀 어시스턴트에게 환경 설명하기</h3>
					<div className="flex items-center gap-2">
						<button
							onClick={() => setShowDetails(!showDetails)}
							className="flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm text-zinc-400 hover:text-zinc-100 border border-zinc-800 hover:border-zinc-700 transition-colors"
						>
							{showDetails ? (
								<>
									<ChevronUp className="h-4 w-4" />
									<span>접기</span>
								</>
							) : (
								<>
									<ChevronDown className="h-4 w-4" />
									<span>펼치기</span>
								</>
							)}
						</button>
						<button
							onClick={handleCopy}
							className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-all ${
								copied
									? "bg-green-500/10 text-green-400 border border-green-500/30"
									: "bg-indigo-500/10 text-indigo-400 border border-indigo-500/30 hover:bg-indigo-500/20 active:scale-95"
							}`}
						>
							{copied ? (
								<>
									<Check className="h-4 w-4" />
									<span>복사됨</span>
								</>
							) : (
								<>
									<Copy className="h-4 w-4" />
									<span>Copy Setup Prompt</span>
								</>
							)}
						</button>
					</div>
				</div>

				{showDetails && (
					<motion.div
						initial={{ opacity: 0, height: 0 }}
						animate={{ opacity: 1, height: "auto" }}
						exit={{ opacity: 0, height: 0 }}
						transition={{ duration: 0.2 }}
						className="relative"
					>
						<pre className="overflow-x-auto rounded-lg border border-zinc-800 bg-zinc-950 p-4 text-sm text-zinc-100 font-mono leading-relaxed max-h-96 overflow-y-auto">
							<code className="text-zinc-100 whitespace-pre-wrap">{prompt}</code>
						</pre>
					</motion.div>
				)}

				<div className="mt-4 text-xs text-zinc-300">
					<p>💡 이 프롬프트를 Cursor 또는 Claude Code 터미널에 붙여넣어 AI 어시스턴트를 초기화하세요.</p>
					<p className="mt-1 text-zinc-500">
						프롬프트에는 Codanna 분석, 스택 감지, MCP 활성화, 지식 베이스 동기화 단계가 포함되어 있습니다.
					</p>
				</div>
			</motion.div>
		</div>
	);
}

