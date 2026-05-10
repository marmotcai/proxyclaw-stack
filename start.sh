#!/bin/bash
# =============================================================================
# ProxyClaw Stack - 统一启动脚本
# =============================================================================
# 支持启动通用中间件、Mem0、Pi Sandbox 等第三方服务
# =============================================================================

set -euo pipefail

readonly RED=$'\033[0;31m'
readonly GREEN=$'\033[0;32m'
readonly YELLOW=$'\033[1;33m'
readonly BLUE=$'\033[0;34m'
readonly CYAN=$'\033[0;36m'
readonly NC=$'\033[0m'

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MIDDLEWARE_DIR="${PROJECT_ROOT}/middleware"
readonly SERVICES_DIR="${PROJECT_ROOT}/services"

cd "$PROJECT_ROOT"

readonly ENV_FILE="${PROJECT_ROOT}/.env"

print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
print_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }

generate_password() {
    local length="${1:-32}"
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 "$length" | tr -d '=/+' | head -c "$length"
    else
        tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$length"
    fi
}

load_env() {
    if [ -f "${PROJECT_ROOT}/.env" ]; then
        set -a
        # shellcheck source=/dev/null
        source "${PROJECT_ROOT}/.env"
        set +a
        print_success "环境变量已加载: .env"
    elif [ -f "${PROJECT_ROOT}/.env.example" ]; then
        print_warn "未找到 .env，使用 .env.example"
        set -a
        # shellcheck source=/dev/null
        source "${PROJECT_ROOT}/.env.example"
        set +a
    else
        print_warn "未找到环境变量文件"
    fi
}

check_dependencies() {
    local deps_ok=true
    command -v docker >/dev/null 2>&1 || { print_error "Docker 未安装"; deps_ok=false; }
    docker info >/dev/null 2>&1 || { print_error "Docker 守护进程未运行"; deps_ok=false; }
    docker compose --env-file "${ENV_FILE}" version >/dev/null 2>&1 || docker-compose version >/dev/null 2>&1 || { print_error "Docker Compose 未安装"; deps_ok=false; }
    $deps_ok || exit 1
}

# =============================================================================
# 向导模式
# =============================================================================

wizard_read() {
    local prompt="$1"
    local default="${2:-}"
    local input=""

    if [ -n "$default" ]; then
        echo -ne "${CYAN}${prompt} [${default}]: ${NC}" >&2
    else
        echo -ne "${CYAN}${prompt}: ${NC}" >&2
    fi

    if [ -t 0 ]; then
        read -r input
    else
        read -r input < /dev/tty 2>/dev/null || input=""
    fi

    echo "${input:-$default}"
}

wizard_confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local input

    if [ "$default" = "y" ]; then
        echo -ne "${YELLOW}${prompt} [Y/n]: ${NC}" >&2
    else
        echo -ne "${YELLOW}${prompt} [y/N]: ${NC}" >&2
    fi

    read -r input
    input="${input:-$default}"
    [[ "$input" =~ ^[Yy]$ ]]
}

