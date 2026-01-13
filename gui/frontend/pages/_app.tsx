/**
 * Next.js App 컴포넌트
 * 다크 모드 지원 포함
 */

import type { AppProps } from "next/app";
import { useEffect } from "react";
import ToastProvider from "@/components/ToastProvider";
import "@/styles/globals.css";

export default function App({ Component, pageProps }: AppProps) {
	useEffect(() => {
		// 초기 다크 모드 설정 로드
		const saved = localStorage.getItem("darkMode");
		if (saved === "true") {
			document.documentElement.classList.add("dark");
		} else if (saved === null) {
			// 시스템 설정 확인
			const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
			if (prefersDark) {
				document.documentElement.classList.add("dark");
			}
		}
	}, []);

	return (
		<ToastProvider>
			<Component {...pageProps} />
		</ToastProvider>
	);
}

