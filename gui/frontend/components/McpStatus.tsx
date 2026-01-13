/**
 * McpStatus 컴포넌트
 * MCP 서버 헬스체크 대시보드 - 각 MCP 서버의 온라인/오프라인 상태 표시
 */

import { useState } from "react";
import { motion } from "framer-motion";
import { CheckCircle2, XCircle, AlertCircle, Loader2, Copy, Check } from "lucide-react";
import { useToast } from "./ToastProvider";

interface McpServer {
	name: string;
	displayName: string;
	description: string;
	status: "online" | "offline" | "checking" | "unknown";
	category: "core" | "domain" | "optional";
	command?: string; // Cursor 설정용 명령어
	args?: string[]; // 명령어 인자
}

interface McpStatusProps {
	servers?: McpServer[];
}

const defaultServers: McpServer[] = [
	{
		name: "serena",
		displayName: "Serena",
		description: "심볼 기반 검색 및 정밀 편집 (필수)",
		status: "unknown",
		category: "core",
		command: "npx",
		args: ["-y", "@modelcontextprotocol/server-serena"],
	},
	{
		name: "codanna",
		displayName: "Codanna",
		description: "시맨틱 검색 및 사실 기반 분석 (필수)",
		status: "unknown",
		category: "core",
		command: "npx",
		args: ["-y", "@modelcontextprotocol/server-codanna"],
	},
	{
		name: "shrimp-task-manager",
		displayName: "Shrimp Task Manager",
		description: "구조화된 작업 관리 및 지속적 메모리 (필수)",
		status: "unknown",
		category: "core",
		command: "npx",
		args: ["-y", "@modelcontextprotocol/server-shrimp-task-manager"],
	},
	{
		name: "context7",
		displayName: "Context7",
		description: "대규모 코드베이스 컨텍스트 최적화 (권장)",
		status: "unknown",
		category: "core",
		command: "npx",
		args: ["-y", "@modelcontextprotocol/server-context7"],
	},
	{
		name: "chrome-devtools",
		displayName: "Chrome DevTools",
		description: "브라우저 UI 검증 및 콘솔 에러 확인 (웹 프로젝트)",
		status: "unknown",
		category: "domain",
		command: "npx",
		args: ["-y", "@modelcontextprotocol/server-chrome-devtools"],
	},
	{
		name: "proxymock",
		displayName: "Proxymock",
		description: "실제 운영 트래픽 재현 및 API 검증 (API 프로젝트)",
		status: "unknown",
		category: "domain",
		command: "npx",
		args: ["-y", "@modelcontextprotocol/server-proxymock"],
	},
	{
		name: "playwright",
		displayName: "Playwright",
		description: "자동화된 E2E 테스트 실행 (선택)",
		status: "unknown",
		category: "optional",
		command: "npx",
		args: ["-y", "@modelcontextprotocol/server-playwright"],
	},
];

