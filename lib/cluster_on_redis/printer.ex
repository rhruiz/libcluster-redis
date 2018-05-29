defmodule ClusterOnRedis.Printer do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: {:global, :printer})
  end

  def init(_) do
    {:ok, []}
  end

  def handle_call({:print, arg}, _from, state) do
    {:reply, IO.puts(arg), state}
  end
end
