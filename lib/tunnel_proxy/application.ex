defmodule TunnelProxy.Application do
  use Application

  def start(_type, _args) do
    port = Application.get_env(:tunnel_proxy, :port, 8080)
    
    children = [
      {Task, fn -> TunnelProxy.Server.start(port) end}
    ]

    opts = [strategy: :one_for_one, name: TunnelProxy.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