wizard_step() {
    local step_num="$1"
    local title="$2"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  步骤 ${step_num}: ${title}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

ensure_env_file() {
    if [ ! -f "${PROJECT_ROOT}/.env" ]; then
        print_warn "未找到 .env 文件"
        echo ""
        echo -e "启动服务需要配置文件，是否现在生成? ${CYAN}[Y/n]${NC}"
        echo -ne "> "
        read -r answer
        if [[ "$answer" =~ ^[Nn] ]]; then
            print_info "已取消"
            exit 0
        else
            init_env_file
        fi
    fi
}

init_env_file() {
    if [ ! -f "${PROJECT_ROOT}/.env" ]; then
        if [ ! -f "${PROJECT_ROOT}/.env.example" ]; then
            print_error "未找到 .env.example 文件"
            exit 1
        fi

        print_info "从 .env.example 创建 .env..."
        cp "${PROJECT_ROOT}/.env.example" "${PROJECT_ROOT}/.env"

        local password
        password=$(generate_password 32)
        print_info "自动生成统一密钥..."

        # 写入临时文件再 mv：兼容 macOS BSD sed（其 sed -i 需备份后缀参数，易误解析脚本）
        local tmp_env
        tmp_env=$(mktemp)

        sed \
            -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${password}|" \
            -e "s|^PG_PASSWORD=.*|PG_PASSWORD=${password}|" \
            -e "s|^REDIS_PASSWORD=.*|REDIS_PASSWORD=|" \
            -e "s|^ELASTICSEARCH_PASSWORD=.*|ELASTICSEARCH_PASSWORD=${password}|" \
            -e "s|^NEO4J_PASSWORD=.*|NEO4J_PASSWORD=${password}|" \
            -e "s|^MEM0_ADMIN_API_KEY=.*|MEM0_ADMIN_API_KEY=mem0_${password}|" \
            -e "s|^MEM0_JWT_SECRET=.*|MEM0_JWT_SECRET=${password}|" \
            -e "s|^MEM0_QDRANT_API_KEY=.*|MEM0_QDRANT_API_KEY=qdrant_${password}|" \
            -e "s|^MEM0_OPENAI_API_KEY=.*|MEM0_OPENAI_API_KEY=|" \
            -e "s|^MEM0_POSTGRES_PASSWORD=.*|MEM0_POSTGRES_PASSWORD=${password}|" \
            "${PROJECT_ROOT}/.env" > "$tmp_env"
        mv "$tmp_env" "${PROJECT_ROOT}/.env"

        mkdir -p "${SERVICES_DIR}/mem0"
        cp "${PROJECT_ROOT}/.env" "${SERVICES_DIR}/mem0/.env"

        print_success "已创建 .env 并生成统一密钥"
    else
        print_success "找到 .env 文件"
    fi

    load_env
}

run_wizard() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         ProxyClaw Stack 交互式启动向导                       ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    wizard_step 1 "环境变量配置"
    ensure_env_file

    echo ""
    print_info "当前配置的服务端口:"
    echo "  PostgreSQL:  ${POSTGRES_PORT:-5432}"
    echo "  Redis:       ${REDIS_PORT:-26379}"
    echo "  Qdrant:      ${QDRANT_PORT:-6333}"
    echo "  Neo4j:       ${NEO4J_HTTP_PORT:-7474}"
    echo "  Mem0:        ${MEM0_PORT:-20061}"
    echo "  Pi Sandbox:  ${PI_SANDBOX_PORT:-20062}"
    echo ""
    print_info "统一密钥已自动生成（可通过修改 .env 更换）"

    wizard_step 2 "选择服务组合"

    echo "请选择要启动的服务组合（输入数字）:"
    echo ""
    echo "  ${GREEN}[1]${NC} 基础中间件（推荐）"
    echo "      包含: PostgreSQL, Redis, Elasticsearch, Qdrant, Neo4j, Ollama"
    echo ""
    echo "  ${GREEN}[2]${NC} Mem0 完整栈"
    echo "      包含: PostgreSQL + Qdrant + Neo4j + Mem0 Server"
    echo ""
    echo "  ${GREEN}[3]${NC} 全部服务"
    echo "      包含: 基础中间件 + Mem0 + Pi Sandbox"
    echo ""
    echo "  ${GREEN}[4]${NC} 仅 PostgreSQL"
    echo "      仅启动 PostgreSQL 数据库"
    echo ""
    echo "  ${GREEN}[5]${NC} 自定义选择"
    echo "      手动输入服务名（支持简写: pg, rd, es, qd, n4j, ol, m0, pi）"
    echo ""

    local choice
    choice=$(wizard_read "请输入选项" "1")

    local services_to_start=()

    case "$choice" in
        1)
            services_to_start+=("base")
            ;;
        2)
            services_to_start+=("mem0")
            ;;
        3)
            services_to_start+=("base")
            services_to_start+=("mem0")
            services_to_start+=("pi-sandbox")
            ;;
        4)
            services_to_start+=("postgres")
            ;;
        5)
            run_custom_selection
            return
            ;;
        *)
            print_error "无效选项: $choice"
            exit 1
            ;;
    esac

    wizard_step 3 "确认并启动"

    ensure_env_file

    echo "将要启动的服务:"
    for svc in "${services_to_start[@]}"; do
        echo "  - ${GREEN}$svc${NC}"
    done
    echo ""

    if wizard_confirm "确认启动?" "y"; then
        for svc in "${services_to_start[@]}"; do
            print_info "启动服务: $svc"
            case "$svc" in
                base)
                    docker compose --env-file "${ENV_FILE}" -f "${MIDDLEWARE_DIR}/docker-compose.yml" -p proxyclaw-stack --profile base up --remove-orphans -d
                    ;;
                mem0)
                    start_mem0
                    ;;
                pi-sandbox)
                    start_pi_sandbox
                    ;;
                *)
                    docker compose --env-file "${ENV_FILE}" -f "${MIDDLEWARE_DIR}/docker-compose.yml" -p proxyclaw-stack up --remove-orphans -d "$svc"
                    ;;
            esac
        done

        echo ""
        print_success "服务启动完成!"
        echo ""
        print_info "查看状态: ./start.sh status"
        print_info "查看日志: ./start.sh logs <服务名>"
        echo ""
        print_info "提示: 编辑 .env 文件可修改配置和密钥"
    else
        print_info "已取消启动"
    fi
}

