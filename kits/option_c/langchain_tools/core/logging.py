import sqlite3
import json
import time
from datetime import datetime
from typing import Any, Dict, Optional, Literal
from pydantic import BaseModel
from pathlib import Path

class LogEvent(BaseModel):
    task_id: str
    phase: str
    actor: str  # e.g., "orchestrator", "claude-cli", "system"
    level: Literal["INFO", "WARNING", "ERROR", "DEBUG"] = "INFO"
    message: str
    metadata: Dict[str, Any] = {}
    timestamp: str = ""

    def model_post_init(self, __context):
        if not self.timestamp:
            self.timestamp = datetime.utcnow().isoformat()

class StructuredLogger:
    """
    A standalone SQLite-backed logger.
    Used by:
    - Launcher (Setup logs)
    - Orchestrator (Decision logs)
    - CLI Wrapper (Execution logs)
    """

    def __init__(self, db_path: str = ".logs/events.db"):
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _init_db(self):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                task_id TEXT,
                phase TEXT,
                actor TEXT,
                level TEXT,
                message TEXT,
                metadata TEXT,
                timestamp TEXT
            )
        """)
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_task_id ON events(task_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_timestamp ON events(timestamp)")
        conn.commit()
        conn.close()

    def log(self, event: LogEvent):
        if not event.timestamp:
            event.timestamp = datetime.utcnow().isoformat()

        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO events (task_id, phase, actor, level, message, metadata, timestamp)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                event.task_id,
                event.phase,
                event.actor,
                event.level,
                event.message,
                json.dumps(event.metadata),
                event.timestamp
            )
        )
        conn.commit()
        conn.close()

    def query_events(self, task_id: str, limit: int = 100) -> list[LogEvent]:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute(
            "SELECT * FROM events WHERE task_id = ? ORDER BY timestamp ASC LIMIT ?",
            (task_id, limit)
        )
        rows = cursor.fetchall()
        conn.close()

        events = []
        for row in rows:
            events.append(LogEvent(
                task_id=row["task_id"],
                phase=row["phase"],
                actor=row["actor"],
                level=row["level"],
                message=row["message"],
                metadata=json.loads(row["metadata"]),
                timestamp=row["timestamp"]
            ))
        return events
