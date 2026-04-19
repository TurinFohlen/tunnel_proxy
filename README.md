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
    {:tunnel_proxy, "~> 0.1.0"}
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

With frp (Intranet Penetration)

```toml
# frpc.toml
[[proxies]]
name = "tunnel-http"
type = "tcp"
localIP = "127.0.0.1"
localPort = 8080
remotePort = 8080

[[proxies]]
name = "tunnel-shell"
type = "tcp"
localIP = "127.0.0.1"
localPort = 27417
remotePort = 27417
```

Then access from anywhere:

```bash
nc your-frp-server.com 27417
curl http://your-frp-server.com:8080/
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
    {:tunnel_proxy, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/tunnel_proxy>.