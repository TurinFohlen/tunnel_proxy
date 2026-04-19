import Config

config :tunnel_proxy,
  port: String.to_integer(System.get_env("PROXY_PORT", "8080")),
  doc_root: System.get_env("DOC_PATH", "./www"),
  upload_path: System.get_env("UPLOAD_PATH", "./uploads")
