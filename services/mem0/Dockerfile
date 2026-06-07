FROM docker.m.daocloud.io/library/python:3.11-slim

WORKDIR /app

# 安装系统依赖（添加 sed 用于 patch）
# 替换为阿里云镜像源以解决 deb.debian.org 连接超时问题
RUN sed -i 's|http://deb.debian.org/debian|http://mirrors.aliyun.com/debian|g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's|http://security.debian.org/debian-security|http://mirrors.aliyun.com/debian-security|g' /etc/apt/sources.list.d/debian.sources && \
    apt-get update && apt-get install -y --no-install-recommends git libpq-dev gcc sed postgresql-client && rm -rf /var/lib/apt/lists/*

# 下载 mem0 官方源码
ADD https://github.com/mem0ai/mem0/archive/refs/heads/main.tar.gz /tmp/mem0.tar.gz
RUN tar -xzf /tmp/mem0.tar.gz -C /tmp && rm -rf /app && mv /tmp/mem0-main /app && rm /tmp/mem0.tar.gz

# 安装 mem0ai 核心包（本地 editable 模式）
RUN pip install --no-cache-dir -e /app

# 安装 server 专属依赖
RUN pip install --no-cache-dir -r server/requirements.txt

# 安装 Ollama 支持（LLM + Embedder provider）
RUN pip install --no-cache-dir ollama

# Patch main.py：
# 1. 支持通过 EMBEDDING_MODEL_DIMS 环境变量配置向量维度
# 2. 扩展 provider 白名单支持 ollama
# 3. DEFAULT_CONFIG 根据环境变量动态选择 provider
RUN cat > /tmp/patch_main.py << 'PYEOF'
import os
import re

with open("/app/server/main.py", "r") as f:
    content = f.read()

# 1. Patch provider 白名单
content = content.replace(
    'BUNDLED_LLM_PROVIDERS = ("openai", "anthropic", "gemini")',
    'BUNDLED_LLM_PROVIDERS = ("openai", "anthropic", "gemini", "ollama")'
)
content = content.replace(
    'BUNDLED_EMBEDDER_PROVIDERS = ("openai", "gemini")',
    'BUNDLED_EMBEDDER_PROVIDERS = ("openai", "gemini", "ollama")'
)

# 2. 在 OPENAI_API_KEY 读取后添加 Ollama 环境变量
if 'LLM_PROVIDER = os.environ.get' not in content:
    ollama_env_block = '''OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")
LLM_PROVIDER = os.environ.get("LLM_PROVIDER", "openai")
EMBEDDER_PROVIDER = os.environ.get("EMBEDDER_PROVIDER", "openai")
OLLAMA_BASE_URL = os.environ.get("OLLAMA_BASE_URL", "http://localhost:11434")'''
    content = content.replace(
        'OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")',
        ollama_env_block
    )

# 3. Patch DEFAULT_CONFIG 使其动态选择 provider
old_llm_block = '''    "llm": {
        "provider": "openai",
        "config": {"api_key": OPENAI_API_KEY, "temperature": 0.2, "model": DEFAULT_LLM_MODEL},
    },
    "embedder": {"provider": "openai", "config": {"api_key": OPENAI_API_KEY, "model": DEFAULT_EMBEDDER_MODEL}},'''

if old_llm_block in content:
    new_llm_block = '''    "llm": {
        "provider": LLM_PROVIDER,
        "config": (
            {"model": DEFAULT_LLM_MODEL, "temperature": 0.2, "ollama_base_url": OLLAMA_BASE_URL}
            if LLM_PROVIDER == "ollama"
            else {"api_key": OPENAI_API_KEY, "temperature": 0.2, "model": DEFAULT_LLM_MODEL}
        ),
    },
    "embedder": {
        "provider": EMBEDDER_PROVIDER,
        "config": (
            {"model": DEFAULT_EMBEDDER_MODEL, "ollama_base_url": OLLAMA_BASE_URL, "embedding_dims": int(os.environ.get("EMBEDDING_MODEL_DIMS", "768"))}
            if EMBEDDER_PROVIDER == "ollama"
            else {"api_key": OPENAI_API_KEY, "model": DEFAULT_EMBEDDER_MODEL}
        ),
    },'''
    content = content.replace(old_llm_block, new_llm_block)

# 4. Patch pgvector embedding_model_dims
if '"embedding_model_dims":' not in content:
    content = content.replace(
        '"collection_name": POSTGRES_COLLECTION_NAME,',
        '"collection_name": POSTGRES_COLLECTION_NAME,\n            "embedding_model_dims": int(os.environ.get("EMBEDDING_MODEL_DIMS", "1536")),'
    )

with open("/app/server/main.py", "w") as f:
    f.write(content)

print("Patched /app/server/main.py successfully")
PYEOF
RUN python3 /tmp/patch_main.py

WORKDIR /app/server

# 创建自动迁移 + 启动脚本
RUN cat > /app/server/start.sh << 'EOF'
#!/bin/bash
set -e

# 确保数据库存在
PG_DB="${APP_DB_NAME:-mem0_app}"
echo "Ensuring database ${PG_DB} exists..."
PGPASSWORD="${POSTGRES_PASSWORD:-postgres}" psql \
    -h "${POSTGRES_HOST:-postgres}" -p "${POSTGRES_PORT:-5432}" \
    -U "${POSTGRES_USER:-postgres}" -d postgres \
    -c "CREATE DATABASE \"${PG_DB}\";" 2>/dev/null || echo "Database ${PG_DB} already exists or created"

# 根据环境变量动态配置 alembic.ini
DB_URL="postgresql+psycopg://${POSTGRES_USER:-postgres}:${POSTGRES_PASSWORD:-postgres}@${POSTGRES_HOST:-postgres}:${POSTGRES_PORT:-5432}/${PG_DB}"
sed -i "s|sqlalchemy.url = .*|sqlalchemy.url = ${DB_URL}|" /app/server/alembic.ini

# 执行数据库迁移
echo "Running database migrations..."
cd /app/server && alembic upgrade head

# 启动服务
echo "Starting mem0 server..."
exec uvicorn main:app --host 0.0.0.0 --port 8000
EOF
RUN chmod +x /app/server/start.sh

EXPOSE 8000

CMD ["/app/server/start.sh"]
