defmodule TunnelProxy.Router do
  @moduledoc """
  Bandit/Plug HTTP 路由。

  Agent API：
    POST /api/register        注册 agent，返回 token
    POST /api/heartbeat       心跳保活
    POST /api/exec            提交命令，返回 task_id
    GET  /api/result/:task_id 轮询执行结果
    GET  /api/agents          列出所有 agent（管理用）
    DELETE /api/agents/:id    强制终止 agent 的 shell

  文件服务器（保留原有功能）：
    GET  /upload              上传页面
    POST /upload              二进制上传（magic-word 协议）
    GET  /proxy?url=...       HTTP 反向代理
    GET  /*                   静态文件 / 目录列表
  """

  use Plug.Router
  require Logger

  plug Plug.Logger
  plug :match
  plug Plug.Parsers,
    parsers: [:json, :urlencoded],
    pass: ["application/octet-stream"],
    json_decoder: Jason
  plug :dispatch

  # =========================================================
  # Agent API
  # =========================================================
  
  post "/api/register" do
    with %{"agent_id" => agent_id} <- conn.body_params,
         {:ok, session, token}     <- TunnelProxy.AgentManager.register(agent_id, conn.body_params)
    do
      json(conn, 200, %{ok: true, session: session, token: token})
    else
      {:error, :registration_locked} ->
        json(conn, 403, %{error: "registration is locked"})
      _ ->
        json(conn, 400, %{error: "agent_id required"})
    end
  end
  post "/api/heartbeat" do
    with %{"agent_id" => aid, "token" => tok} <- conn.body_params,
         {:ok, session} <- TunnelProxy.AgentManager.heartbeat(aid, tok)
    do
      json(conn, 200, %{ok: true, session: session})
    else
      {:error, :not_found}    -> json(conn, 404, %{error: "agent not found"})
      {:error, :unauthorized} -> json(conn, 401, %{error: "unauthorized"})
      _                       -> json(conn, 400, %{error: "agent_id and token required"})
    end
  end

  post "/api/exec" do
    with %{"agent_id" => aid, "token" => tok, "cmd" => cmd} <- conn.body_params,
         {:ok, _session} <- TunnelProxy.AgentManager.authenticate(aid, tok)
    do
      task_id = "#{aid}_#{System.unique_integer([:positive, :monotonic])}"
      TunnelProxy.TaskQueue.push(%{agent_id: aid, task_id: task_id, cmd: cmd})
      json(conn, 200, %{ok: true, task_id: task_id})
    else
      {:error, :not_found}    -> json(conn, 404, %{error: "agent not found"})
      {:error, :unauthorized} -> json(conn, 401, %{error: "unauthorized"})
      _                       -> json(conn, 400, %{error: "agent_id, token, and cmd required"})
    end
  end

  get "/api/result/:task_id" do
    case TunnelProxy.ResultCollector.get(task_id) do
      nil    -> json(conn, 404, %{error: "task not found"})
      result -> json(conn, 200, result)
    end
  end

  get "/api/agents" do
    json(conn, 200, TunnelProxy.AgentManager.list_all())
  end

  delete "/api/agents/:agent_id" do
    TunnelProxy.PTYPool.kill(agent_id)
    json(conn, 200, %{ok: true})
  end
post "/api/session" do
  with %{"token" => token} <- conn.body_params,
       {:ok, port} <- TunnelProxy.PTYGateway.request_session(token) do
    json(conn, 200, %{ok: true, port: port})
  else
    {:error, :invalid_token} ->
      json(conn, 403, %{error: "invalid token"})
    _ ->
      json(conn, 400, %{error: "token required"})
  end
