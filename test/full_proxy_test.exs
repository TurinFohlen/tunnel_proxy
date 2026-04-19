defmodule TunnelProxyTest do
  use ExUnit.Case
  doctest TunnelProxy

  test "greets the world" do
    assert TunnelProxy.hello() == :world
  end
end