run_custom_selection() {
    echo ""
    echo -e "${CYAN}自定义服务选择${NC}"
    echo ""
    echo "可用服务: postgres/pg, redis/rd, elasticsearch/es, qdrant/qd, neo4j/n4j, ollama/ol, mem0/m0, pi-sandbox/pi"
    echo ""
    echo "请输入要启动的服务名（空格分隔，留空结束）:"
    echo -ne "${CYAN}> ${NC}"
    read -r input

    if [ -z "$input" ]; then
        print_warn "未选择任何服务"
        return
    fi

    local selected=()
    for svc in $input; do
        local resolved
        resolved=$(resolve_service "$svc")
        if [[ "$resolved" != "$svc" ]] || [[ "$svc" =~ ^(postgres|redis|elasticsearch|qdrant|neo4j|ollama|mem0|pi-sandbox)$ ]]; then
            selected+=("$resolved")
        else
            print_warn "未知服务: $svc"
        fi
    done

    if [ ${#selected[@]} -eq 0 ]; then
        print_warn "未选择任何有效服务"
        return
    fi

    echo ""
    print_info "将启动: ${selected[*]}"

    ensure_env_file

    for svc in "${selected[@]}"; do
        case "$svc" in
            mem0)
                start_mem0
                ;;
            pi-sandbox)
                start_pi_sandbox
                ;;
            *)
                docker compose --env-file "${ENV_FILE}" -f "${MIDDLEWARE_DIR}/docker-compose.yml" -p proxyclaw-stack up --remove-orphans -d "$svc"
                ;;
    esac
    done

    print_success "服务启动完成!"
}

# =============================================================================
# 服务管理命令
# =============================================================================

start_mem0() {
    local compose_file="${SERVICES_DIR}/mem0/docker-compose.yml"

    if [ ! -f "$compose_file" ]; then
        print_error "未找到: $compose_file"
        exit 1
    fi

    print_info "检查 Mem0 依赖服务..."
    local deps_needed=false

    for svc in postgresql qdrant neo4j; do
        local running=$(docker compose --env-file "${ENV_FILE}" -f "${MIDDLEWARE_DIR}/docker-compose.yml" -p proxyclaw-stack ps -q "$svc" 2>/dev/null)
        if [ -z "$running" ] || ! docker ps -q --filter "id=$running" --filter "status=running" | grep -q .; then
            deps_needed=true
            break
        fi
    done

    if $deps_needed; then
        print_info "启动 Mem0 依赖: postgresql, qdrant, neo4j"
        docker compose --env-file "${ENV_FILE}" -f "${MIDDLEWARE_DIR}/docker-compose.yml" -p proxyclaw-stack up --remove-orphans -d postgresql qdrant neo4j
        print_info "等待依赖服务就绪（30秒）..."
        sleep 30
    else
        print_success "依赖服务已运行"
    fi

    print_info "启动 Mem0 服务..."
    docker compose --env-file "${ENV_FILE}" -f "$compose_file" up --remove-orphans -d
    print_success "Mem0 服务已启动"
}

