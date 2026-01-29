#!/usr/bin/env python3
"""
update_prd.py - PRD Task State Manager

작업 완료 시 prd-active.json → prd-done.json 이동을 처리합니다.

사용법:
    # 단일 task 완료
    python update_prd.py complete TASK-001

    # 단일 task 완료 (커밋 해시 포함)
    python update_prd.py complete TASK-001 --commit abc1234

    # plan 기반으로 task 완료 (phase.plan.task 형식)
    python update_prd.py complete-plan 1.2.1 --commit abc1234

    # 새 task 추가 (prd-active.json에)
    python update_prd.py add --title "구현할 기능" --phase 1 --wave 1

    # 현재 상태 확인
    python update_prd.py status

출력: JSON 형식
"""

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def get_gsd_path() -> Path:
    """Find .gsd directory."""
    cwd = Path.cwd()

    # Check current directory
    if (cwd / ".gsd").is_dir():
        return cwd / ".gsd"

    # Check parent directories
    for parent in cwd.parents:
        if (parent / ".gsd").is_dir():
            return parent / ".gsd"

    # Fallback to current directory
    return cwd / ".gsd"


def load_json(path: Path) -> dict[str, Any]:
    """Load JSON file, return empty structure if not exists."""
    if not path.exists():
        return {"$schema": "prd-schema", "version": "1.0.0", "tasks": []}
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save_json(path: Path, data: dict[str, Any]) -> None:
    """Save JSON file with updated timestamp."""
    data["updated"] = datetime.now(timezone.utc).isoformat()
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def find_task_by_id(tasks: list[dict], task_id: str) -> tuple[int, dict | None]:
    """Find task by ID, return (index, task) or (-1, None)."""
    for i, task in enumerate(tasks):
        if task.get("id") == task_id:
            return i, task
    return -1, None


def find_task_by_plan(
    tasks: list[dict], phase: int, plan: int, task_num: int
) -> tuple[int, dict | None]:
    """Find task by phase.plan.task number."""
    for i, task in enumerate(tasks):
        if (
            task.get("phase") == phase
            and task.get("plan") == plan
            and task.get("task_num") == task_num
        ):
            return i, task
    return -1, None


def generate_task_id(tasks: list[dict]) -> str:
    """Generate next task ID."""
    max_num = 0
    for task in tasks:
        tid = task.get("id", "")
        if tid.startswith("TASK-"):
            try:
                num = int(tid.split("-")[1])
                max_num = max(max_num, num)
            except (IndexError, ValueError):
                pass
    return f"TASK-{max_num + 1:03d}"


def cmd_complete(args: argparse.Namespace) -> dict[str, Any]:
    """Complete a task: move from active to done."""
    gsd = get_gsd_path()
    active_path = gsd / "prd-active.json"
    done_path = gsd / "prd-done.json"

    active = load_json(active_path)
    done = load_json(done_path)

    # Find task
    idx, task = find_task_by_id(active["tasks"], args.task_id)

    if task is None:
        return {
            "success": False,
            "error": f"Task {args.task_id} not found in prd-active.json",
            "hint": "Use 'update_prd.py status' to see active tasks",
        }

    # Update task
    task["status"] = "done"
    task["completed"] = datetime.now(timezone.utc).isoformat()
    if args.commit:
        task["commit"] = args.commit
    if args.summary:
        task["summary"] = args.summary

    # Move to done
    active["tasks"].pop(idx)
    done["tasks"].append(task)

    # Save
    save_json(active_path, active)
    save_json(done_path, done)

    return {
        "success": True,
        "action": "completed",
        "task": task,
        "remaining": len(active["tasks"]),
    }


def cmd_complete_plan(args: argparse.Namespace) -> dict[str, Any]:
    """Complete a task by plan reference (phase.plan.task)."""
    gsd = get_gsd_path()
    active_path = gsd / "prd-active.json"
    done_path = gsd / "prd-done.json"

    # Parse plan reference
    parts = args.plan_ref.split(".")
    if len(parts) != 3:
        return {
            "success": False,
            "error": f"Invalid plan reference: {args.plan_ref}",
            "hint": "Use format: phase.plan.task (e.g., 1.2.1)",
        }

    try:
        phase, plan, task_num = int(parts[0]), int(parts[1]), int(parts[2])
    except ValueError:
        return {
            "success": False,
            "error": f"Invalid plan reference: {args.plan_ref}",
            "hint": "All parts must be integers",
        }

    active = load_json(active_path)
    done = load_json(done_path)

    # Find task
    idx, task = find_task_by_plan(active["tasks"], phase, plan, task_num)

    if task is None:
        return {
            "success": False,
            "error": f"Task for plan {args.plan_ref} not found",
            "hint": "Task must have matching phase, plan, and task_num fields",
        }

    # Update task
    task["status"] = "done"
    task["completed"] = datetime.now(timezone.utc).isoformat()
    if args.commit:
        task["commit"] = args.commit
    if args.summary:
        task["summary"] = args.summary

    # Move to done
    active["tasks"].pop(idx)
    done["tasks"].append(task)

    # Save
    save_json(active_path, active)
    save_json(done_path, done)

    return {
        "success": True,
        "action": "completed",
        "plan_ref": args.plan_ref,
        "task": task,
        "remaining": len(active["tasks"]),
    }


