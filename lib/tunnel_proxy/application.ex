defmodule TunnelProxy.Application do
  use Application

  def start(_type, _args) do
    port = Application.get_env(:tunnel_proxy, :http_port, 8080)

    children = [
      TunnelProxy.Cache,
      TunnelProxy.PTYPool,
      TunnelProxy.TaskQueue,
      TunnelProxy.TaskExecutor,
  
      {Bandit, plug: TunnelProxy.Router, port: port, scheme: :http}
    ]

    IO.puts(:stderr, "TunnelProxy — HTTP :#{port}")
    {:ok, sup} = Supervisor.start_link(children, strategy: :one_for_one, name: TunnelProxy.Supervisor)

    # 钩子1：从环境变量自动注册预设 Agent（支持多 Agent）
    TunnelProxy.AgentManager.init_preset_agent()

    # 钩子2：从环境变量控制注册锁
    if System.get_env("TUNNEL_LOCK_REGISTRATION") == "1" do
      TunnelProxy.AgentManager.lock_registration()
      IO.puts("[Application] 注册已锁定，禁止新 Agent 注册")
    end

    {:ok, sup}
  end
end