export default function McpStatus({ servers = defaultServers }: McpStatusProps) {
	const { showToast } = useToast();
	const [copiedServer, setCopiedServer] = useState<string | null>(null);

	const handleCopyForCursor = async (server: McpServer) => {
		if (!server.command || !server.args) {
			showToast("이 서버의 설정 정보가 없습니다.", "error");
			return;
		}

		// args가 배열인지 확인
		if (!Array.isArray(server.args)) {
			showToast("서버 설정의 args가 유효한 배열이 아닙니다.", "error");
			return;
		}

		// 명령어 형식 변환: mise x -- 형식으로 변환
		let command: string;
		if (server.name === "serena") {
			// Serena는 uvx 사용
			const packageName = server.args.length > 0
				? server.args[server.args.length - 1]
				: "@modelcontextprotocol/server-serena";
			command = `uvx ${packageName}`;
		} else if (server.command === "npx") {
			// npx 서버는 mise x -- npx -y 형식
			const args = server.args.includes("-y") ? server.args : ["-y", ...server.args];
			command = `mise x -- npx ${args.join(" ")}`;
		} else {
			// 기타 명령어는 mise x -- 형식
			const args = server.args.length > 0 ? ` ${server.args.join(" ")}` : "";
			command = `mise x -- ${server.command}${args}`;
		}

		const cursorConfig = `Name: ${server.displayName}\nType: command\nCommand: ${command}`;

		try {
			await navigator.clipboard.writeText(cursorConfig);
			setCopiedServer(server.name);
			showToast(`${server.displayName} 설정이 클립보드에 복사되었습니다`, "success");
			setTimeout(() => setCopiedServer(null), 2000);
		} catch (error) {
			showToast("복사에 실패했습니다", "error");
		}
	};

	const getStatusIcon = (status: McpServer["status"]) => {
		switch (status) {
			case "online":
				return <CheckCircle2 className="h-5 w-5 text-green-400" />;
			case "offline":
				return <XCircle className="h-5 w-5 text-red-400" />;
			case "checking":
				return <Loader2 className="h-5 w-5 text-yellow-400 animate-spin" />;
			default:
				return <AlertCircle className="h-5 w-5 text-zinc-500" />;
		}
	};

	const getStatusColor = (status: McpServer["status"]) => {
		switch (status) {
			case "online":
				return "border-green-500/30 bg-green-500/10";
			case "offline":
				return "border-red-500/30 bg-red-500/10";
			case "checking":
				return "border-yellow-500/30 bg-yellow-500/10";
			default:
				return "border-zinc-800 bg-zinc-900/30";
		}
	};

	const getCategoryBadge = (category: McpServer["category"]) => {
		const badges = {
			core: { label: "필수", color: "bg-indigo-500/20 text-indigo-400 border-indigo-500/30" },
			domain: { label: "도메인", color: "bg-purple-500/20 text-purple-400 border-purple-500/30" },
			optional: { label: "선택", color: "bg-zinc-500/20 text-zinc-400 border-zinc-500/30" },
		};
		const badge = badges[category];
		return (
			<span className={`px-2 py-0.5 text-xs rounded border ${badge.color}`}>{badge.label}</span>
		);
	};

	const coreServers = servers.filter((s) => s.category === "core");
	const domainServers = servers.filter((s) => s.category === "domain");
	const optionalServers = servers.filter((s) => s.category === "optional");

	return (
		<div className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-6 backdrop-blur-sm">
			<div className="mb-6">
				<h3 className="text-lg font-semibold text-zinc-100 mb-2">MCP 서버 상태</h3>
				<p className="text-sm text-zinc-400">
					각 MCP 서버의 활성화 상태를 확인하고 필요에 따라 활성화하세요.
				</p>
			</div>

			{/* 필수 MCP 서버 */}
			{coreServers.length > 0 && (
				<div className="mb-6">
					<h4 className="text-sm font-semibold text-zinc-300 mb-3">필수 MCP 서버</h4>
					<div className="space-y-2">
						{coreServers.map((server, index) => (
							<motion.div
								key={server.name}
								initial={{ opacity: 0, y: 10 }}
								animate={{ opacity: 1, y: 0 }}
								transition={{ duration: 0.2, delay: index * 0.05 }}
								className={`flex items-center gap-4 rounded-lg border p-3 transition-colors ${getStatusColor(server.status)}`}
							>
								<div className="flex-shrink-0">{getStatusIcon(server.status)}</div>
								<div className="flex-1 min-w-0">
									<div className="flex items-center gap-2 mb-1">
										<span className="font-medium text-zinc-100">{server.displayName}</span>
										{getCategoryBadge(server.category)}
									</div>
									<div className="text-xs text-zinc-400">{server.description}</div>
								</div>
								{server.command && server.args && (
									<button
										onClick={() => handleCopyForCursor(server)}
										className={`flex items-center gap-1.5 px-2.5 py-1.5 rounded text-xs font-medium transition-all ${
											copiedServer === server.name
												? "bg-green-500/10 text-green-400 border border-green-500/30"
												: "bg-indigo-500/10 text-indigo-400 border border-indigo-500/30 hover:bg-indigo-500/20 active:scale-95"
										}`}
									>
										{copiedServer === server.name ? (
											<>
												<Check className="h-3.5 w-3.5" />
												<span>복사됨</span>
											</>
										) : (
											<>
												<Copy className="h-3.5 w-3.5" />
												<span>Copy for Cursor</span>
											</>
										)}
									</button>
								)}
							</motion.div>
						))}
					</div>
				</div>
			)}

			{/* 도메인별 MCP 서버 */}
			{domainServers.length > 0 && (
				<div className="mb-6">
					<h4 className="text-sm font-semibold text-zinc-300 mb-3">도메인별 MCP 서버</h4>
					<div className="space-y-2">
						{domainServers.map((server, index) => (
							<motion.div
								key={server.name}
								initial={{ opacity: 0, y: 10 }}
								animate={{ opacity: 1, y: 0 }}
								transition={{ duration: 0.2, delay: index * 0.05 }}
								className={`flex items-center gap-4 rounded-lg border p-3 transition-colors ${getStatusColor(server.status)}`}
							>
								<div className="flex-shrink-0">{getStatusIcon(server.status)}</div>
								<div className="flex-1 min-w-0">
									<div className="flex items-center gap-2 mb-1">
										<span className="font-medium text-zinc-100">{server.displayName}</span>
										{getCategoryBadge(server.category)}
									</div>
									<div className="text-xs text-zinc-400">{server.description}</div>
								</div>
								{server.command && server.args && (
									<button
										onClick={() => handleCopyForCursor(server)}
										className={`flex items-center gap-1.5 px-2.5 py-1.5 rounded text-xs font-medium transition-all ${
											copiedServer === server.name
												? "bg-green-500/10 text-green-400 border border-green-500/30"
												: "bg-indigo-500/10 text-indigo-400 border border-indigo-500/30 hover:bg-indigo-500/20 active:scale-95"
										}`}
									>
										{copiedServer === server.name ? (
											<>
												<Check className="h-3.5 w-3.5" />
												<span>복사됨</span>
											</>
										) : (
											<>
												<Copy className="h-3.5 w-3.5" />
												<span>Copy for Cursor</span>
											</>
										)}
									</button>
								)}
							</motion.div>
						))}
					</div>
				</div>
			)}

			{/* 선택적 MCP 서버 */}
			{optionalServers.length > 0 && (
				<div>
					<h4 className="text-sm font-semibold text-zinc-300 mb-3">선택적 MCP 서버</h4>
					<div className="space-y-2">
						{optionalServers.map((server, index) => (
							<motion.div
								key={server.name}
								initial={{ opacity: 0, y: 10 }}
								animate={{ opacity: 1, y: 0 }}
								transition={{ duration: 0.2, delay: index * 0.05 }}
								className={`flex items-center gap-4 rounded-lg border p-3 transition-colors ${getStatusColor(server.status)}`}
							>
								<div className="flex-shrink-0">{getStatusIcon(server.status)}</div>
								<div className="flex-1 min-w-0">
									<div className="flex items-center gap-2 mb-1">
										<span className="font-medium text-zinc-100">{server.displayName}</span>
										{getCategoryBadge(server.category)}
									</div>
									<div className="text-xs text-zinc-400">{server.description}</div>
								</div>
								{server.command && server.args && (
									<button
										onClick={() => handleCopyForCursor(server)}
										className={`flex items-center gap-1.5 px-2.5 py-1.5 rounded text-xs font-medium transition-all ${
											copiedServer === server.name
												? "bg-green-500/10 text-green-400 border border-green-500/30"
												: "bg-indigo-500/10 text-indigo-400 border border-indigo-500/30 hover:bg-indigo-500/20 active:scale-95"
										}`}
									>
										{copiedServer === server.name ? (
											<>
												<Check className="h-3.5 w-3.5" />
												<span>복사됨</span>
											</>
										) : (
											<>
												<Copy className="h-3.5 w-3.5" />
												<span>Copy for Cursor</span>
											</>
										)}
									</button>
								)}
							</motion.div>
						))}
					</div>
				</div>
			)}

			<div className="mt-6 pt-4 border-t border-zinc-800">
				<p className="text-xs text-zinc-500">
					💡 MCP 서버 상태는 AI가 프롬프트를 받은 후 자동으로 확인합니다. `.mcp.json` 설정을 확인하세요.
				</p>
			</div>
		</div>
	);
}

