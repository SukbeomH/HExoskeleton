/**
 * ToolReference 컴포넌트
 * AI-Native 툴체인 명세 및 설계 의도를 시각화
 */

import { motion } from "framer-motion";
import {
	Wrench,
	Brain,
	FileText,
	Search,
	Edit3,
	ClipboardList,
	Sparkles,
	FileSearch,
	Shield,
	Eye,
	Zap,
	Package,
	Code2,
} from "lucide-react";

interface ToolInfo {
	name: string;
	category: "infra" | "mcp" | "skill" | "control";
	icon: React.ReactNode;
	description: string;
	intention: string;
	badge?: string;
}

const TOOLS: ToolInfo[] = [
	// 코어 인프라
	{
		name: "uv",
		category: "infra",
		icon: <Zap className="w-6 h-6" />,
		description: "Rust로 작성된 초고속 Python 패키지 및 버전 관리자입니다.",
		intention:
			"pyenv, poetry, pip를 하나로 통합하여 환경 구축 시간을 단축하고, AI 에이전트가 의존성 충돌 없이 실행될 수 있는 견고한 기반을 제공합니다.",
		badge: "Core",
	},
	{
		name: "mise",
		category: "infra",
		icon: <Wrench className="w-6 h-6" />,
		description: "프로젝트별 개발 도구(Node, Python, Go 등)와 태스크를 관리합니다.",
		intention:
			"팀원 모두가 동일한 툴체인 버전을 사용하게 강제하며, mise run verify와 같이 표준화된 명령어로 AI와 인간의 협업 접점을 일원화합니다.",
		badge: "Core",
	},
	{
		name: "CLAUDE.md",
		category: "infra",
		icon: <Brain className="w-6 h-6" />,
		description: "프로젝트의 규칙, 안티패턴, 지식을 담은 AI 전용 메모리입니다.",
		intention:
			"세션이 바뀌어도 AI가 프로젝트의 컨텍스트를 잃지 않게 하며, 매 작업의 교훈을 기록하여 '지식의 복리(Compounding Knowledge)'를 실현합니다.",
		badge: "Core",
	},
	// MCP 서버
	{
		name: "Codanna",
		category: "mcp",
		icon: <Search className="w-6 h-6" />,
		description: "시맨틱 검색 및 기호 기반의 사실 분석을 수행합니다.",
		intention:
			"AI가 단순히 코드를 '추측'해서 읽지 않고, 프로젝트 전체의 맥락을 '사실'에 기반하여 정확히 파악하도록 감각 기관을 확장합니다.",
		badge: "MCP",
	},
	{
		name: "Serena",
		category: "mcp",
		icon: <Edit3 className="w-6 h-6" />,
		description: "코드의 심볼(함수, 클래스 등) 단위를 정밀하게 수정합니다.",
		intention:
			"전체 파일을 덮어쓰는 위험한 방식 대신, IDE 수준의 정밀도로 필요한 부분만 수정(Surgical Precision)하여 코드 파괴를 방지합니다.",
		badge: "MCP",
	},
	{
		name: "Shrimp",
		category: "mcp",
		icon: <ClipboardList className="w-6 h-6" />,
		description: "구조화된 작업 관리 및 계획 수립을 담당합니다.",
		intention:
			"AI가 무작정 코딩을 시작하지 않고, PLAN 단계에서 명확한 할 일 목록을 작성하고 인간의 승인을 받도록 워크플로우를 통제합니다.",
		badge: "MCP",
	},
	// 검증 에이전트
	{
		name: "simplifier",
		category: "skill",
		icon: <Sparkles className="w-6 h-6" />,
		description: "코드의 인지적 복잡도를 측정하고 리팩토링을 제안합니다.",
		intention:
			"코드가 동작하는 것을 넘어, 인간과 AI 모두가 이해하기 쉬운 '간결함'을 유지하여 장기적인 유지보수 비용을 낮춥니다.",
		badge: "Skill",
	},
	{
		name: "log-analyzer",
		category: "skill",
		icon: <FileSearch className="w-6 h-6" />,
		description: "로컬 app.log를 분석하여 런타임 에러를 진단합니다.",
		intention:
			"외부 서비스(Sentry 등) 의존 없이 로컬 개발 단계에서 에러의 근본 원인을 AI가 즉시 파악하고 자가 치유(Self-Healing)를 시도하게 합니다.",
		badge: "Skill",
	},
	{
		name: "security-audit",
		category: "skill",
		icon: <Shield className="w-6 h-6" />,
		description: "패키지 취약점을 실시간으로 모니터링합니다.",
		intention:
			"개발 초기 단계부터 보안 가드레일을 적용하여 취약한 라이브러리가 프로덕션에 유입되는 것을 원천 차단합니다.",
		badge: "Skill",
	},
	{
		name: "visual-verifier",
		category: "skill",
		icon: <Eye className="w-6 h-6" />,
		description: "웹 프로젝트의 UI 렌더링과 콘솔 에러를 확인합니다.",
		intention:
			"단순 유닛 테스트를 넘어 브라우저를 직접 열고 UI가 깨지지 않았는지, 네트워크 로그에 에러가 없는지 확인합니다.",
		badge: "Skill",
	},
	// 제어 평면
	{
		name: "Control Plane GUI",
		category: "control",
		icon: <Code2 className="w-6 h-6" />,
		description: "FastAPI와 Next.js로 구축된 통합 대시보드로, 보일러플레이트 주입 및 에이전트 활동을 모니터링합니다.",
		intention:
			"명령줄 환경(CLI)에 익숙하지 않은 사용자도 AI-Native 워크플로우에 쉽게 적응하게 하며, AI의 내부 작동 과정을 시각화하여 투명성과 신뢰성을 확보합니다.",
		badge: "GUI",
	},
];

