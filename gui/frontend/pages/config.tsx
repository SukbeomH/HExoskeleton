/**
 * Config 페이지 - 설정 편집기
 */

import { motion } from "framer-motion";
import Layout from "@/components/Layout";
import ConfigEditor from "@/components/ConfigEditor";

export default function Config() {
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
						<ConfigEditor />
					</motion.div>
				</div>
			</div>
		</Layout>
	);
}

