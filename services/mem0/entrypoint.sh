#!/bin/bash
set -e
echo "[mem0-entrypoint] Starting Mem0 Server..."
sed -i 's/"host": QDRANT_HOST,/"url": f"http:\/\/{QDRANT_HOST}:{QDRANT_PORT}",/g' /app/server/main.py
sed -i 's/"port": int(QDRANT_PORT),/# port removed to use url/g' /app/server/main.py
exec uvicorn main:app --host 0.0.0.0 --port 8000