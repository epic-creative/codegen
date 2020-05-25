defmodule CodegenTest do
  use ExUnit.Case
  doctest Codegen

  test "greets the world" do
    assert Codegen.hello() == :world
  end
end
