defmodule TunnelProxy.Cache do
  use Nebulex.Cache,
    otp_app: :tunnel_proxy,
    adapter: Nebulex.Adapters.Local
end
