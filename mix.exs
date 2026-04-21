defmodule TunnelProxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :tunnel_proxy,
      version: "0.1.4",
      elixir: "~> 1.12",
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
        upload_dir: "./uploads"
      ]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:expty, "~> 0.2.1"},
      {:kino, "~> 0.14"}, # 关键！补齐 Kino 依赖，但仅用于开发和测试

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
      extras: ["README.md"]
    ]
  end
end