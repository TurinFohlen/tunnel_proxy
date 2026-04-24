defmodule TunnelProxy.PTYGateway do
  @moduledoc """
  纯 BEAM 内部一次性 PTY 会话。
  使用环境变量中的 Agent Token 直接认证，认证通过后动态分配端口并启动临时 PTY 服务器。
  客户端 10 秒内 `nc localhost <port>` 即可进入 bash shell。
  """

  require Logger

  # ---- 公开 API ----
  def request_session(agent_token) do
    with {:ok, agent_id} <- verify_token(agent_token),
         port = random_port(),
         init_cmd = build_init_cmd(agent_id),
         :ok <- spawn_pty_server(port, init_cmd) do
      {:ok, port}
    end
  end

  # ---- 私有函数 ----

  # 从环境变量中匹配 Token（直接读取 TUNNEL_TOKEN_* 变量）
  defp verify_token(token) do
    result =
      Enum.find_value(System.get_env(), fn
        {"TUNNEL_TOKEN_" <> agent_id, val} when val == token -> {:ok, agent_id}
        _ -> nil
      end)

    result || {:error, :invalid_token}
  end

  defp random_port, do: :rand.uniform(35000) + 30000
  defp build_init_cmd(_agent_id), do: "stty -echo; clear; export PS1='\\w > '"
  defp spawn_pty_server(port, init_cmd) do
    spawn(fn -> pty_server(port, init_cmd) end)
    Logger.info("PTY 临时服务器已孵化，端口: #{port}，10 秒内未连接将自动关闭")
    :ok
  end

  # ---- 一次性 PTY 服务器进程 ----
defp pty_server(port, init_cmd) do
  listen_opts = [:binary, {:active, false}, {:reuseaddr, true}]
  case :gen_tcp.listen(port, listen_opts) do
    {:ok, listen_sock} ->
      timer = Process.send_after(self(), :timeout, 10_000)
      case :gen_tcp.accept(listen_sock, 10_000) do
        {:ok, sock} ->
          Process.cancel_timer(timer)
          :gen_tcp.close(listen_sock)

          {:ok, pty} = ExPTY.spawn("/bin/bash", [],
            name: "xterm-256color",
            cols: 200, rows: 50,
            on_data: fn _pty, _pid, data -> :gen_tcp.send(sock, data) end,
            on_exit: fn _pty, _pid, _code, _sig -> :gen_tcp.close(sock) end
          )

          if init_cmd, do: ExPTY.write(pty, init_cmd <> "\n")

          spawn_link(fn -> client_to_pty(sock, pty) end)
          Process.sleep(:infinity)

        {:error, :timeout} ->
          Logger.info("PTY 服务器端口 #{port} 超时未连接，已关闭")
          :gen_tcp.close(listen_sock)
        {:error, _} ->
          :gen_tcp.close(listen_sock)
      end

    {:error, _} -> :ok
  end
end

defp client_to_pty(sock, pty) do
  case :gen_tcp.recv(sock, 0, 1000) do
    {:ok, data} -> ExPTY.write(pty, data); client_to_pty(sock, pty)
    {:error, :closed} -> :ok
    {:error, :timeout} -> client_to_pty(sock, pty)
  end
end

end
