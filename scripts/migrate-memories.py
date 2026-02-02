#!/usr/bin/env python3
"""memorygraph → mcp-memory-service 일회성 마이그레이션 스크립트.

기존 memory.db (memorygraph SQLite)에서 메모리를 읽어
mcp-memory-service의 memory_store JSON-RPC로 저장한다.

Usage:
    python3 scripts/migrate-memories.py [--dry-run]
    python3 scripts/migrate-memories.py --source .agent/data/memory-graph/memory.db
"""

import argparse
import json
import os
import sqlite3
import subprocess
import sys
from pathlib import Path


def read_memorygraph_db(db_path: str) -> list[dict]:
    """memorygraph SQLite DB에서 메모리를 읽어 dict 리스트로 반환."""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    # memorygraph의 테이블 구조 탐색
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [row["name"] for row in cursor.fetchall()]
    print(f"[INFO] Tables found: {tables}")

    memories = []

    # memorygraph는 memories 또는 memory 테이블 사용
    memory_table = None
    for candidate in ["memories", "memory", "nodes"]:
        if candidate in tables:
            memory_table = candidate
            break

    if not memory_table:
        print(f"[WARN] No known memory table found in {tables}")
        # 각 테이블의 스키마를 출력하여 디버깅
        for table in tables:
            cursor.execute(f"PRAGMA table_info({table})")
            cols = [(row["name"], row["type"]) for row in cursor.fetchall()]
            print(f"  {table}: {cols}")
            cursor.execute(f"SELECT COUNT(*) as cnt FROM {table}")
            cnt = cursor.fetchone()["cnt"]
            print(f"    rows: {cnt}")
        conn.close()
        return memories

    # 컬럼 목록 확인
    cursor.execute(f"PRAGMA table_info({memory_table})")
    columns = [row["name"] for row in cursor.fetchall()]
    print(f"[INFO] {memory_table} columns: {columns}")

    cursor.execute(f"SELECT * FROM {memory_table}")
    for row in cursor.fetchall():
        memory = {}
        for col in columns:
            memory[col] = row[col]
        # memorygraph nodes 테이블: properties JSON에 실제 데이터 저장
        if "properties" in memory and memory["properties"]:
            try:
                props = json.loads(memory["properties"])
                if isinstance(props, dict):
                    memory.update(props)
            except (json.JSONDecodeError, TypeError):
                pass
        memories.append(memory)

    conn.close()
    return memories


def convert_to_mcp_memory(mem: dict) -> dict:
    """memorygraph 메모리를 mcp-memory-service memory_store arguments로 변환."""
    title = mem.get("title") or mem.get("name") or "Untitled"
    content = mem.get("content") or mem.get("description") or ""
    mem_type = mem.get("type") or "general"

    # tags 처리: JSON 배열 또는 콤마 구분 문자열
    raw_tags = mem.get("tags", "")
    if isinstance(raw_tags, str):
        try:
            tags_list = json.loads(raw_tags)
            if isinstance(tags_list, list):
                tags = ",".join(str(t) for t in tags_list)
            else:
                tags = raw_tags
        except (json.JSONDecodeError, TypeError):
            tags = raw_tags
    elif isinstance(raw_tags, list):
        tags = ",".join(str(t) for t in raw_tags)
    else:
        tags = str(raw_tags) if raw_tags else "migrated"

    if not tags:
        tags = "migrated"

    # 마이그레이션 태그 추가
    if "migrated" not in tags:
        tags = f"{tags},migrated"

    full_content = f"## {title}\n\n{content}"

    return {
        "content": full_content,
        "metadata": {
            "tags": tags,
            "type": mem_type,
        },
    }


def store_via_jsonrpc(arguments: dict, dry_run: bool = False) -> bool:
    """mcp-memory-service에 JSON-RPC로 메모리 저장."""
    if dry_run:
        print(f"  [DRY-RUN] Would store: {arguments['content'][:80]}...")
        return True

    init_msg = json.dumps(
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "migrate-client", "version": "1.0"},
            },
        }
    )
    init_notify = json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"})
    call_msg = json.dumps(
        {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {"name": "memory_store", "arguments": arguments},
        }
    )

    input_data = f"{init_msg}\n{init_notify}\n{call_msg}\n"

    try:
        env = os.environ.copy()
        if not env.get("MCP_MEMORY_SQLITE_PATH"):
            # 프로젝트 기본 경로 설정
            project_dir = Path(__file__).resolve().parent.parent
            env["MCP_MEMORY_SQLITE_PATH"] = str(
                project_dir / ".agent" / "data" / "memory-service" / "memories.db"
            )
        result = subprocess.run(
            ["memory", "server"],
            input=input_data,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
            env=env,
        )
        for line in result.stdout.strip().split("\n"):
            if '"id":2' in line or '"id": 2' in line:
                response = json.loads(line)
                if "result" in response:
                    return True
                print(f"  [ERROR] {response.get('error', 'unknown error')}")
                return False
    except subprocess.TimeoutExpired:
        print("  [ERROR] Timeout")
        return False
    except FileNotFoundError:
        print("  [ERROR] 'memory' command not found. Install: pipx install mcp-memory-service")
        return False
    except Exception as e:
        print(f"  [ERROR] {e}")
        return False

    print("  [WARN] No response with id:2 found")
    return False


def main():
    parser = argparse.ArgumentParser(description="Migrate memorygraph → mcp-memory-service")
    parser.add_argument(
        "--source",
        default=".agent/data/memory-graph/memory.db",
        help="Source memorygraph SQLite DB path",
    )
    parser.add_argument("--dry-run", action="store_true", help="Print without storing")
    parser.add_argument(
        "--target",
        default=".agent/data/memory-service/memories.db",
        help="Target mcp-memory-service DB path",
    )
    args = parser.parse_args()

    db_path = Path(args.source)
    if not db_path.exists():
        print(f"[ERROR] Source DB not found: {db_path}")
        sys.exit(1)

    print(f"[INFO] Reading from: {db_path}")
    memories = read_memorygraph_db(str(db_path))
    print(f"[INFO] Found {len(memories)} memories")

    if not memories:
        print("[INFO] Nothing to migrate")
        return

    success = 0
    fail = 0
    for i, mem in enumerate(memories, 1):
        title = mem.get("title") or mem.get("name") or "Untitled"
        print(f"\n[{i}/{len(memories)}] Migrating: {title}")
        arguments = convert_to_mcp_memory(mem)
        if store_via_jsonrpc(arguments, dry_run=args.dry_run):
            success += 1
            print("  OK")
        else:
            fail += 1
            print("  FAILED")

    print(f"\n[RESULT] Success: {success}, Failed: {fail}, Total: {len(memories)}")


if __name__ == "__main__":
    main()
