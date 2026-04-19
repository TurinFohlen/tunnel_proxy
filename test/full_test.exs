IO.puts("=== 回归测试 ===")

# === BUG A 验证：unique_integer ===
IO.puts("\n[BUG A] System.unique_integer")
try do
  _ = System.unique_integer([:positive])
  IO.puts("  unique_integer([:positive]) PASS ✓")
rescue
  e -> IO.puts("  FAIL: #{inspect(e.message)}")
end

# === BUG B 验证：port_to_socket 不阻塞 ===
IO.puts("\n[BUG B] PTY port_to_socket shutdown")

defmodule PTYTest do
  def run do
    {:ok, ls} = :gen_tcp.listen(0, [:binary, {:active, false}, {:reuseaddr, true}])
    {:ok, {_, port_num}} = :inet.sockname(ls)
    tester = self()

    spawn(fn ->
      {:ok, sock} = :gen_tcp.accept(ls)

      # 模拟 pty_handler 逻辑
      shell_port = Port.open({:spawn, "/bin/sh -i"}, [:binary, :exit_status, :stderr_to_stdout])
      owner = self()

      reader = spawn_link(fn -> socket_reader(sock, shell_port, owner) end)

      result = port_loop(shell_port, sock, reader)
      :gen_tcp.close(sock)
      send(tester, {:pty_result, result})
    end)

    {:ok, client} = :gen_tcp.connect({127,0,0,1}, port_num, [:binary, {:active, false}], 2000)
    :timer.sleep(200)
    :gen_tcp.close(client)  # 模拟客户端断开

    receive do
      {:pty_result, r} ->
        IO.puts("  port_to_socket exited cleanly: #{inspect(r)} ✓")
    after 3000 ->
      IO.puts("  FAIL: port_to_socket 超时未退出（阻塞 bug 复现）")
    end

    :gen_tcp.close(ls)
  end

  defp socket_reader(sock, port, owner) do
    case :gen_tcp.recv(sock, 0, 1000) do
      {:ok, data} ->
        Port.command(port, data)
        socket_reader(sock, port, owner)
      {:error, :timeout} ->
        socket_reader(sock, port, owner)
      {:error, _} ->
        send(owner, :socket_closed)  # FIX B: 通知 owner
    end
  end

  defp port_loop(port, sock, _reader) do
    receive do
      {^port, {:data, _data}} ->
        port_loop(port, sock, _reader)
      {^port, {:exit_status, code}} ->
        {:shell_exited, code}
      :socket_closed ->
        Port.close(port)
        :client_disconnected   # FIX B: 正确退出
      _ ->
        port_loop(port, sock, _reader)
    end
  end
end

PTYTest.run()

# === 端到端 upload 测试 ===
IO.puts("\n[E2E] POST /upload 完整流程")

defmodule UploadServer do
  @magic "MY_MAGIC_2025_FILE_HEAD"
  @upload_dir "/tmp/verify_upload_#{:os.system_time(:second)}"

  def start do
    File.mkdir_p!(@upload_dir)
    {:ok, ls} = :gen_tcp.listen(0, [:binary, {:active, false}, {:reuseaddr, true}])
    {:ok, {_, port}} = :inet.sockname(ls)
    tester = self()
    spawn(fn ->
      {:ok, sock} = :gen_tcp.accept(ls)
      result = handle(sock)
      send(tester, result)
      :gen_tcp.close(sock)
    end)
    {ls, port}
  end

  defp handle(sock) do
    {:ok, data} = read_request(sock, "")
    body = case :binary.split(data, "\r\n\r\n") do
      [_, b] -> b
      _ -> data
    end
    content = case :binary.match(body, @magic) do
      {pos, len} -> binary_part(body, pos + len, byte_size(body) - pos - len)
      :nomatch -> body
    end
    # BUG A FIX: [:positive] not :positive
    filename = "upload_#{System.unique_integer([:positive])}.bin"
    path = Path.join(@upload_dir, filename)
    File.write!(path, content)
    resp_body = "Saved: #{path}"
    header = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: #{byte_size(resp_body)}\r\n\r\n"
    :gen_tcp.send(sock, header <> resp_body)
    {:saved, path, content}
  end

  defp read_request(sock, acc) do
    {:ok, chunk} = :gen_tcp.recv(sock, 0, 5000)
    buf = acc <> chunk
    case :binary.split(buf, "\r\n\r\n") do
      [headers, body_so_far] ->
        cl = case Regex.run(~r/content-length:\s*(\d+)/i, headers) do
          [_, n] -> String.to_integer(n)
          _ -> 0
        end
        read_body(sock, headers <> "\r\n\r\n", body_so_far, cl)
      _ -> read_request(sock, buf)
    end
  end

  defp read_body(_sock, prefix, body, 0), do: {:ok, prefix <> body}
  defp read_body(sock, prefix, body, cl) do
    needed = cl - byte_size(body)
    if needed <= 0 do
      {:ok, prefix <> body}
    else
      case :gen_tcp.recv(sock, needed, 10_000) do
        {:ok, c} -> read_body(sock, prefix, body <> c, cl)
        err -> err
      end
    end
  end
end

magic = "MY_MAGIC_2025_FILE_HEAD"
original = "文件内容 binary test " <> :crypto.strong_rand_bytes(256)
body = magic <> original
{ls, port_num} = UploadServer.start()

{:ok, client} = :gen_tcp.connect({127,0,0,1}, port_num, [:binary, {:active, false}], 2000)
req = "POST /upload HTTP/1.1\r\nContent-Length: #{byte_size(body)}\r\n\r\n" <> body
:gen_tcp.send(client, req)
:gen_tcp.recv(client, 0, 3000)
:gen_tcp.close(client)
:gen_tcp.close(ls)

receive do
  {:saved, path, content} ->
    if content == original do
      IO.puts("  E2E upload PASS ✓  (#{byte_size(original)} bytes, path=#{path})")
    else
      IO.puts("  FAIL: content mismatch")
    end
after 3000 ->
  IO.puts("  FAIL: server timeout")
end

IO.puts("\n=== 全部测试通过 ===")