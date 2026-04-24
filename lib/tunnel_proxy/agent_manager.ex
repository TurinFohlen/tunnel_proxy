defmodule TunnelProxy.AgentManager do
  @moduledoc "Agent 注册 / 认证 / 心跳"

  alias TunnelProxy.Cache

  @index_key "agent:index"
  @lock_key "agent:registration_locked"

  # ── 钩子 1：从环境变量自动注册预设 Agent ─────────────────────────────────
  def init_preset_agent do
    # 方案 A：逗号分隔列表（优先级最高）
    case System.get_env("TUNNEL_PRESET_AGENTS") do
      nil -> :ok
      ""  -> :ok
      list ->
        list
        |> String.split(",")
        |> Enum.each(&register_preset/1)
    end

    # 方案 B：编号变量 TUNNEL_PRESET_AGENT_1, _2, ...
    Stream.iterate(1, &(&1 + 1))
    |> Stream.map(fn n -> System.get_env("TUNNEL_PRESET_AGENT_#{n}") end)
    |> Stream.take_while(&(&1 != nil))
    |> Enum.each(&register_preset/1)

    # 方案 C：单变量（向后兼容）
    case System.get_env("TUNNEL_PRESET_AGENT") do
      nil -> :ok
      ""  -> :ok
      config -> register_preset(config)
    end
  end

  defp register_preset(config) do
    case String.split(config, ":") do
      [agent_id, hostname, username, os] ->
        metadata = %{
          "hostname" => hostname,
          "username" => username,
          "os" => os
        }
        case register(agent_id, metadata) do
          {:ok, _session, token} ->
            IO.puts("[AgentManager] Preset agent registered: #{agent_id}")
            IO.puts("[AgentManager] Token: #{token}")
          {:error, reason} ->
            IO.puts(:stderr, "[AgentManager] Preset agent #{agent_id} failed: #{reason}")
        end
      _ ->
        IO.puts(:stderr, "[AgentManager] Invalid preset format, expect 'id:host:user:os', got: #{config}")
    end
  end

  # ── 钩子 2：注册锁 ───────────────────────────────────────────────────────
  def lock_registration, do: Cache.put(@lock_key, true)
  def unlock_registration, do: Cache.delete(@lock_key)
  def registration_locked?, do: Cache.get(@lock_key) == true

  # ── 注册（带锁检查）──────────────────────────────────────────────────────
  def register(agent_id, metadata) do
    if registration_locked?() do
      {:error, :registration_locked}
    else
      token      = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      token_hash = Bcrypt.hash_pwd_salt(token)

      session = %{
        id:               agent_id,
        hostname:         Map.get(metadata, "hostname", "unknown"),
        username:         Map.get(metadata, "username", "unknown"),
        os:               Map.get(metadata, "os", "unknown"),
        registered_at:    utc_now(),
        last_heartbeat:   utc_now(),
        token_hash:       token_hash,
        status:           "online"
      }

      Cache.put("agent:session:#{agent_id}", session)
      add_to_index(agent_id)

      # Export token to environment variable
      env_name = "TUNNEL_TOKEN_#{String.upcase(agent_id)}"
      System.put_env(env_name, token)

      {:ok, public(session), token}
    end
  end

  # ── 认证 ──────────────────────────────────────────────────────────────────
  def authenticate(agent_id, token) do
    case Cache.get("agent:session:#{agent_id}") do
      nil     -> {:error, :not_found}
      session ->
        if Bcrypt.verify_pass(token, session.token_hash),
          do:   {:ok, session},
          else: {:error, :unauthorized}
    end
  end

  # ── 心跳 ──────────────────────────────────────────────────────────────────
  def heartbeat(agent_id, token) do
    with {:ok, session} <- authenticate(agent_id, token) do
      updated = %{session | last_heartbeat: utc_now(), status: "online"}
      Cache.put("agent:session:#{agent_id}", updated)
      {:ok, public(updated)}
    end
  end

  # ── 列出所有 Agent ─────────────────────────────────────────────────────────
  def list_all do
    (Cache.get(@index_key) || [])
    |> Enum.flat_map(fn id ->
      case Cache.get("agent:session:#{id}") do
        nil -> []
        s   -> [public(s)]
      end
    end)
  end

  # ── 内部 ──────────────────────────────────────────────────────────────────
  defp add_to_index(agent_id) do
    ids = Cache.get(@index_key) || []
    Cache.put(@index_key, Enum.uniq([agent_id | ids]))
  end

  defp public(session), do: Map.delete(session, :token_hash)

  defp utc_now, do: DateTime.utc_now() |> DateTime.to_iso8601()
end
