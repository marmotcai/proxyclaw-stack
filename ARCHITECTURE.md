# ProxyClaw Stack — 架构设计

## 1. 设计原则

1. **职责分离** - 中间件与业务逻辑分离
2. **依赖自举** - 服务自动启动所需依赖
3. **环境统一** - 所有配置通过 `.env` 管理
4. **健康检查** - 所有服务配置健康检查

## 2. 分层结构

```
┌─────────────────────────────────────────────┐
│              ProxyClaw Stack                │
├─────────────────────────────────────────────┤
│  start.sh (统一入口)                         │
├─────────────────────────────────────────────┤
│  middleware/          │  services/          │
│  - PostgreSQL         │  - mem0/             │
│  - Redis              │    └─ mem0-server   │
│  - Elasticsearch      │      → postgresql    │
│  - Qdrant             │      → qdrant        │
│  - Neo4j              │      → neo4j         │
│  - Ollama             │  - pi-sandbox/       │
│                       │    └─ pi + HTTP    │
├─────────────────────────────────────────────┤
│  Docker Network: proxyclaw-network           │
├─────────────────────────────────────────────┤
│  plugins/ (待迁移)                           │
│  - mem0 plugin                               │
└─────────────────────────────────────────────┘
```

## 3. 部署模式

### 模式 A: 仅基础中间件
```bash
./start.sh start base
```

### 模式 B: Mem0 完整栈
```bash
./start.sh start base
./start.sh start mem0
```

### 模式 C: 全部服务
```bash
./start.sh start all
```

## 4. 网络设计

- 网络名称: `proxyclaw-network`
- 网络类型: bridge
- 服务间通过服务名通信（如 `postgresql:5432`）

## 5. 数据持久化

所有数据通过 Docker volumes 持久化：

| Volume | 用途 |
|--------|------|
| `postgresql_data` | PostgreSQL 数据 |
| `redis_data` | Redis 数据 |
| `es_data` | Elasticsearch 数据 |
| `qdrant_data` | Qdrant 数据 |
| `neo4j_data` | Neo4j 数据 |
| `ollama_data` | Ollama 模型 |
| `mem0_history_data` | Mem0 历史数据 |
| `pi-sandbox-sessions` | Pi 会话数据 |
| `pi-sandbox-workspace` | Pi 工作区 |