start_pi_sandbox() {
    local compose_file="${SERVICES_DIR}/pi-sandbox/docker-compose.yml"

    if [ ! -f "$compose_file" ]; then
        print_error "未找到: $compose_file"
        exit 1
    fi

    print_info "启动 Pi Sandbox（首次构建镜像可能较慢）..."
    docker compose --env-file "${ENV_FILE}" -f "$compose_file" up --remove-orphans -d --build
    print_success "Pi Sandbox 已启动（根路径与 UI: http://localhost:${PI_SANDBOX_PORT:-20062}/ 与 …/ui/，健康检查 …/api/health）"
}

stop_service() {
    local service
    service=$(resolve_service "${1:-}")

    case "$service" in
        base)
            docker compose --env-file "${ENV_FILE}" -f "${MIDDLEWARE_DIR}/docker-compose.yml" -p proxyclaw-stack down 2>/dev/null || true
            ;;
        mem0)
            docker compose --env-file "${ENV_FILE}" -f "${SERVICES_DIR}/mem0/docker-compose.yml" down 2>/dev/null || true
            ;;
        pi-sandbox)
            docker compose --env-file "${ENV_FILE}" -f "${SERVICES_DIR}/pi-sandbox/docker-compose.yml" down 2>/dev/null || true
            ;;
        all)
            print_info "停止所有服务..."
            # 停止 docker compose 网络（使用各自的项目名称）
            docker compose --env-file "${ENV_FILE}" -f "${MIDDLEWARE_DIR}/docker-compose.yml" -p proxyclaw-stack down --remove-orphans 2>/dev/null || true
            docker compose --env-file "${ENV_FILE}" -f "${SERVICES_DIR}/mem0/docker-compose.yml" down --remove-orphans 2>/dev/null || true
            docker compose --env-file "${ENV_FILE}" -f "${SERVICES_DIR}/pi-sandbox/docker-compose.yml" down --remove-orphans 2>/dev/null || true
            print_success "所有服务已停止"
            ;;
        postgresql|redis|elasticsearch|qdrant|neo4j|ollama)
            docker compose --env-file "${ENV_FILE}" -f "${MIDDLEWARE_DIR}/docker-compose.yml" -p proxyclaw-stack stop "$service" 2>/dev/null || true
            print_success "服务已停止: $service"
            ;;
        *)
            print_error "未知服务: $service"
            echo "可用: base, mem0, pi-sandbox, all, postgres, redis, elasticsearch, qdrant, neo4j, ollama"
            exit 1
            ;;
    esac
}

show_status() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}              ProxyClaw Stack 状态                        ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

print_info "基础中间件:"
    docker compose --env-file "${ENV_FILE}" -f "${MIDDLEWARE_DIR}/docker-compose.yml" -p proxyclaw-stack ps 2>/dev/null || echo "  未运行"
    echo ""
    print_info "Mem0 服务:"
    docker compose --env-file "${ENV_FILE}" -f "${SERVICES_DIR}/mem0/docker-compose.yml" ps 2>/dev/null || echo "  未运行"
    echo ""
    print_info "Pi Sandbox:"
    docker compose --env-file "${ENV_FILE}" -f "${SERVICES_DIR}/pi-sandbox/docker-compose.yml" ps 2>/dev/null || echo "  未运行"
    echo ""
}

show_health() {
    print_info "=== 健康检查 ==="
    local failed=0

    check_service_health "PostgreSQL" 5432 || failed=$((failed + 1))
    check_service_health "Redis" 6379 || failed=$((failed + 1))
    check_service_health "Qdrant" 6333 || failed=$((failed + 1))
    check_service_health "Neo4j" 7474 || failed=$((failed + 1))

    if [ $failed -eq 0 ]; then
        print_success "所有服务健康"
    else
        print_warn "$failed 个服务不可用"
    fi
}

check_service_health() {
    local name="$1"
    local port="$2"
    if bash -c "echo >/dev/tcp/localhost/$port" 2>/dev/null; then
        print_success "$name ($port) - 可用"
        return 0
    else
        print_warn "$name ($port) - 不可用"
        return 1
    fi
}

# =============================================================================
# 帮助信息
# =============================================================================

