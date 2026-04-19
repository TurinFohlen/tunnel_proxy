import Config

config :tunnel_proxy,
  port: String.to_integer(System.get_env("PORT", "8080"))
