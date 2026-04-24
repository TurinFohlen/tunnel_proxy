# tunnel_proxy v0.3.3 - API Reference

## Modules

- [TunnelProxy.AgentManager](TunnelProxy.AgentManager.md): Agent 注册 / 认证 / 心跳
- [TunnelProxy.Cache](TunnelProxy.Cache.md)
- [TunnelProxy.PTYGateway](TunnelProxy.PTYGateway.md): 纯 BEAM 内部一次性 PTY 会话。
使用环境变量中的 Agent Token 直接认证，认证通过后动态分配端口并启动临时 PTY 服务器。
客户端 10 秒内 `nc localhost <port>` 即可进入 fish shell。

- [TunnelProxy.PTYPool](TunnelProxy.PTYPool.md): 每个 agent_id 对应一个持久 ExPTY shell 进程。
shell 在 agent 首次 exec 时懒创建，exit 后自动从 pool 移除。

- [TunnelProxy.ResultCollector](TunnelProxy.ResultCollector.md): 双哨兵·深度堆栈管理（极简固定哨兵）。
- [TunnelProxy.Router](TunnelProxy.Router.md): Bandit/Plug HTTP 路由。
- [TunnelProxy.TaskExecutor](TunnelProxy.TaskExecutor.md): GenStage 消费者：从队列拉取任务并交给 PTYPool 执行
- [TunnelProxy.TaskQueue](TunnelProxy.TaskQueue.md): GenStage 生产者：命令任务队列

- Core
  - [TunnelProxy.Application](TunnelProxy.Application.md)

