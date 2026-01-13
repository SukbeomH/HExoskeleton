/**
 * ToastProvider 컴포넌트
 * Toast 상태 관리 Context 및 Provider
 */

import { createContext, useContext, useState, useCallback, ReactNode } from "react";
import Toast, { ToastType } from "./Toast";

interface ToastState {
	message: string;
	type: ToastType;
	id: number;
}

interface ToastContextType {
	showToast: (message: string, type?: ToastType, duration?: number) => void;
}

const ToastContext = createContext<ToastContextType | undefined>(undefined);

export function useToast() {
	const context = useContext(ToastContext);
	if (!context) {
		throw new Error("useToast must be used within ToastProvider");
	}
	return context;
}

interface ToastProviderProps {
	children: ReactNode;
}

export default function ToastProvider({ children }: ToastProviderProps) {
	const [toasts, setToasts] = useState<ToastState[]>([]);

	const showToast = useCallback((message: string, type: ToastType = "info", duration = 3000) => {
		const id = Date.now();
		setToasts((prev) => [...prev, { message, type, id }]);

		// 자동 제거
		if (duration > 0) {
			setTimeout(() => {
				setToasts((prev) => prev.filter((toast) => toast.id !== id));
			}, duration);
		}
	}, []);

	const removeToast = useCallback((id: number) => {
		setToasts((prev) => prev.filter((toast) => toast.id !== id));
	}, []);

	return (
		<ToastContext.Provider value={{ showToast }}>
			{children}
			<div className="fixed bottom-4 left-1/2 -translate-x-1/2 z-50 flex flex-col gap-2 items-center pointer-events-none">
				{toasts.map((toast) => (
					<div key={toast.id} className="pointer-events-auto">
						<Toast
							message={toast.message}
							type={toast.type}
							duration={0}
							onClose={() => removeToast(toast.id)}
						/>
					</div>
				))}
			</div>
		</ToastContext.Provider>
	);
}

