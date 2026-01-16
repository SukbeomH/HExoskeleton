#!/bin/bash
# Start the Agent Dashboard from the injected directory

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "🚀 Starting Agent Dashboard..."
echo "   Config: $SCRIPT_DIR"
echo "   Project: $PROJECT_ROOT"
echo ""

# Check if we're in a virtualenv or use system python
if [ -n "$VIRTUAL_ENV" ]; then
    PYTHON="$VIRTUAL_ENV/bin/python"
    PIP="$VIRTUAL_ENV/bin/pip"
elif [ -f "$PROJECT_ROOT/.venv/bin/python" ]; then
    PYTHON="$PROJECT_ROOT/.venv/bin/python"
    PIP="$PROJECT_ROOT/.venv/bin/pip"
else
    PYTHON=$(command -v python3 || command -v python)
    # Try uv pip first, then pip3
    if command -v uv &> /dev/null; then
        PIP="uv pip"
    else
        PIP=$(command -v pip3 || command -v pip)
    fi
fi

if [ -z "$PYTHON" ]; then
    echo "❌ Python not found. Please install Python 3.12+."
    exit 1
fi

# Install dependencies if needed
if ! $PYTHON -c "import fastapi" 2>/dev/null; then
    echo "📦 Installing dependencies..."
    $PIP install fastapi uvicorn jinja2 pydantic python-dotenv --quiet 2>/dev/null || true
fi

# Start the dashboard
cd "$SCRIPT_DIR"
echo "🌐 Dashboard will be available at: http://localhost:8001"
echo ""
$PYTHON -m uvicorn runtime.app:app --host 0.0.0.0 --port 8001
