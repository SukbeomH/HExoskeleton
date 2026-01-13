/**
 * Knowledge 페이지 - Knowledge Timeline & Tool Reference
 */

import { motion } from "framer-motion";
import Layout from "@/components/Layout";
import KnowledgeTimeline from "@/components/KnowledgeTimeline";
import ToolReference from "@/components/ToolReference";

export default function Knowledge() {
	return (
		<Layout>
			<div className="min-h-screen">
				<div className="max-w-7xl mx-auto px-4 md:px-6 py-8">
					<div className="space-y-8">
						<motion.div
							initial={{ opacity: 0, scale: 0.95 }}
							animate={{ opacity: 1, scale: 1 }}
							transition={{ delay: 0.1, duration: 0.2 }}
							className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-6 backdrop-blur-sm"
						>
							<KnowledgeTimeline />
						</motion.div>
						<motion.div
							initial={{ opacity: 0, scale: 0.95 }}
							animate={{ opacity: 1, scale: 1 }}
							transition={{ delay: 0.2, duration: 0.2 }}
							className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-6 backdrop-blur-sm"
						>
							<ToolReference />
						</motion.div>
					</div>
				</div>
			</div>
		</Layout>
	);
}

