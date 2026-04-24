defmodule TunnelProxy.ResultCollector do
  @moduledoc """
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
  """

  alias TunnelProxy.Cache

  @left  "꧁"
  @right "꧂"

  def sentinel_left,  do: @left
  def sentinel_right, do: @right

  # 公开 API ---------------------------------------------------------------
  def init_task(task_id) do
    Cache.put("result:#{task_id}", %{
      status: "idle",
      depth: 0,
      start_byte: nil
    })
    Cache.put("result:#{task_id}:buffer", "")
  end

  def collect(agent_id, data) do
    case Cache.get("agent:current_task:#{agent_id}") do
      nil -> :ok
      task_id -> process_data(agent_id, task_id, data)
    end
  end

  def get(task_id) do
    case Cache.get("result:#{task_id}") do
      %{status: "complete"} = res -> %{output: res.output, status: "complete"}
      %{status: status}           -> %{output: "", status: status}
      nil                         -> nil
    end
  end

  # 核心逻辑 ---------------------------------------------------------------
  defp process_data(agent_id, task_id, data) do
    buf_key = "result:#{task_id}:buffer"
    res_key = "result:#{task_id}"

    buffer = Cache.get(buf_key) || ""
    new_buf = buffer <> data

    raw_l = count_occurrences(new_buf, @left)
    raw_r = count_occurrences(new_buf, @right)

    eff_l = div(raw_l, 2)
    eff_r = div(raw_r, 2)

    depth = eff_l - eff_r

    current = Cache.get(res_key) || %{
      status: "idle",
      depth: 0,
      start_byte: nil
    }

    cond do
      current.status == "idle" and depth == 1 ->
        activate_collecting(res_key, buf_key, current, new_buf)

      current.status == "collecting" and depth == 0 ->
        finalize_output(agent_id, res_key, buf_key, current, new_buf)

      true ->
        new_state = %{current | depth: depth}
        Cache.put(res_key, new_state)
        Cache.put(buf_key, new_buf)
    end
  end

  defp activate_collecting(res_key, buf_key, current, buffer) do
    # 第2次出现（即实际输出）的字节位置
    byte_pos = find_byte_pos(buffer, @left, 2)
    start_byte = byte_pos + byte_size(@left)

    new_state = %{current | status: "collecting", depth: 1, start_byte: start_byte}
    Cache.put(res_key, new_state)
    Cache.put(buf_key, buffer)
  end

  defp finalize_output(agent_id, res_key, buf_key, current, buffer) do
    raw_r = count_occurrences(buffer, @right)
    eff_r = div(raw_r, 2)

    start_byte = current.start_byte
    end_byte   = find_byte_pos(buffer, @right, 2 * eff_r)

    length = max(end_byte - start_byte, 0)
    output =
      :binary.part(buffer, start_byte, length)
      |> clean_output()

    Cache.put(res_key, %{output: output, status: "complete"})
    Cache.delete(buf_key)
    Cache.delete("agent:current_task:#{agent_id}")
  end

  # 辅助函数 ---------------------------------------------------------------
  defp count_occurrences(string, pattern), do: length(find_all(string, pattern))

  defp find_all(string, pattern) do
    find_all(string, pattern, 0, [])
  end

  defp find_all(string, pattern, offset, acc) do
    case :binary.match(string, pattern, scope: {offset, byte_size(string) - offset}) do
      {pos, _len} -> find_all(string, pattern, pos + byte_size(pattern), [pos | acc])
      :nomatch     -> acc
    end
  end

  defp find_byte_pos(string, pattern, n) do
    string
    |> find_all(pattern)
    |> Enum.sort()
    |> Enum.at(n - 1)
    |> case do
      nil -> 0
      pos -> pos
    end
  end

  defp clean_output(binary) when is_binary(binary) do
    binary
    |> String.replace(~r/꧁[^꧁]*꧁/u, "")   # 完整左哨兵
    |> String.replace(~r/꧂[^꧂]*꧂/u, "")   # 完整右哨兵
    |> String.replace(~r/꧁[^꧁]*$/u, "")    # 尾部残留左哨兵碎片
    |> String.replace(~r/꧂[^꧂]*$/u, "")    # 尾部残留右哨兵碎片
    |> String.trim()
  end
end