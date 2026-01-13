/**
 * KnowledgeTimeline 컴포넌트
 * CLAUDE.md의 Lessons Learned를 날짜별 타임라인으로 표시
 */

import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { Calendar, BookOpen } from "lucide-react";
import { getClaudeLessons, type LessonItem } from "@/lib/api";

export default function KnowledgeTimeline() {
	const [lessons, setLessons] = useState<LessonItem[]>([]);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState<string | null>(null);

	useEffect(() => {
		const fetchLessons = async () => {
			try {
				setLoading(true);
				const data = await getClaudeLessons();
				setLessons(data.lessons);
			} catch (err: any) {
				setError(err.message || "Failed to load lessons");
			} finally {
				setLoading(false);
			}
		};

		fetchLessons();
	}, []);

	if (loading) {
		return (
			<div className="flex items-center justify-center py-12">
				<div className="text-zinc-400">Loading knowledge timeline...</div>
			</div>
		);
	}

	if (error) {
		return (
			<div className="flex items-center justify-center py-12">
				<div className="text-red-400">Error: {error}</div>
			</div>
		);
	}

	if (lessons.length === 0) {
		return (
			<div className="flex flex-col items-center justify-center py-12 text-center">
				<BookOpen className="w-12 h-12 text-zinc-600 mb-4" />
				<div className="text-zinc-400">No lessons learned yet.</div>
				<div className="text-sm text-zinc-500 mt-2">
					Lessons will appear here as they are added to CLAUDE.md
				</div>
			</div>
		);
	}

	return (
		<div className="space-y-6">
			<div className="flex items-center gap-3 mb-6">
				<BookOpen className="w-6 h-6 text-indigo-400" />
				<h2 className="text-2xl font-bold text-zinc-100">Knowledge Timeline</h2>
			</div>

			{/* 타임라인 */}
			<div className="relative">
				{/* 세로선 */}
				<div className="absolute left-8 top-0 bottom-0 w-0.5 bg-zinc-800" />

				{/* 타임라인 항목 */}
				<div className="space-y-8">
					{lessons.map((lesson, index) => (
						<motion.div
							key={lesson.date}
							initial={{ opacity: 0, x: -20 }}
							animate={{ opacity: 1, x: 0 }}
							transition={{ delay: index * 0.1 }}
							className="relative flex gap-6"
						>
							{/* 날짜 마커 */}
							<div className="relative z-10 flex-shrink-0">
								<div className="w-16 h-16 rounded-full bg-zinc-900 border-2 border-indigo-500 flex items-center justify-center">
									<Calendar className="w-6 h-6 text-indigo-400" />
								</div>
							</div>

							{/* 컨텐츠 카드 */}
							<div className="flex-1 pb-8">
								<motion.div
									layout
									className="rounded-lg border border-zinc-800 bg-zinc-900/50 p-6 backdrop-blur-sm hover:border-indigo-500/50 transition-colors"
								>
									{/* 날짜 헤더 */}
									<div className="flex items-center gap-3 mb-4">
										<span className="text-sm font-semibold text-indigo-400">
											{lesson.date}
										</span>
										<div className="flex-1 h-px bg-zinc-800" />
									</div>

									{/* 제목 */}
									{lesson.title && (
										<h3 className="text-lg font-semibold text-zinc-100 mb-3">
											{lesson.title}
										</h3>
									)}

									{/* 항목 리스트 */}
									{lesson.items.length > 0 ? (
										<ul className="space-y-2">
											{lesson.items.map((item, itemIndex) => (
												<li
													key={itemIndex}
													className="text-sm text-zinc-300 flex items-start gap-2"
												>
													<span className="text-indigo-400 mt-1.5">•</span>
													<span className="flex-1">{item}</span>
												</li>
											))}
										</ul>
									) : (
										<div className="text-sm text-zinc-400 whitespace-pre-wrap">
											{lesson.content}
										</div>
									)}
								</motion.div>
							</div>
						</motion.div>
					))}
				</div>
			</div>
		</div>
	);
}

