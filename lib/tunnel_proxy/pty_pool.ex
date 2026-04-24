defmodule TunnelProxy.PTYPool do
  @moduledoc """
  每个 agent_id 对应一个持久 ExPTY shell 进程。
  shell 在 agent 首次 exec 时懒创建，exit 后自动从 pool 移除。
  """

  use GenServer
  require Logger
  alias TunnelProxy.{Cache, ResultCollector}

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def init(_), do: {:ok, %{}}

  # ── 公开 API ───────────────────────────────────────────────────────────────

  @doc "向 agent 的 PTY 会话提交命令，返回 {:ok, task_id} 或 {:error, :busy}"
  def exec(agent_id, task_id, cmd) do
    GenServer.call(__MODULE__, {:exec, agent_id, task_id, cmd})
  end

  @doc "强制终止 agent 的 shell 会话"
  def kill(agent_id) do
    GenServer.cast(__MODULE__, {:kill, agent_id})
  end

  # ── GenServer 回调 ─────────────────────────────────────────────────────────

  def handle_call({:exec, agent_id, task_id, cmd}, _from, sessions) do
    Logger.info("PTYPool.exec: #{agent_id}, #{task_id}")
    if Cache.get("agent:current_task:#{agent_id}") do
      Logger.warning("Agent 正在执行其他任务: #{agent_id}")
      {:reply, {:error, :busy}, sessions}
    else
      {pty, new_sessions} = get_or_create(agent_id, sessions)
      ResultCollector.init_task(task_id)
      Cache.put("agent:current_task:#{agent_id}", task_id)
      command_line = "echo #{ResultCollector.sentinel_left()}; #{cmd}; echo #{ResultCollector.sentinel_right()}"
      Logger.info("写入 PTY: #{command_line}")
      ExPTY.write(pty, command_line <> "\n")

      {:reply, {:ok, task_id}, new_sessions}
    end
  end

  def handle_cast({:kill, agent_id}, sessions) do
    if pty = Map.get(sessions, agent_id), do: ExPTY.write(pty, "exit\n")
    {:noreply, Map.delete(sessions, agent_id)}
  end

  def handle_cast({:remove, agent_id}, sessions) do
    {:noreply, Map.delete(sessions, agent_id)}
  end

  # ── 内部函数 ───────────────────────────────────────────────────────────────

  defp get_or_create(agent_id, sessions) do
    case Map.get(sessions, agent_id) do
      nil ->
        shell = System.find_executable("sh") || "/bin/sh"
        {:ok, pty} = ExPTY.spawn(shell, [],
          name: "xterm-256color",
          cols: 200,
          rows: 50,
          on_data: fn _pty, _pid, data ->
            ResultCollector.collect(agent_id, data)
          end,
          on_exit: fn _pty, _pid, _code, _sig ->
            GenServer.cast(__MODULE__, {:remove, agent_id})
          end
        )
        {pty, Map.put(sessions, agent_id, pty)}

      pty -> {pty, sessions}
    end
  end

end