def cmd_add(args: argparse.Namespace) -> dict[str, Any]:
    """Add a new task to prd-active.json."""
    gsd = get_gsd_path()
    active_path = gsd / "prd-active.json"
    done_path = gsd / "prd-done.json"

    active = load_json(active_path)
    done = load_json(done_path)

    # Generate ID from both active and done
    all_tasks = active["tasks"] + done["tasks"]
    task_id = args.task_id if args.task_id else generate_task_id(all_tasks)

    # Check for duplicate
    if find_task_by_id(active["tasks"], task_id)[1]:
        return {
            "success": False,
            "error": f"Task {task_id} already exists in active",
        }

    task = {
        "id": task_id,
        "title": args.title,
        "status": "pending",
        "created": datetime.now(timezone.utc).isoformat(),
    }

    if args.description:
        task["description"] = args.description
    if args.phase:
        task["phase"] = args.phase
    if args.plan:
        task["plan"] = args.plan
    if args.task_num:
        task["task_num"] = args.task_num
    if args.wave:
        task["wave"] = args.wave
    if args.priority:
        task["priority"] = args.priority
    if args.tags:
        task["tags"] = args.tags.split(",")
    if args.dependencies:
        task["dependencies"] = args.dependencies.split(",")

    active["tasks"].append(task)
    save_json(active_path, active)

    return {
        "success": True,
        "action": "added",
        "task": task,
        "total_active": len(active["tasks"]),
    }


def cmd_status(args: argparse.Namespace) -> dict[str, Any]:
    """Show current PRD status."""
    gsd = get_gsd_path()
    active_path = gsd / "prd-active.json"
    done_path = gsd / "prd-done.json"

    active = load_json(active_path)
    done = load_json(done_path)

    active_tasks = active.get("tasks", [])
    done_tasks = done.get("tasks", [])

    # Group by status
    pending = [t for t in active_tasks if t.get("status") == "pending"]
    in_progress = [t for t in active_tasks if t.get("status") == "in_progress"]
    blocked = [t for t in active_tasks if t.get("status") == "blocked"]

    return {
        "success": True,
        "summary": {
            "pending": len(pending),
            "in_progress": len(in_progress),
            "blocked": len(blocked),
            "done": len(done_tasks),
            "total": len(active_tasks) + len(done_tasks),
        },
        "active_tasks": [
            {"id": t["id"], "title": t["title"], "status": t["status"]} for t in active_tasks
        ],
        "gsd_path": str(gsd),
    }


def cmd_start(args: argparse.Namespace) -> dict[str, Any]:
    """Mark a task as in_progress."""
    gsd = get_gsd_path()
    active_path = gsd / "prd-active.json"

    active = load_json(active_path)

    idx, task = find_task_by_id(active["tasks"], args.task_id)

    if task is None:
        return {
            "success": False,
            "error": f"Task {args.task_id} not found",
        }

    task["status"] = "in_progress"
    task["started"] = datetime.now(timezone.utc).isoformat()

    save_json(active_path, active)

    return {
        "success": True,
        "action": "started",
        "task": task,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="PRD Task State Manager",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    subparsers = parser.add_subparsers(dest="command", help="Command")

    # complete
    p_complete = subparsers.add_parser("complete", help="Complete a task by ID")
    p_complete.add_argument("task_id", help="Task ID (e.g., TASK-001)")
    p_complete.add_argument("--commit", help="Git commit hash")
    p_complete.add_argument("--summary", help="Completion summary")

    # complete-plan
    p_complete_plan = subparsers.add_parser(
        "complete-plan", help="Complete a task by plan reference"
    )
    p_complete_plan.add_argument("plan_ref", help="Plan reference (phase.plan.task, e.g., 1.2.1)")
    p_complete_plan.add_argument("--commit", help="Git commit hash")
    p_complete_plan.add_argument("--summary", help="Completion summary")

    # add
    p_add = subparsers.add_parser("add", help="Add a new task")
    p_add.add_argument("--task-id", help="Task ID (auto-generated if not provided)")
    p_add.add_argument("--title", required=True, help="Task title")
    p_add.add_argument("--description", help="Task description")
    p_add.add_argument("--phase", type=int, help="Phase number")
    p_add.add_argument("--plan", type=int, help="Plan number within phase")
    p_add.add_argument("--task-num", type=int, help="Task number within plan")
    p_add.add_argument("--wave", type=int, help="Execution wave")
    p_add.add_argument("--priority", choices=["low", "medium", "high", "critical"], help="Priority")
    p_add.add_argument("--tags", help="Comma-separated tags")
    p_add.add_argument("--dependencies", help="Comma-separated task IDs")

    # status
    subparsers.add_parser("status", help="Show PRD status")

    # start
    p_start = subparsers.add_parser("start", help="Mark task as in_progress")
    p_start.add_argument("task_id", help="Task ID")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    commands = {
        "complete": cmd_complete,
        "complete-plan": cmd_complete_plan,
        "add": cmd_add,
        "status": cmd_status,
        "start": cmd_start,
    }

    result = commands[args.command](args)
    print(json.dumps(result, indent=2, ensure_ascii=False))

    if not result.get("success", True):
        sys.exit(1)


if __name__ == "__main__":
    main()
