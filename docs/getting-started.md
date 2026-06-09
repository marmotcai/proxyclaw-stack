# 快速开始

## 前置条件

- Docker & Docker Compose
- 2GB+ 可用内存

## 1. 初始化配置

```bash
cd proxyclaw-stack
cp .env.example .env
```

按需编辑 `.env`：

| 场景 | 必填变量 |
|------|----------|
| 仅中间件 | `POSTGRES_PASSWORD`（向导可自动生成） |
| Mem0 | 上述 + `MEM0_JWT_SECRET`、`MEM0_ADMIN_API_KEY` |
| Pi Sandbox | 至少一个 LLM Key，如 `OPENAI_API_KEY` 或 `KIMI_API_KEY` |

也可运行向导自动生成密钥：

```bash
./start.sh w
```

向导选项说明：

| 选项 | 内容 |
|------|------|
| 1 | 基础中间件 |
| 2 | Mem0 完整栈（含依赖中间件） |
| 3 | 全部服务 |
| **4** | **仅 Pi Sandbox（独立，无需中间件）** |
| 5 | 仅 PostgreSQL |
| 6 | 自定义选择 |

## 2. 按场景启动

在 **proxyclaw 主仓库** 使用同源编排库（`lib/stack.sh`，无需 `cd proxyclaw-stack`）：

```bash
cd /path/to/proxyclaw
./start.sh stack start base
./start.sh stack ensure postgresql ollama   # 仅确保依赖已运行
./start.sh stack status
```

`proxyclaw-stack/start.sh` 为薄入口，与 `./start.sh stack` 加载同一套逻辑。

### 仅基础中间件

```bash
./start.sh start base
./start.sh status
```

### Mem0 记忆服务

```bash
./start.sh start mem0
curl http://localhost:20061/health
```

`start.sh` 会自动：创建共享 Docker 网络 → 拉起缺失的 PG/Qdrant/Neo4j/Ollama → 启动 Mem0。

配置检查：认证密钥仍为 `__RANDOM_PASSWORD__` 时会**自动生成**；LLM 未配置时会**弹出向导**（Ollama 本地 / OpenAI 兼容 API / 混合方案）。

### Pi Agent 网关（独立，无需 middleware）

```bash
./start.sh start pi-sandbox
curl http://localhost:20062/api/health
```

若 `.env` 中未配置 LLM API Key，启动时会**自动弹出向导**引导选择供应商并填入密钥。

### 全部服务

```bash
./start.sh start all
```

## 3. 验证

```bash
./start.sh health
```

## 4. 停止与清理

```bash
./start.sh stop all          # 停止，保留数据卷
./start.sh clean mem0        # 清理 Mem0 容器与镜像
./start.sh clean all         # 清理全部（含数据卷）
```

## 下一步

- [Pi Sandbox 操作手册](pi-sandbox-guide.md)
- [Mem0 操作手册](mem0-guide.md)
- [中间件说明](middleware-guide.md)