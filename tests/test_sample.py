"""Sample tests demonstrating project conventions.

TDD workflow:
  1. Write failing test  →  commit
  2. Implement code      →  make test pass
  3. Refactor            →  keep tests green

Run:
  uv run pytest tests/               # all
  uv run pytest tests/ -k "sample"   # this file only
"""

from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import sqlite3
    from pathlib import Path


class TestProjectStructure:
    """Verify boilerplate skeleton is intact."""

    def test_claude_md_exists(self, project_root: Path) -> None:
        assert (project_root / "CLAUDE.md").is_file()

    def test_mcp_json_exists(self, project_root: Path) -> None:
        assert (project_root / ".mcp.json").is_file()

    def test_gsd_directory_exists(self, project_root: Path) -> None:
        assert (project_root / ".gsd").is_dir()

    def test_agents_present(self, project_root: Path) -> None:
        agents = list((project_root / ".claude" / "agents").glob("*.md"))
        assert len(agents) >= 14

    def test_skills_present(self, project_root: Path) -> None:
        skills = list((project_root / ".claude" / "skills").iterdir())
        skill_dirs = [s for s in skills if s.is_dir()]
        assert len(skill_dirs) >= 16


class TestDatabaseFixture:
    """Demonstrate in-memory DB fixture usage."""

    def test_db_connection_works(self, db_conn: sqlite3.Connection) -> None:
        cur = db_conn.execute("SELECT 1 AS ok")
        row = cur.fetchone()
        assert row is not None
        assert row["ok"] == 1

    def test_db_isolation(self, db_conn: sqlite3.Connection) -> None:
        """Each test gets a fresh connection — no shared state."""
        db_conn.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT)")
        db_conn.execute("INSERT INTO items (name) VALUES ('test')")
        cur = db_conn.execute("SELECT COUNT(*) AS cnt FROM items")
        assert cur.fetchone()["cnt"] == 1


class TestTmpWorkspace:
    """Demonstrate tmp_workspace fixture for file-producing tests."""

    def test_workspace_is_empty(self, tmp_workspace: Path) -> None:
        assert list(tmp_workspace.iterdir()) == []

    def test_can_create_files(self, tmp_workspace: Path) -> None:
        f = tmp_workspace / "output.txt"
        f.write_text("hello")
        assert f.read_text() == "hello"
