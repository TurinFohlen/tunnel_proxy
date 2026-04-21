defmodule TunnelProxy.Server do
  @moduledoc """
  TunnelProxy HTTP Server + PTY Forwarder
  """
  
  use GenServer
  @max_body_size 2_147_483_647
  
  defp doc_root do
    path = System.get_env("TUNNEL_DOC_ROOT") || Application.get_env(:tunnel_proxy, :doc_root)
    if path do
      Path.expand(path)
    else
      raise "TUNNEL_DOC_ROOT environment variable or :doc_root config must be set"
    end
  end
  
  defp upload_dir do
    path = System.get_env("TUNNEL_UPLOAD_DIR") || Application.get_env(:tunnel_proxy, :upload_dir)
    if path do
      Path.expand(path)
    else
      raise "TUNNEL_UPLOAD_DIR environment variable or :upload_dir config must be set"
    end
  end
  
  defp pty_port do
    val = System.get_env("TUNNEL_PTY_PORT") || Application.get_env(:tunnel_proxy, :pty_port) || 27417
    if is_binary(val), do: String.to_integer(val), else: val
  end
    
  def start(port) do
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end

  def init(http_port) do
    {:ok, http_ls} = :gen_tcp.listen(http_port, [:binary, {:active, false}, {:reuseaddr, true}])
    {:ok, pty_ls} = :gen_tcp.listen(pty_port(), [:binary, {:active, false}, {:reuseaddr, true}])
    
    IO.puts(:stderr, "HTTP Server: 0.0.0.0:#{http_port}")
    IO.puts(:stderr, "PTY Forwarder: 0.0.0.0:#{pty_port()}")
    IO.puts(:stderr, "Doc Root: #{doc_root()}")
    IO.puts(:stderr, "Upload Dir: #{upload_dir()}")
    
    spawn_link(fn -> http_accept_loop(http_ls) end)
    spawn_link(fn -> pty_accept_loop(pty_ls) end)
    
    {:ok, %{http: http_ls, pty: pty_ls}}
  end

  # ========== PTY (ExPTY 实现) ==========
  defp pty_accept_loop(ls) do
    {:ok, sock} = :gen_tcp.accept(ls)
    spawn_link(fn -> pty_handler(sock) end)
    pty_accept_loop(ls)
  end

  defp pty_handler(sock) do
    shell = System.get_env("SHELL") || "/bin/sh"

    {:ok, pty} = ExPTY.spawn(shell, [],
      name: "xterm-256color",
      cols: 80,
      rows: 24,
      on_data: fn _pty, _pid, data -> :gen_tcp.send(sock, data) end,
      on_exit: fn _pty, _pid, _code, _sig -> :gen_tcp.close(sock) end
    )

    socket_to_pty(sock, pty)
  rescue
    _ -> :ok
  after
    :gen_tcp.close(sock)
  end

  defp socket_to_pty(sock, pty) do
    case :gen_tcp.recv(sock, 0, 1000) do
      {:ok, data} ->
        ExPTY.write(pty, data)
        socket_to_pty(sock, pty)
      {:error, :timeout} ->
        socket_to_pty(sock, pty)
      {:error, _} ->
        :ok
    end
  end

  # ========== HTTP ==========
  defp http_accept_loop(ls) do
    {:ok, sock} = :gen_tcp.accept(ls)
    spawn_link(fn -> handle_client(sock) end)
    http_accept_loop(ls)
  end

  defp handle_client(sock) do
    case read_http_request(sock) do
      {:ok, data} when byte_size(data) <= @max_body_size ->
        process_request(sock, data)
      {:ok, _data} ->
        send_response(sock, 413, "text/plain", "Request too large")
      _ -> :ok
    end
    :gen_tcp.close(sock)
  rescue
    error -> IO.puts(:stderr, "Error: #{inspect(error)}")
  end

  defp read_http_request(sock), do: read_until_headers(sock, "")

  defp read_until_headers(sock, acc) do
    case :gen_tcp.recv(sock, 0, 30_000) do
      {:ok, chunk} ->
        buf = acc <> chunk
        case :binary.split(buf, "\r\n\r\n") do
          [headers, body_so_far] ->
            content_length = parse_content_length(headers)
            read_body(sock, headers <> "\r\n\r\n", body_so_far, content_length)
          _ ->
            read_until_headers(sock, buf)
        end
      {:error, reason} -> {:error, reason}
    end
  end

  defp read_body(_sock, prefix, body, 0), do: {:ok, prefix <> body}
  defp read_body(sock, prefix, body, content_length) do
    needed = content_length - byte_size(body)
    if needed <= 0 do
      {:ok, prefix <> body}
    else
      case :gen_tcp.recv(sock, needed, 60_000) do
        {:ok, chunk} -> read_body(sock, prefix, body <> chunk, content_length)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp parse_content_length(headers) do
    case Regex.run(~r/content-length:\s*(\d+)/i, headers) do
      [_, n] -> String.to_integer(n)
      _ -> 0
    end
  end

  defp process_request(sock, data) do
    [method | rest] = String.split(data, " ", parts: 3)
    path = if length(rest) >= 2, do: Enum.at(rest, 0), else: "/"

    cond do
      method == "GET" and path == "/upload"  -> handle_upload_page(sock)
      method == "POST" and path == "/upload" -> handle_magic_upload(sock, data)
      method == "GET" and String.starts_with?(path, "/proxy?url=") -> handle_proxy(sock, path)
      method == "GET" -> handle_file_or_dir(sock, path)
      true -> send_response(sock, 400, "text/plain", "Bad request")
    end
  end

  defp handle_upload_page(sock) do
    magic = magic_word()
    html = """
    <!DOCTYPE html>
    <html>
    <head><meta charset="utf-8"><title>Upload</title></head>
    <body>
      <input type="file" id="f"><button onclick="up()">Upload</button>
      <p>Magic Word: <code>#{magic}</code></p>
      <script>
        const MAGIC = "#{magic}";
        async function up(){
          const file = document.getElementById('f').files[0];
          if(!file) return;
          const magic = new TextEncoder().encode(MAGIC);
          const data = new Uint8Array(magic.length + file.size);
          data.set(magic, 0);
          data.set(new Uint8Array(await file.arrayBuffer()), magic.length);
          fetch("/upload", {method:"POST", body:data, headers:{"Content-Type":"application/octet-stream"}})
            .then(r=>r.text()).then(alert);
        }
      </script>
    </body>
    </html>
    """
    send_response(sock, 200, "text/html", html)
  end

  defp handle_magic_upload(sock, data) do
    magic = magic_word()

    content = case :binary.match(data, magic) do
      {pos, len} ->
        start = pos + len
        binary_part(data, start, byte_size(data) - start)
      :nomatch ->
        case :binary.split(data, "\r\n\r\n") do
          [_, body] -> body
          _ -> data
        end
    end

    File.mkdir_p!(upload_dir())
    filename = "upload_#{System.unique_integer([:positive])}.bin"
    full_path = Path.join(upload_dir(), filename)
    File.write!(full_path, content)

    send_response(sock, 200, "text/plain", "Saved: #{full_path}")
  end

  defp magic_word do
    System.get_env("UPLOAD_MAGIC", "MY_MAGIC_2025_FILE_HEAD")
  end

  defp handle_proxy(sock, path) do
    url = String.trim_leading(path, "/proxy?url=") |> URI.decode()

    if String.starts_with?(url, "http") do
      headers = [
        {~c"User-Agent", ~c"Mozilla/5.0"},
        {~c"Accept", ~c"*/*"}
      ]
      case :httpc.request(:get, {String.to_charlist(url), headers}, [{:timeout, 15000}], [{:body_format, :binary}]) do
        {:ok, {{_, 200, _}, _, body}} ->
          send_response(sock, 200, "application/octet-stream", body)
        {:ok, {{_, status, _}, _, _body}} ->
          send_response(sock, status, "text/plain", "HTTP #{status}")
        {:error, reason} ->
          send_response(sock, 502, "text/plain", "Bad gateway: #{inspect(reason)}")
      end
    else
      send_response(sock, 400, "text/plain", "Invalid URL")
    end
  end

  defp handle_file_or_dir(sock, path) do
    decoded = URI.decode(path)
    full = Path.expand(Path.join(doc_root(), decoded))

    cond do
      not String.starts_with?(full, doc_root()) ->
        send_response(sock, 403, "text/plain", "Access denied")
      File.dir?(full) ->
        send_response(sock, 200, "text/html", list_directory(full))
      File.regular?(full) ->
        {:ok, content} = File.read(full)
        send_response(sock, 200, "application/octet-stream", content)
      true ->
        send_response(sock, 404, "text/plain", "Not found")
    end
  end

  defp list_directory(dir) do
    files = File.ls!(dir)
    links = Enum.map(files, fn f ->
      full = Path.join(dir, f)
      rel = Path.relative_to(full, doc_root())
      encoded = URI.encode(rel)
      if File.dir?(full) do
        "<li>📁 <a href=\"/#{encoded}/\">#{f}/</a></li>"
      else
        "<li>📄 <a href=\"/#{encoded}\">#{f}</a></li>"
      end
    end)
    """
    <!DOCTYPE html>
    <body>
      <ul>#{Enum.join(links)}</ul>
      <hr>
      <a href="/upload">Upload</a> | <a href="/">Root</a>
    </body>
    </html>
    """
  end

  defp send_response(sock, code, content_type, body) do
    status = case code do
      200 -> "OK"
      400 -> "Bad Request"
      403 -> "Forbidden"
      404 -> "Not Found"
      413 -> "Payload Too Large"
      502 -> "Bad Gateway"
      _ -> "Unknown"
    end
    header = "HTTP/1.1 #{code} #{status}\r\nContent-Type: #{content_type}\r\nContent-Length: #{byte_size(body)}\r\n\r\n"
    :gen_tcp.send(sock, header <> body)
  end
end