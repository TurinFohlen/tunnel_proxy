# `TunnelProxy.PTYGateway`

纯 BEAM 内部一次性 PTY 会话。
使用环境变量中的 Agent Token 直接认证，认证通过后动态分配端口并启动临时 PTY 服务器。
客户端 10 秒内 `nc localhost <port>` 即可进入 fish shell。

# `request_session`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
