defmodule ClusterOnRedis.RedisStrategy do
  use GenServer
  use Cluster.Strategy
  import Cluster.Logger

  alias Cluster.Strategy.State

  @default_poll_interval 5_000
  @prefix "peers:"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    state = %State{
      topology: Keyword.fetch!(opts, :topology),
      connect: Keyword.fetch!(opts, :connect),
      disconnect: Keyword.fetch!(opts, :disconnect),
      list_nodes: Keyword.fetch!(opts, :list_nodes),
      config: Keyword.get(opts, :config, [])
    }

    {:ok, redis} = Redix.start_link(Keyword.get(state.config, :redis, "redis://localhost:6379/0"))

    query = Keyword.fetch!(state.config, :query)
    node_sname = Keyword.fetch!(state.config, :node_sname)
    poll_interval = Keyword.get(state.config, :poll_interval, @default_poll_interval)

    state = %{state | meta: {poll_interval, query, node_sname, [], redis}}

    info(state.topology, "starting redis polling for #{query}")

    {:ok, do_poll(state)}
  end

  def handle_info(:timeout, state), do: handle_info(:poll, state)
  def handle_info(:poll, state), do: {:noreply, do_poll(state)}
  def handle_info(_, state), do: {:noreply, state}

  defp do_poll(%State{meta: {poll_interval, query, node_sname, _, redis}} = state) do
    debug(state.topology, "polling redis for #{query}")

    me = node()

    my_ip =
      me
      |> to_string()
      |> String.replace("myapp", "")
      |> String.trim_leading("@")

    Redix.command(redis, ["PSETEX", "#{@prefix}#{my_ip}", poll_interval, "#{me}"])

    nodes =
      Redix.command(redis, ["KEYS", query])
      |> (fn {:ok, nodes} -> nodes end).()
      |> Enum.map(&format_node(&1, node_sname))
      |> Enum.reject(fn n -> n == me end)

    debug(state.topology, "found nodes #{inspect(nodes)}")

    Cluster.Strategy.connect_nodes(state.topology, state.connect, state.list_nodes, nodes)

    # reschedule a call to itself in poll_interval ms
    Process.send_after(self(), :poll, poll_interval)

    %{state | meta: {poll_interval, query, node_sname, nodes, redis}}
  end

  # turn an ip into a node name atom, assuming that all other node names looks similar to our own name
  defp format_node(@prefix <> other, sname), do: :"#{sname}@#{other}"
end
