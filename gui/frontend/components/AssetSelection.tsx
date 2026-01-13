/**
 * AssetSelection 컴포넌트
 * 자산 선택 UI - Cybernetic Minimalism Theme
 */

import { useState, useEffect } from "react";
import { ASSETS, type AssetType } from "@/lib/types";

interface AssetSelectionProps {
	onSelectionChange: (selectedAssets: string[]) => void;
}

export default function AssetSelection({ onSelectionChange }: AssetSelectionProps) {
	const [selected, setSelected] = useState<Set<AssetType>>(
		new Set(ASSETS.filter((a) => a.required).map((a) => a.id)),
	);

	useEffect(() => {
		onSelectionChange(Array.from(selected));
	}, [selected, onSelectionChange]);

	const handleToggle = (assetId: AssetType) => {
		const asset = ASSETS.find((a) => a.id === assetId);
		if (asset?.required) {
			return; // 필수 항목은 선택 해제 불가
		}

		setSelected((prev) => {
			const next = new Set(prev);
			if (next.has(assetId)) {
				next.delete(assetId);
			} else {
				next.add(assetId);
			}
			return next;
		});
	};

	const handleSelectAll = () => {
		setSelected(new Set(ASSETS.map((a) => a.id)));
	};

	const handleDeselectAll = () => {
		setSelected(new Set(ASSETS.filter((a) => a.required).map((a) => a.id)));
	};

	return (
		<div className="mb-8">
			<div className="mb-4 flex items-center justify-between">
				<h2 className="text-2xl font-bold text-zinc-100">주입할 자산 선택</h2>
				<div className="flex gap-2">
					<button
						onClick={handleSelectAll}
						className="rounded-lg border border-zinc-700 bg-zinc-800 px-3 py-1 text-sm text-zinc-300 transition-colors hover:bg-zinc-700 active:scale-95"
					>
						전체 선택
					</button>
					<button
						onClick={handleDeselectAll}
						className="rounded-lg border border-zinc-700 bg-zinc-800 px-3 py-1 text-sm text-zinc-300 transition-colors hover:bg-zinc-700 active:scale-95"
					>
						필수만 선택
					</button>
				</div>
			</div>

			<div className="flex flex-col gap-3">
				{ASSETS.map((asset) => (
					<label
						key={asset.id}
						className={`flex cursor-pointer items-start rounded-lg border p-4 transition-colors ${
							selected.has(asset.id)
								? "border-indigo-500/50 bg-indigo-500/10"
								: "border-zinc-800 bg-zinc-900/30"
						} ${asset.required ? "cursor-default" : ""}`}
					>
						<input
							type="checkbox"
							checked={selected.has(asset.id)}
							onChange={() => handleToggle(asset.id)}
							disabled={asset.required}
							className="mr-3 mt-1 h-4 w-4 rounded border-zinc-700 bg-zinc-800 text-indigo-500 focus:ring-2 focus:ring-indigo-500 disabled:opacity-50"
						/>
						<div className="flex-1">
							<div className="mb-1 font-semibold text-zinc-100">
								{asset.label}
								{asset.required && (
									<span className="ml-2 text-sm text-red-400">(필수)</span>
								)}
							</div>
							<div className="text-sm text-zinc-400">{asset.description}</div>
						</div>
					</label>
				))}
			</div>
		</div>
	);
}
