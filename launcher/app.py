"""
Launcher App: Setup Wizard for AI-Native Boilerplate.

Run with: python -m launcher.app
Opens at: http://localhost:8000
"""

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel
from pathlib import Path
import shutil
import subprocess
import os

app = FastAPI(title="Agent Booster Launcher")

# Templates and static files
BASE_DIR = Path(__file__).parent
templates = Jinja2Templates(directory=BASE_DIR / "templates")

# --- Models ---
class ScanRequest(BaseModel):
    path: str

class InjectRequest(BaseModel):
    option: str  # "a", "b", "c"
    target_path: str
    project_name: str = "my_project"
    cli_command: str = "claude"  # For Option C


# --- API Routes ---
@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})


@app.post("/api/scan")
async def scan_project(req: ScanRequest):
    """Scan target directory and recommend an option."""
    target = Path(req.path).expanduser().resolve()

    if not target.exists():
        return JSONResponse({"error": f"Path not found: {target}"}, status_code=400)

    # Detect project type
    project_type = "unknown"
    recommendation = "a"  # Default: Manual

    if (target / "pyproject.toml").exists() or (target / "requirements.txt").exists():
        project_type = "python"
        recommendation = "c"  # Hybrid recommended for Python
    elif (target / "package.json").exists():
        project_type = "node"
        recommendation = "c"
    elif (target / "pom.xml").exists() or (target / "build.gradle").exists():
        project_type = "java"
        recommendation = "b"  # Full auto for Java (less CLI support)

    return {
        "path": str(target),
        "project_type": project_type,
        "recommendation": recommendation,
        "is_git": (target / ".git").is_dir(),
    }


@app.post("/api/inject")
async def inject_kit(req: InjectRequest):
    """Inject the selected kit into a dedicated subdirectory of the target project."""
    target = Path(req.target_path).expanduser().resolve()
    kits_dir = Path(__file__).parent.parent / "kits"

    # Create dedicated boilerplate directory to avoid conflicts
    BOILERPLATE_DIR = ".agent-booster"
    inject_target = target / BOILERPLATE_DIR

    if not target.exists():
        return JSONResponse({"error": f"Target path not found: {target}"}, status_code=400)

    # Determine kit to copy
    kit_path = kits_dir / f"option_{req.option}"
    common_path = kits_dir / "common"

    if not kit_path.exists():
        return JSONResponse({"error": f"Kit not found: option_{req.option}"}, status_code=400)

    try:
        # Create the dedicated directory
        inject_target.mkdir(parents=True, exist_ok=True)

        # Copy common files into .agent-booster/
        for item in common_path.iterdir():
            dest = inject_target / item.name
            if item.is_file():
                shutil.copy2(item, dest)
            elif item.is_dir():
                shutil.copytree(item, dest, dirs_exist_ok=True)

        # Copy option-specific files into .agent-booster/
        for item in kit_path.iterdir():
            dest = inject_target / item.name
            if item.is_file():
                shutil.copy2(item, dest)
            elif item.is_dir():
                shutil.copytree(item, dest, dirs_exist_ok=True)

        # Initialize git in project root if not present
        if not (target / ".git").is_dir():
            subprocess.run(["git", "init"], cwd=target, capture_output=True)

        # Add .agent-booster to .gitignore if it exists
        gitignore_path = target / ".gitignore"
        if gitignore_path.exists():
            content = gitignore_path.read_text()
            if BOILERPLATE_DIR not in content:
                with open(gitignore_path, "a") as f:
                    f.write(f"\n# Agent Booster config (may contain API keys)\n{BOILERPLATE_DIR}/\n")

        # Create .env with absolute path to project root
        env_path = inject_target / ".env"
        with open(env_path, "w") as f:
            f.write(f"# Auto-generated config\n")
            f.write(f"PROJECT_ROOT=\"{target}\"\n")
            f.write(f"PROJECT_NAME=\"{req.project_name}\"\n")
            # Copy other defaults from example if needed, but let's keep it minimal for now
            with open(common_path / ".env.example") as example:
                f.write("\n" + example.read())

        return {
            "success": True,
            "message": f"Option {req.option.upper()} injected into '{BOILERPLATE_DIR}/' successfully!",
            "inject_path": str(inject_target),
            "next_steps": [
                f"Review {BOILERPLATE_DIR}/INSTRUCTIONS.md",
                f"Check {BOILERPLATE_DIR}/.env (PROJECT_ROOT is pre-configured)",
                f"Run: docker-compose -f {BOILERPLATE_DIR}/mcp/docker-compose.mcp.yml up -d",
            ]
        }
    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=500)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
