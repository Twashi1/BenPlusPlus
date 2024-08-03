defmodule BenplusplusTest do
  use ExUnit.Case
  doctest Benplusplus

  test "greets the world" do
    assert Benplusplus.hello() == :world
  end
end