show_help() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                  ProxyClaw Stack 管理脚本                        ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}用法:${NC} ${GREEN}$0${NC} ${YELLOW}<命令>${NC} [服务]"
    echo ""
    echo -e "${CYAN}━━━ 启动向导 ━━━${NC}"
    echo "  ${GREEN}w${NC}, ${GREEN}wizard${NC}              交互式启动向导（推荐首次使用）"
    echo ""
    echo -e "${CYAN}━━━ 启动服务 ━━━${NC}"
    echo "  ${GREEN}start${NC} [服务]         启动服务"
    echo "  ${GREEN}start base${NC}            启动所有基础中间件"
    echo "  ${GREEN}start mem0${NC}            启动 Mem0（含依赖）"
    echo "  ${GREEN}start pi-sandbox${NC}     启动 Pi Sandbox（Pi Agent HTTP 网关）"
    echo "  ${GREEN}start all${NC}             启动全部服务"
    echo ""
    echo -e "${CYAN}━━━ 单个服务（支持简写）━━━━${NC}"
    echo "  ${GREEN}start pg${NC}    启动 PostgreSQL"
    echo "  ${GREEN}start rd${NC}    启动 Redis"
    echo "  ${GREEN}start es${NC}    启动 Elasticsearch"
    echo "  ${GREEN}start qd${NC}    启动 Qdrant"
    echo "  ${GREEN}start n4j${NC}   启动 Neo4j"
    echo "  ${GREEN}start ol${NC}    启动 Ollama"
    echo "  ${GREEN}start m0${NC}    启动 Mem0"
    echo "  ${GREEN}start pi${NC}    启动 Pi Sandbox"
    echo ""
    echo "  完整名称也可用: postgres, redis, elasticsearch, qdrant, neo4j, ollama, mem0, pi-sandbox"
    echo ""
    echo -e "${CYAN}━━━ 停止服务 ━━━${NC}"
    echo "  ${GREEN}stop${NC} [服务]           停止服务"
    echo "  ${GREEN}stop all${NC}             停止所有服务"
    echo ""
    echo -e "${CYAN}━━━ 查看状态 ━━━${NC}"
    echo "  ${GREEN}status${NC}                查看所有服务状态"
    echo "  ${GREEN}health${NC}                健康检查"
    echo ""
    echo -e "${CYAN}━━━ 日志查看 ━━━${NC}"
    echo "  ${GREEN}logs${NC} <服务>           查看服务日志（跟随）"
    echo "  例: ${YELLOW}logs mem0${NC}       查看 Mem0 日志"
    echo "  例: ${YELLOW}logs postgres${NC}   查看 PostgreSQL 日志"
    echo ""
    echo -e "${CYAN}━━━ 其他命令 ━━━${NC}"
    echo "  ${GREEN}restart${NC} [服务]        重启服务"
    echo "  ${GREEN}help${NC}, ${GREEN}--help${NC}, ${GREEN}-h${NC}    显示此帮助信息"
    echo ""

    echo -e "${CYAN}━━━ 可用服务列表 ━━━${NC}"
    echo ""
    echo -e "  ${YELLOW}基础中间件:${NC}"
    echo "    postgres       PostgreSQL + pgvector (端口: 5432)"
    echo "    redis          Redis 缓存 (端口: 6379)"
    echo "    elasticsearch  Elasticsearch 向量存储 (端口: 9200)"
    echo "    qdrant         Qdrant 向量数据库 (端口: 6333)"
    echo "    neo4j          Neo4j 图数据库 (端口: 7474/7687)"
    echo "    ollama         Ollama 本地模型 (端口: 11434)"
    echo ""
    echo -e "  ${YELLOW}第三方服务:${NC}"
    echo "    mem0           Mem0 记忆服务 (端口: 20061)"
    echo "                   依赖: postgresql, qdrant, neo4j"
    echo "    pi-sandbox     Pi Agent 沙盒 HTTP 网关 (端口: 20062)"
    echo "                   需在 .env 配置至少一个 LLM API Key（如 ANTHROPIC_API_KEY）"
    echo ""
    echo -e "${CYAN}━━━ 快速开始 ━━━${NC}"
    echo "  ${GREEN}1.${NC} 交互式向导: ${YELLOW}./start.sh w${NC}"
    echo "  ${GREEN}2.${NC} 选择服务组合并启动"
    echo "  ${GREEN}3.${NC} 查看状态: ${YELLOW}./start.sh status${NC}"
    echo ""

    echo -e "${CYAN}━━━ 示例 ━━━${NC}"
    echo "  ./start.sh w                    # 交互式向导启动（推荐）"
    echo "  ./start.sh start base           # 启动所有基础中间件"
    echo "  ./start.sh start mem0           # 启动 Mem0（含依赖）"
    echo "  ./start.sh start pi-sandbox     # 启动 Pi Sandbox"
    echo "  ./start.sh start all            # 启动全部服务"
    echo "  ./start.sh stop all             # 停止所有服务"
    echo "  ./start.sh logs mem0            # 查看 Mem0 日志"
    echo "  ./start.sh status               # 查看状态"
    echo ""
}

