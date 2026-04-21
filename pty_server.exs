#!/usr/bin/env elixir

Mix.install([:expty])

defmodule PTYServer do
  def start(port \\ 27417) do
    {:ok, listen_sock} = :gen_tcp.listen(port, [:binary, {:active, false}, {:reuseaddr, true}])
    IO.puts("PTY Server listening on port #{port}")

    {:ok, sock} = :gen_tcp.accept(listen_sock)
    IO.puts("Client connected")

    # 启动 PTY
    {:ok, pty} = ExPTY.spawn("fish", [],
      name: "xterm-256color",
      cols: 80,
      rows: 24,
      on_data: fn _pty, _pid, data -> :gen_tcp.send(sock, data) end,
      on_exit: fn _pty, _pid, code, _sig -> 
        IO.puts("PTY exited with code #{code}")
        :gen_tcp.close(sock)
      end
    )

    # 转发客户端输入到 PTY
    spawn_link(fn -> client_to_pty(sock, pty) end)

    # 等待退出
    Process.sleep(:infinity)
  end

  defp client_to_pty(sock, pty) do
    case :gen_tcp.recv(sock, 0, 1000) do
      {:ok, data} ->
        ExPTY.write(pty, data)
        client_to_pty(sock, pty)
      {:error, :closed} ->
        :ok
      {:error, :timeout} ->
        client_to_pty(sock, pty)
    end
  end
end

PTYServer.start()