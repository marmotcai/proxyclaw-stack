FROM python:3.11-slim

WORKDIR /app

# 安装系统依赖（添加 sed 用于 patch）
RUN apt-get update && apt-get install -y --no-install-recommends git libpq-dev gcc sed && rm -rf /var/lib/apt/lists/*

# 从 GitHub 克隆 mem0 官方源码
RUN git clone --depth 1 https://github.com/mem0ai/mem0.git /app

# 安装 mem0ai 核心包（本地 editable 模式）
RUN pip install --no-cache-dir -e .

# 安装 server 专属依赖
RUN pip install --no-cache-dir -r server/requirements.txt

# Patch main.py：支持通过 EMBEDDING_MODEL_DIMS 环境变量配置向量维度
# 默认 1536（OpenAI），Ollama bge-m3 需设为 1024
RUN sed -i \
    's/"collection_name": POSTGRES_COLLECTION_NAME,/"collection_name": POSTGRES_COLLECTION_NAME,\n            "embedding_model_dims": int(os.environ.get("EMBEDDING_MODEL_DIMS", "1536")),/' \
    /app/server/main.py

WORKDIR /app/server

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
