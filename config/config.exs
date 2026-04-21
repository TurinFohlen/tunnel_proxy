import Config

config :tunnel_proxy,
  http_port: String.to_integer(System.get_env("PROXY_PORT", "8080")),
  doc_root: System.get_env("DOC_PATH", "./www"),
  upload_dir: System.get_env("UPLOAD_PATH", "./uploads")

config :expty, :use_precompiled, true