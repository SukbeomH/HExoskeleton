#!/bin/bash

# Configuration
NEO4J_HOST="localhost"
NEO4J_PORT="7687"
NEO4J_HTTP_PORT="7474"

echo "🧪 Starting Neo4j Integration Test"
echo "================================="

# Check availability
if ! nc -z $NEO4J_HOST $NEO4J_PORT; then
    echo "❌ Neo4j not reachable at $NEO4J_HOST:$NEO4J_PORT"
    echo "   Please run: cd platform-core && docker-compose up -d"
    exit 1
fi
echo "✅ Neo4j connection check passed."

# Define test query
TEST_QUERY='RETURN "Hello from OmniGraph!" as message'

# Run via .venv/bin/python driver (requires dependencies)
echo "Running smoke test via API Server..."
.venv/bin/python -c "
from neo4j import GraphDatabase
import os
import sys

uri = os.getenv('NEO4J_URI', 'bolt://localhost:7687')
user = os.getenv('NEO4J_USER', 'neo4j')
pwd = os.getenv('NEO4J_PASSWORD', 'omnigraph')

try:
    with GraphDatabase.driver(uri, auth=(user, pwd)) as driver:
        driver.verify_connectivity()
        result = driver.execute_query('RETURN 1 as val')
        print('✅ Driver connectivity verified (val=1)')
except Exception as e:
    print(f'❌ Connection failed: {e}')
    sys.exit(1)
"

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Test Completed Successfully!"
else
    echo ""
    echo "💥 Test Failed."
    exit 1
fi
