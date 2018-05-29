defmodule ClusterOnRedisTest do
  use ExUnit.Case
  doctest ClusterOnRedis

  test "greets the world" do
    assert ClusterOnRedis.hello() == :world
  end
end