end
  # =========================================================
  # 文件服务器
  # =========================================================

  get "/upload" do
    magic = magic_word()
    html = """
    <!DOCTYPE html>
    <html><head><meta charset="utf-8"><title>Upload</title></head>
    <body>
      <input type="file" id="f">
      <button onclick="up()">Upload</button>
      <p>Magic: <code>#{magic}</code></p>
      <script>
        const MAGIC = "#{magic}";
        async function up() {
          const file = document.getElementById('f').files[0];
          if (!file) return;
          const enc  = new TextEncoder().encode(MAGIC);
          const buf  = new Uint8Array(enc.length + file.size);
          buf.set(enc); buf.set(new Uint8Array(await file.arrayBuffer()), enc.length);
          fetch("/upload", {method:"POST", body:buf, headers:{"Content-Type":"application/octet-stream"}})
            .then(r => r.text()).then(alert);
        }
      </script>
    </body></html>
    """
    conn |> Plug.Conn.put_resp_content_type("text/html") |> Plug.Conn.send_resp(200, html)
  end

  post "/upload" do
    {:ok, body, conn} = Plug.Conn.read_body(conn, length: 2_147_483_647)
    magic = magic_word()

    content = case :binary.match(body, magic) do
      {pos, len} ->
        start = pos + len
        binary_part(body, start, byte_size(body) - start)
      :nomatch ->
        case :binary.split(body, "\r\n\r\n") do
          [_, rest] -> rest
          _         -> body
        end
    end

    dir  = upload_dir()
    File.mkdir_p!(dir)
    name = "upload_#{System.unique_integer([:positive])}.bin"
    path = Path.join(dir, name)
    File.write!(path, content)
    Plug.Conn.send_resp(conn, 200, "Saved: #{path}")
  end

  get "/proxy" do
    url = Map.get(conn.query_params, "url", "") |> URI.decode()

    if String.starts_with?(url, "http") do
      hdrs = [{~c"User-Agent", ~c"Mozilla/5.0"}, {~c"Accept", ~c"*/*"}]
      case :httpc.request(:get, {String.to_charlist(url), hdrs}, [{:timeout, 15_000}], [{:body_format, :binary}]) do
        {:ok, {{_, 200, _}, _, body}} ->
          conn |> Plug.Conn.put_resp_content_type("application/octet-stream") |> Plug.Conn.send_resp(200, body)
        {:ok, {{_, status, _}, _, _}} ->
          Plug.Conn.send_resp(conn, status, "HTTP #{status}")
        {:error, reason} ->
          Plug.Conn.send_resp(conn, 502, "Bad gateway: #{inspect(reason)}")
      end
    else
      Plug.Conn.send_resp(conn, 400, "Invalid URL")
    end
  end

  match _ do
    serve_file(conn, conn.request_path)
  end

  # =========================================================
  # 内部工具
  # =========================================================

  defp json(conn, status, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, Jason.encode!(body))
  end

  defp serve_file(conn, path) do
    decoded = URI.decode(path)
    root    = doc_root()
    full    = Path.expand(Path.join(root, decoded))

    cond do
      not String.starts_with?(full, root) ->
        Plug.Conn.send_resp(conn, 403, "Access denied")

      File.dir?(full) ->
        html = list_directory(full, root)
        conn |> Plug.Conn.put_resp_content_type("text/html") |> Plug.Conn.send_resp(200, html)

      File.regular?(full) ->
        {:ok, content} = File.read(full)
        conn |> Plug.Conn.put_resp_content_type("application/octet-stream") |> Plug.Conn.send_resp(200, content)

      true ->
        Plug.Conn.send_resp(conn, 404, "Not found")
    end
  end

  defp list_directory(dir, root) do
    links =
      File.ls!(dir)
      |> Enum.map(fn f ->
        full    = Path.join(dir, f)
        rel     = Path.relative_to(full, root)
        encoded = URI.encode(rel)
        if File.dir?(full),
          do:   "<li>📁 <a href=\"/#{encoded}/\">#{f}/</a></li>",
          else: "<li>📄 <a href=\"/#{encoded}\">#{f}</a></li>"
      end)

    """
    <!DOCTYPE html><body>
      <ul>#{Enum.join(links)}</ul>
      <hr><a href="/upload">Upload</a> | <a href="/">Root</a>
    </body></html>
    """
  end

  defp doc_root do
    (System.get_env("TUNNEL_DOC_ROOT") || Application.get_env(:tunnel_proxy, :doc_root, "./www"))
    |> Path.expand()
  end

  defp upload_dir do
    (System.get_env("TUNNEL_UPLOAD_DIR") || Application.get_env(:tunnel_proxy, :upload_dir, "./uploads"))
    |> Path.expand()
  end

  defp magic_word, do: System.get_env("UPLOAD_MAGIC", "MY_MAGIC_2025_FILE_HEAD")
end
