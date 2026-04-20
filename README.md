# TunnelProxy

HTTP Server + PTY Shell Forwarder - A lightweight all-in-one tool for file serving, remote shell, and file upload.

## Features

| Feature | Port | Description |
|---------|------|-------------|
| Static File Server | 8080 | Browse and download files with directory listing |
| PTY Shell Forwarder | 27417 | Interactive shell via `nc` connection |
| File Upload | 8080/upload | Upload via web page or curl command |

## Installation

### Option 1: Install from Hex

```elixir
def deps do
  [
    {:tunnel_proxy, "~> 0.1.3"}
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
export TUNNEL_DOC_ROOT="your/root/path"
export TUNNEL_UPLOAD_DIR="your/upload/path"
mkdir -p "$TUNNEL_DOC_ROOT" "$TUNNEL_UPLOAD_DIR"
mix run --no-halt -e "TunnelProxy.Server.start(8080)"
```

Expected output:

```
HTTP Server: 0.0.0.0:8080
PTY Forwarder: 0.0.0.0:27417
Doc Root: /path/to/current/www
Upload Dir: /path/to/current/uploads
```

Connect to Shell

```bash
nc 127.0.0.1 27417
```

Type commands and get output:

```bash
$ pwd
/path/to/current
$ ls -la
...file list...
$ exit
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

Configuration

Create config/config.exs or set environment variables:

```elixir
config :tunnel_proxy,
  http_port: 8080,           # HTTP server port
  pty_port: 27417,           # Shell forwarder port
  doc_root: "./www",         # Static files directory
  upload_dir: "./uploads"    # Upload destination
```

Environment variables:

Variable Default Description
SHELL /bin/sh Shell to use for PTY forwarder
UPLOAD_MAGIC MY_MAGIC_2025_FILE_HEAD Magic word for upload validation

Use Cases

Termux / Android

```bash
cd /sdcard/Download/tunnel_proxy
mix run --no-halt -e "TunnelProxy.Server.start(8080)"
```

## With frp (Intranet Penetration)

Create a setup script that generates a secure, unique FRP configuration:

```bash
cat > setup-frp.sh << 'SETUP_EOF'
#!/bin/bash
# setup-frp.sh - Generate frpc.toml with a unique hash name

FRPC_CONFIG="frpc.toml"

# Generate 256-bit random name
PROXY_NAME="tunnel-$(openssl rand -hex 32)"

# Random high ports (49152-65535)
HTTP_PORT=$((10001 + RANDOM % 40000))
SHELL_PORT=$((10001 + RANDOM % 40000))
while [ $SHELL_PORT -eq $HTTP_PORT ]; do
    SHELL_PORT=$((10001 + RANDOM % 40000))
done

# Write config with variable expansion (note: no quotes around EOF)
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
echo "   Proxy name prefix: $PROXY_NAME"
echo ""
echo "📋 Connection info (save these):"
echo "   HTTP:  frp.freefrp.net:$HTTP_PORT"
echo "   Shell: frp.freefrp.net:$SHELL_PORT"
echo ""
echo "🎲 Your service is now invisible to scanners."
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


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `tunnel_proxy` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tunnel_proxy, "~> 0.1.3"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/tunnel_proxy>.