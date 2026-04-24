# `TunnelProxy.ResultCollector`

双哨兵·深度堆栈管理（极简固定哨兵）。

哨兵：
    左哨兵: ꧁
    右哨兵: ꧂

规则：
    - 每个哨兵在PTY输出中出现2次（回显 + 实际输出）。
    - 有效计数 = 出现次数 ÷ 2。
    - depth = 有效左 - 有效右。
    - depth: 0→1 开始收集，1→0 完成收集。
    - 使用字节级切片 (:binary.part) 避免 UTF-8 偏移问题。

# `collect`

# `get`

# `init_task`

# `sentinel_left`

# `sentinel_right`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
