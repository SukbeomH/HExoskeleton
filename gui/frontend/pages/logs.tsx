/**
 * Logs 페이지 - Log Monitor
 */

import { motion } from "framer-motion";
import Layout from "@/components/Layout";
import LogMonitor from "@/components/LogMonitor";

export default function Logs() {
	return (
		<Layout>
			<div className="min-h-screen">
				<div className="max-w-7xl mx-auto px-4 md:px-6 py-8">
					<motion.div
						initial={{ opacity: 0, scale: 0.95 }}
						animate={{ opacity: 1, scale: 1 }}
						transition={{ duration: 0.2 }}
						className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-6 backdrop-blur-sm"
					>
						<LogMonitor />
					</motion.div>
				</div>
			</div>
		</Layout>
	);
}