const CATEGORY_LABELS = {
	infra: "코어 인프라",
	mcp: "AI 지능 및 정밀 편집 (MCP)",
	skill: "검증 에이전트 및 스킬",
	control: "제어 평면",
};

const CATEGORY_COLORS = {
	infra: "indigo",
	mcp: "purple",
	skill: "green",
	control: "blue",
};

export default function ToolReference() {
	const categories = ["infra", "mcp", "skill", "control"] as const;

	return (
		<div className="space-y-8">
			<div className="text-center mb-8">
				<h2 className="text-3xl font-bold text-zinc-100 mb-2">AI-Native 툴체인 명세</h2>
				<p className="text-zinc-400">
					도구 간의 유기적인 결합을 통해 <strong className="text-zinc-200">추측을 배제하고 사실에 기반한 개발</strong>을 지향합니다.
				</p>
			</div>

			{categories.map((category) => {
				const categoryTools = TOOLS.filter((tool) => tool.category === category);
				const color = CATEGORY_COLORS[category];

				return (
					<div key={category} className="space-y-4">
						<h3 className="text-xl font-semibold text-zinc-100 flex items-center gap-2">
							<span
								className={`px-3 py-1 rounded text-sm font-medium ${
									color === "indigo"
										? "bg-indigo-500/20 text-indigo-400 border border-indigo-500/30"
										: color === "purple"
										? "bg-purple-500/20 text-purple-400 border border-purple-500/30"
										: color === "green"
										? "bg-green-500/20 text-green-400 border border-green-500/30"
										: "bg-blue-500/20 text-blue-400 border border-blue-500/30"
								}`}
							>
								{CATEGORY_LABELS[category]}
							</span>
						</h3>

						<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
							{categoryTools.map((tool, index) => (
								<motion.div
									key={tool.name}
									initial={{ opacity: 0, y: 20 }}
									animate={{ opacity: 1, y: 0 }}
									transition={{ delay: index * 0.1 }}
									className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-6 backdrop-blur-sm hover:border-indigo-500/50 transition-colors"
								>
									{/* 헤더 */}
									<div className="flex items-start justify-between mb-4">
										<div className="flex items-center gap-3">
											<div
												className={`p-2 rounded-lg ${
													color === "indigo"
														? "bg-indigo-500/20 text-indigo-400"
														: color === "purple"
														? "bg-purple-500/20 text-purple-400"
														: color === "green"
														? "bg-green-500/20 text-green-400"
														: "bg-blue-500/20 text-blue-400"
												}`}
											>
												{tool.icon}
											</div>
											<div>
												<h4 className="font-semibold text-zinc-100">{tool.name}</h4>
												{tool.badge && (
													<span
														className={`text-xs px-2 py-0.5 rounded ${
															color === "indigo"
																? "bg-indigo-500/10 text-indigo-400"
																: color === "purple"
																? "bg-purple-500/10 text-purple-400"
																: color === "green"
																? "bg-green-500/10 text-green-400"
																: "bg-blue-500/10 text-blue-400"
														}`}
													>
														{tool.badge}
													</span>
												)}
											</div>
										</div>
									</div>

									{/* 설명 */}
									<div className="space-y-3">
										<div>
											<div className="text-xs font-semibold text-zinc-400 mb-1">What</div>
											<p className="text-sm text-zinc-300">{tool.description}</p>
										</div>
										<div className="border-t border-zinc-800 pt-3">
											<div className="text-xs font-semibold text-indigo-400 mb-1">Why (설계 의도)</div>
											<p className="text-sm text-zinc-400 leading-relaxed">{tool.intention}</p>
										</div>
									</div>
								</motion.div>
							))}
						</div>
					</div>
				);
			})}
		</div>
	);
}
