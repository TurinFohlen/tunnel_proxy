#!/bin/bash
# setup-frp.sh — 随机扫描 10 个可用端口并生成 FRP 配置

FRPC_CONFIG="$HOME/frpc.toml"

# 1. 扫描 10 个可用端口（在 30000-50000 范围内随机）
echo "正在扫描可用端口..."
AVAILABLE_PORTS=()
ATTEMPTS=0
MAX_ATTEMPTS=50

while [ ${#AVAILABLE_PORTS[@]} -lt 3 ] && [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  PORT=$((30000 + RANDOM % 20000))
  # 检查端口是否已被占用（本地）
  if ! ss -tlnp | grep -q ":$PORT "; then
    # 检查是否已在列表中
    if ! echo "${AVAILABLE_PORTS[@]}" | grep -qw "$PORT"; then
      AVAILABLE_PORTS+=($PORT)
      echo "  ✓ 端口 $PORT 可用"
    fi
  fi
  ATTEMPTS=$((ATTEMPTS + 1))
done

if [ ${#AVAILABLE_PORTS[@]} -lt 3 ]; then
  echo "❌ 未能找到 3 个可用端口，只找到 ${#AVAILABLE_PORTS[@]} 个"
  exit 1
fi

# 2. 随机选一个 HTTP 端口（从可用端口中）
HTTP_PORT=${AVAILABLE_PORTS[0]}

# 3. 生成 FRP 配置
UNIQUE_ID="tunnel-$(openssl rand -hex 4)"

cat > "$FRPC_CONFIG" << FRPC_EOF
serverAddr = "23.95.31.196"
serverPort = 7000
auth.token = "freefrp.net"

[[proxies]]
name = "${UNIQUE_ID}-api"
type = "tcp"
localIP = "127.0.0.1"
localPort = 8080
remotePort = $HTTP_PORT
FRPC_EOF

# 4. 添加 10 个 PTY 端口映射
for PORT in "${AVAILABLE_PORTS[@]}"; do
  cat >> "$FRPC_CONFIG" << FRPC_EOF

[[proxies]]
name = "${UNIQUE_ID}-pty-${PORT}"
type = "tcp"
localIP = "127.0.0.1"
localPort = $PORT
remotePort = $PORT
FRPC_EOF
done

# 5. 输出可用端口列表到文件，供 PTYGateway 读取
echo "${AVAILABLE_PORTS[*]}" | tr ' ' '\n' > priv/tunnel_ports.txt

echo ""
echo "✅ 配置已生成：$FRPC_CONFIG"
echo "📋 HTTP API:  frp.freefrp.net:$HTTP_PORT"
echo "📋 PTY 端口:  ${AVAILABLE_PORTS[*]}"
echo ""
echo "可用端口列表已保存到 priv/tunnel_ports.txt"
