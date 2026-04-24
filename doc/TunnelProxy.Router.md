# `TunnelProxy.Router`

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

# `call`

# `init`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
