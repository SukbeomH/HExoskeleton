/**
 * ToolChecker 컴포넌트 - Cybernetic Minimalism Theme
 * 필수 도구(mise, uv, mcp, pnpm, gh)의 설치 상태를 확인하고 표시합니다.
 */

import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { CheckCircle2, XCircle, Copy, Check } from "lucide-react";
import { checkTools, type ToolStatus } from "@/lib/api";

interface ToolCheckerProps {
	onStatusChange?: (allInstalled: boolean) => void;
}

interface ToolInfo {
	name: string;
	label: string;
	installCmd: string;
	installUrl?: string;
}

const TOOLS: Record<string, ToolInfo> = {
	mise: {
		name: "mise",
		label: "Mise",
		installCmd: "curl https://mise.run | sh",
		installUrl: "https://mise.jdx.dev/",
	},
	uv: {
		name: "uv",
		label: "uv",
		installCmd: "curl -LsSf https://astral.sh/uv/install.sh | sh",
		installUrl: "https://github.com/astral-sh/uv",
	},
	pnpm: {
		name: "pnpm",
		label: "pnpm",
		installCmd: "curl -fsSL https://get.pnpm.io/install.sh | sh -",
		installUrl: "https://pnpm.io/installation",
	},
	gh: {
		name: "gh",
		label: "GitHub CLI",
		installCmd: "brew install gh",
		installUrl: "https://cli.github.com/",
	},
	mcp: {
		name: "mcp",
		label: "MCP Config",
		installCmd: ".mcp.json 파일이 필요합니다.",
	},
};

export default function ToolChecker({ onStatusChange }: ToolCheckerProps) {
	const [toolStatus, setToolStatus] = useState<ToolStatus | null>(null);
	const [loading, setLoading] = useState(true);
	const [copiedTool, setCopiedTool] = useState<string | null>(null);

	useEffect(() => {
		const fetchToolStatus = async () => {
			try {
				const status = await checkTools();
				setToolStatus(status);

				const allInstalled =
					status.mise.installed &&
					status.uv.installed &&
					status.mcp.installed &&
					(status.pnpm?.installed ?? true) &&
					(status.gh?.installed ?? true);

				onStatusChange?.(allInstalled);
			} catch (error) {
				console.error("Failed to check tools:", error);
			} finally {
				setLoading(false);
			}
		};

		fetchToolStatus();
		const interval = setInterval(fetchToolStatus, 5000);

		return () => clearInterval(interval);
	}, [onStatusChange]);

	const handleCopy = async (toolName: string, cmd: string) => {
		try {
			await navigator.clipboard.writeText(cmd);
			setCopiedTool(toolName);
			setTimeout(() => setCopiedTool(null), 2000);
		} catch (error) {
			console.error("Failed to copy:", error);
		}
	};

	if (loading) {
		return (
			<div className="flex items-center gap-2 text-zinc-400">
				<div className="animate-spin h-4 w-4 border-2 border-indigo-500 border-t-transparent rounded-full" />
				<span>도구 상태 확인 중...</span>
			</div>
		);
	}

	if (!toolStatus) {
		return <div className="text-red-400">도구 상태를 확인할 수 없습니다.</div>;
	}

	const tools = [
		{
			...TOOLS.mise,
			status: toolStatus.mise,
		},
		{
			...TOOLS.uv,
			status: toolStatus.uv,
		},
		{
			...TOOLS.pnpm,
			status: toolStatus.pnpm || { installed: false, version: null },
		},
		{
			...TOOLS.gh,
			status: toolStatus.gh || { installed: false, version: null },
		},
		{
			...TOOLS.mcp,
			status: toolStatus.mcp,
		},
	];

	return (
		<div className="space-y-4">
			<h3 className="text-lg font-semibold text-zinc-100">필수 도구 상태</h3>
			<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
				{tools.map((tool) => {
					const isInstalled = tool.status.installed || (tool.name === "mcp" && (tool.status as any).config_exists);
					const version = "version" in tool.status ? tool.status.version : null;

					return (
						<motion.div
							key={tool.name}
							layout
							initial={{ opacity: 0, scale: 0.95 }}
							animate={{ opacity: 1, scale: 1 }}
							className={`rounded-lg border p-4 ${
								isInstalled
									? "border-green-500/30 bg-green-500/10"
									: "border-red-500/30 bg-red-500/10"
							}`}
						>
							<div className="flex items-center justify-between mb-2">
								<span className="font-medium text-zinc-100">{tool.label}</span>
								{isInstalled ? (
									<CheckCircle2 className="w-5 h-5 text-green-400" />
								) : (
									<XCircle className="w-5 h-5 text-red-400" />
								)}
							</div>
							{isInstalled && version && (
								<div className="text-sm text-zinc-400 mb-2 font-mono">{version}</div>
							)}
							{!isInstalled && (
								<div className="space-y-2">
									<div className="text-xs text-zinc-400 font-mono bg-zinc-900/50 p-2 rounded border border-zinc-800">
										{tool.installCmd}
									</div>
									<button
										type="button"
										onClick={() => handleCopy(tool.name, tool.installCmd)}
										className="w-full flex items-center justify-center gap-2 px-3 py-1.5 text-xs font-medium bg-zinc-800 text-zinc-300 rounded hover:bg-zinc-700 active:scale-95 transition-all"
									>
										{copiedTool === tool.name ? (
											<>
												<Check className="w-3 h-3 text-green-400" />
												<span className="text-green-400">Copied!</span>
											</>
										) : (
											<>
												<Copy className="w-3 h-3" />
												<span>Copy Command</span>
											</>
										)}
									</button>
									{tool.installUrl && (
										<a
											href={tool.installUrl}
											target="_blank"
											rel="noopener noreferrer"
											className="block text-xs text-indigo-400 hover:text-indigo-300 text-center"
										>
											View Docs →
										</a>
									)}
								</div>
							)}
						</motion.div>
					);
				})}
			</div>
		</div>
	);
}