# =============================================================================
# 主命令处理
# =============================================================================

resolve_service() {
    local input="$1"
    case "$input" in
        pg|postgres|post|postgresql) echo "postgresql" ;;
        rd|redis) echo "redis" ;;
        es|elastic|elasticsearch) echo "elasticsearch" ;;
        qd|qdrant) echo "qdrant" ;;
        n4j|neo4j|neo) echo "neo4j" ;;
        ol|ollama) echo "ollama" ;;
        m0|mem0|mem0-server) echo "mem0" ;;
        pi|pisandbox|pisb|pi-sandbox) echo "pi-sandbox" ;;
        base|all) echo "$input" ;;
        *) echo "$input" ;;
    esac
}

cmd_start() {
    local service
    service=$(resolve_service "${1:-}")

    ensure_env_file

    case "$service" in
        base)
            docker compose --env-file "${ENV_FILE}" -f "${MIDDLEWARE_DIR}/docker-compose.yml" -p proxyclaw-stack --profile base up --remove-orphans -d
            ;;
        mem0)
            start_mem0
            ;;
        pi-sandbox)
            start_pi_sandbox
            ;;
        all)
            docker compose --env-file "${ENV_FILE}" -f "${MIDDLEWARE_DIR}/docker-compose.yml" -p proxyclaw-stack --profile base up --remove-orphans -d
            sleep 5
            start_mem0
            sleep 3
            start_pi_sandbox
            print_success "全部服务已启动"
            ;;
        postgresql|redis|elasticsearch|qdrant|neo4j|ollama)
            docker compose --env-file "${ENV_FILE}" -f "${MIDDLEWARE_DIR}/docker-compose.yml" -p proxyclaw-stack up --remove-orphans -d "$service"
            ;;
        *)
            print_error "未知服务: $service"
            echo "可用服务: postgresql/pg, redis/rd, elasticsearch/es, qdrant/qd, neo4j/n4j, ollama/ol, mem0/m0, pi-sandbox/pi"
            exit 1
            ;;
    esac
}

cmd_logs() {
    local service
    service=$(resolve_service "${1:-}")
    local compose_file=""

    case "$service" in
        mem0)
            compose_file="${SERVICES_DIR}/mem0/docker-compose.yml"
            ;;
        pi-sandbox)
            compose_file="${SERVICES_DIR}/pi-sandbox/docker-compose.yml"
            ;;
        postgres|redis|elasticsearch|qdrant|neo4j|ollama)
            compose_file="${MIDDLEWARE_DIR}/docker-compose.yml"
            ;;
        *)
            print_error "请指定服务名"
            echo "可用服务: postgres/pg, redis/rd, elasticsearch/es, qdrant/qd, neo4j/n4j, ollama/ol, mem0/m0, pi-sandbox/pi"
            exit 1
            ;;
    esac

    if [ -n "$compose_file" ]; then
        docker compose --env-file "${ENV_FILE}" -f "$compose_file" logs -f "$service"
    fi
}

main() {
    local command="${1:-}"
    local arg="${2:-}"

    if [ -z "$command" ]; then
        show_help
        exit 0
    fi

    check_dependencies

    case "$command" in
        w|wizard)
            run_wizard
            ;;
        start)
            cmd_start "$arg"
            ;;
        stop)
            stop_service "$arg"
            ;;
        restart)
            stop_service "$arg"
            sleep 2
            cmd_start "$arg"
            ;;
        logs)
            cmd_logs "$arg"
            ;;
        status)
            show_status
            ;;
        health)
            show_health
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"