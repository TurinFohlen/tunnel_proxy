# `TunnelProxy.PTYPool`

每个 agent_id 对应一个持久 ExPTY shell 进程。
shell 在 agent 首次 exec 时懒创建，exit 后自动从 pool 移除。

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `exec`

向 agent 的 PTY 会话提交命令，返回 {:ok, task_id} 或 {:error, :busy}

# `init`

# `kill`

强制终止 agent 的 shell 会话

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
