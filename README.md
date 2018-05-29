# ClusterOnRedis

A naive redis-backed `libcluster` dynamic cluster implementation.

To start redis and 3 nodes, run in shell:

```
$> docker-compose up --scale node=3
```

You should see messages like `connected to node myapp@172.0.3.2`

If you want an intereactive shell (iex), after starting redis and the nodes, run:

```
$> docker-compose run --rm node
```

And listing all the nodes:

```
iex> Node.list()
[:"myapp@172.19.0.3", :"myapp@172.19.0.5"]
```

There you can start a globally registered GenServer:

```
iex> ClusterOnRedis.Printer.start_link()
{:ok, #PID<0.193.0>}
```

Starting another node and running that again should result in:

```
iex> ClusterOnRedis.Printer.start_link()
{:error, {:already_started, #PID<19544.193.0>}}
```

You can call that GenServer from any node:

```
iex> GenServer.call({:global, :printer}, {:print, "Hello"})
:ok
```
