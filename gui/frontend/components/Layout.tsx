/**
 * Layout 컴포넌트
 * Cybernetic Minimalism 테마의 메인 레이아웃
 */

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/router";
import { motion } from "framer-motion";
import { Zap, Brain, FileText, BookOpen, Menu, X, Settings } from "lucide-react";
import StatusBadge from "./StatusBadge";
import ThemeToggle from "./ThemeToggle";
import type { StackInfo, PostDiagnosis } from "@/lib/types";

interface LayoutProps {
	children: React.ReactNode;
	stackInfo?: StackInfo | null;
	diagnosis?: PostDiagnosis | null;
}

const navigation = [
	{ name: "Injector", href: "/", icon: Zap },
	{ name: "Skills", href: "/skills", icon: Brain },
	{ name: "Logs", href: "/logs", icon: FileText },
	{ name: "Config", href: "/config", icon: Settings },
	{ name: "Knowledge", href: "/knowledge", icon: BookOpen },
];

export default function Layout({ children, stackInfo = null, diagnosis = null }: LayoutProps) {
	const router = useRouter();
	const [sidebarOpen, setSidebarOpen] = useState(false);

	const isActive = (href: string) => {
		if (href === "/") {
			return router.pathname === "/";
		}
		return router.pathname.startsWith(href);
	};

	return (
		<div className="min-h-screen bg-zinc-950 text-zinc-100">
			{/* 사이드바 (데스크톱) */}
			<aside className="hidden md:fixed md:inset-y-0 md:left-0 md:w-20 md:flex md:flex-col md:items-center md:border-r md:border-zinc-800 md:bg-zinc-900/50">
				<div className="flex h-16 w-full items-center justify-center border-b border-zinc-800">
					<div className="flex h-10 w-10 items-center justify-center rounded-lg bg-indigo-500/10">
						<Zap className="h-6 w-6 text-indigo-500" />
					</div>
				</div>
				<nav className="flex-1 w-full py-4 space-y-2">
					{navigation.map((item) => {
						const Icon = item.icon;
						const active = isActive(item.href);
						return (
							<Link
								key={item.name}
								href={item.href}
								className={`group relative flex flex-col items-center justify-center h-16 w-full transition-colors ${
									active
										? "text-indigo-400 bg-indigo-500/10 border-l-2 border-indigo-500"
										: "text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/50"
								}`}
							>
								<Icon className="h-5 w-5 mb-1" />
								<span className="text-xs font-medium">{item.name}</span>
								{active && (
									<motion.div
										layoutId="activeIndicator"
										className="absolute left-0 top-0 bottom-0 w-0.5 bg-indigo-500"
										initial={false}
										transition={{ type: "spring", stiffness: 500, damping: 30 }}
									/>
								)}
							</Link>
						);
					})}
				</nav>
			</aside>

			{/* 모바일 사이드바 오버레이 */}
			{sidebarOpen && (
				<motion.div
					initial={{ opacity: 0 }}
					animate={{ opacity: 1 }}
					exit={{ opacity: 0 }}
					onClick={() => setSidebarOpen(false)}
					className="fixed inset-0 z-40 bg-zinc-950/80 backdrop-blur-sm md:hidden"
				/>
			)}

			{/* 모바일 사이드바 */}
			<motion.aside
				initial={{ x: -280 }}
				animate={{ x: sidebarOpen ? 0 : -280 }}
				transition={{ type: "spring", damping: 25, stiffness: 200 }}
				className="fixed inset-y-0 left-0 z-50 w-70 bg-zinc-900 border-r border-zinc-800 md:hidden"
				style={{ width: "280px" }}
			>
				<div className="flex h-16 items-center justify-between px-4 border-b border-zinc-800">
					<div className="flex items-center gap-2">
						<div className="flex h-10 w-10 items-center justify-center rounded-lg bg-indigo-500/10">
							<Zap className="h-6 w-6 text-indigo-500" />
						</div>
						<span className="text-sm font-semibold">Control Plane</span>
					</div>
					<button
						onClick={() => setSidebarOpen(false)}
						className="p-2 rounded-lg hover:bg-zinc-800"
					>
						<X className="h-5 w-5" />
					</button>
				</div>
				<nav className="py-4 space-y-1">
					{navigation.map((item) => {
						const Icon = item.icon;
						const active = isActive(item.href);
						return (
							<Link
								key={item.name}
								href={item.href}
								onClick={() => setSidebarOpen(false)}
								className={`flex items-center gap-3 px-4 py-3 mx-2 rounded-lg transition-colors ${
									active
										? "text-indigo-400 bg-indigo-500/10"
										: "text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/50"
								}`}
							>
								<Icon className="h-5 w-5" />
								<span className="font-medium">{item.name}</span>
							</Link>
						);
					})}
				</nav>
			</motion.aside>

			{/* 메인 컨텐츠 영역 */}
			<div className="md:pl-20">
				{/* 헤더 */}
				<header className="sticky top-0 z-30 border-b border-zinc-800 bg-zinc-950/80 backdrop-blur-sm">
					<div className="flex h-16 items-center justify-between px-4 md:px-6">
						<button
							onClick={() => setSidebarOpen(true)}
							className="p-2 rounded-lg hover:bg-zinc-800 md:hidden"
						>
							<Menu className="h-5 w-5" />
						</button>
						<h1 className="text-lg font-semibold md:text-xl">AI-Native Control Plane</h1>
						<div className="flex items-center gap-4">
							<StatusBadge stackInfo={stackInfo} diagnosis={diagnosis} />
							<ThemeToggle />
						</div>
					</div>
				</header>

				{/* 페이지 컨텐츠 */}
				<main className="relative">
					{/* 배경 효과 */}
					<div className="fixed inset-0 -z-10 cyber-noise cyber-glow" />
					<div className="absolute inset-0 bg-gradient-to-br from-indigo-500/5 via-transparent to-transparent pointer-events-none" />
					{children}
				</main>
			</div>
		</div>
	);
}

