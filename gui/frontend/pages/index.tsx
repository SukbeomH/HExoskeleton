/**
 * 메인 페이지 - Injector
 * Cybernetic Minimalism Theme
 */

import { useState } from "react";
import { motion } from "framer-motion";
import Layout from "@/components/Layout";
import InjectorStep from "@/components/InjectorStep";
import type { StackInfo, PostDiagnosis } from "@/lib/types";

export default function Home() {
	const [stackInfo, setStackInfo] = useState<StackInfo | null>(null);
	const [diagnosis, setDiagnosis] = useState<PostDiagnosis | null>(null);

	return (
		<Layout stackInfo={stackInfo} diagnosis={diagnosis}>
			<div className="min-h-screen">
				<div className="max-w-7xl mx-auto px-4 md:px-6 py-8">
					<div className="grid gap-6 md:grid-cols-1 lg:grid-cols-3">
						{/* 메인 인젝터 카드 */}
						<div className="lg:col-span-2">
							<motion.div
								initial={{ opacity: 0, scale: 0.95 }}
								animate={{ opacity: 1, scale: 1 }}
								transition={{ delay: 0.1 }}
								className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-6 backdrop-blur-sm cyber-glow"
							>
								<InjectorStep
									onStackDetected={setStackInfo}
									onDiagnosisUpdate={setDiagnosis}
								/>
							</motion.div>
						</div>

						{/* 사이드바 정보 카드 */}
						<div className="space-y-6">
							<motion.div
								initial={{ opacity: 0, x: 20 }}
								animate={{ opacity: 1, x: 0 }}
								transition={{ delay: 0.2 }}
								className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-6 backdrop-blur-sm"
							>
								<h3 className="mb-4 text-sm font-semibold text-zinc-300">시스템 상태</h3>
								<div className="space-y-3">
									{stackInfo && (
										<div className="text-sm">
											<div className="text-zinc-400">감지된 스택</div>
											<div className="mt-1 font-mono text-indigo-400">
												{stackInfo.stack?.toUpperCase() || "N/A"}
											</div>
										</div>
									)}
								</div>
							</motion.div>
						</div>
					</div>
				</div>
			</div>
		</Layout>
	);
}
