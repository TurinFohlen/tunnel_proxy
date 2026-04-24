defmodule TunnelProxy.TaskQueue do
  @moduledoc "GenStage 生产者：命令任务队列"

  use GenStage
  require Logger

  def start_link(opts), do: GenStage.start_link(__MODULE__, opts, name: __MODULE__)

  def push(task), do: GenStage.cast(__MODULE__, {:push, task})

  def init(_) do
    {:producer, {:queue.new(), 0}}
  end

  def handle_demand(demand, {queue, pending}) when demand > 0 do
    Logger.debug("TaskQueue 收到需求: #{demand}, 队列长度: #{:queue.len(queue)}")
    dispatch({queue, pending + demand})
  end

  def handle_cast({:push, task}, {queue, pending}) do
    Logger.debug("TaskQueue 收到新任务，pending demand: #{pending}")
    new_queue = :queue.in(task, queue)
    dispatch({new_queue, pending})
  end

  defp dispatch({queue, pending}) do
    queue_len = :queue.len(queue)
    to_send = min(pending, queue_len)

    if to_send > 0 do
      {items, new_queue} = drain(queue, to_send, [])
      Logger.debug("TaskQueue 分发 #{length(items)} 个任务")
      {:noreply, items, {new_queue, pending - to_send}}
    else
      {:noreply, [], {queue, pending}}
    end
  end

  defp drain(q, 0, acc), do: {Enum.reverse(acc), q}
  defp drain(q, n, acc) do
    case :queue.out(q) do
      {{:value, item}, rest} -> drain(rest, n - 1, [item | acc])
      {:empty, _}            -> {Enum.reverse(acc), q}
    end
  end
end

defmodule TunnelProxy.TaskExecutor do
  @moduledoc "GenStage 消费者：从队列拉取任务并交给 PTYPool 执行"

  use GenStage
  require Logger

  def start_link(opts), do: GenStage.start_link(__MODULE__, opts, name: __MODULE__)

  def init(_) do
    {:consumer, %{}, subscribe_to: [{TunnelProxy.TaskQueue, max_demand: 10, min_demand: 5}]}
  end

  def handle_events(tasks, _from, state) do
    Logger.info("TaskExecutor 收到 #{length(tasks)} 个任务")
    Enum.each(tasks, fn %{agent_id: agent_id, task_id: task_id, cmd: cmd} ->
      Logger.info("执行任务: #{task_id} - #{cmd}")
      case TunnelProxy.PTYPool.exec(agent_id, task_id, cmd) do
        {:ok, _} ->
          Logger.info("任务已提交到 PTY: #{task_id}")
          :ok
        {:error, :busy} ->
          Logger.warning("Agent 繁忙，重新入队: #{task_id}")
          TunnelProxy.TaskQueue.push(%{agent_id: agent_id, task_id: task_id, cmd: cmd})
      end
    end)
    {:noreply, [], state}
  end
end
