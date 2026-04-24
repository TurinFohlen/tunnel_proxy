defmodule TunnelProxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :tunnel_proxy,
      version: "0.3.3",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "HTTP Server + PTY Shell Forwarder",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl],
      mod: {TunnelProxy.Application, []},
      env: [
        http_port: 8080,
        pty_port: 27417,
        doc_root: "./www",
        upload_dir: "./uploads",
        session_ttl: 3600  # 会话空闲超时（秒）
      ]
    ]
  end

  defp deps do
    [
      # 核心 PTY
      {:expty, "~> 0.2.1"},
      
      # 分布式缓存（多 Agent 会话管理）
      {:nebulex, "~> 2.0"},
      {:shards, "~> 1.0"},
      
      # 任务队列（异步命令执行）
      {:gen_stage, "~> 1.2"},
      
      # HTTP API 和 JSON
      {:bandit, "~> 1.5"},
      {:plug, "~> 1.15"},
      {:jason, "~> 1.4"},
      
      # 认证
      {:bcrypt_elixir, "~> 3.0"},
      
      # 持久化存储（可选）
      {:ecto_sqlite3, "~> 0.10"},
      {:ecto, "~> 3.9"},
      
      # 开发工具
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:kino, "~> 0.14", only: [:dev, :test]}
    ]
  end


  defp package do
    [
      name: "tunnel_proxy",
      files: ["lib", "mix.exs", "README.md", "LICENSE", ".formatter.exs"],
      maintainers: ["TurinFohlen"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/TurinFohlen/tunnel_proxy"}
    ]
  end

  defp docs do
    [
      main: "TunnelProxy",
      extras: ["README.md"],
      groups_for_modules: [
        "Core": [
          TunnelProxy,
          TunnelProxy.Application,
          TunnelProxy.Server
        ],
        "Session Management": [
          TunnelProxy.SessionAgent,
          TunnelProxy.SessionSupervisor,
          TunnelProxy.SessionRegistry
        ],
        "PTY Integration": [
          TunnelProxy.PTY,
          TunnelProxy.StreamHandler
        ]
      ]
    ]
  end
end