defmodule Codegen.Resolver do
  use Agent, restart: :temporary

  require Logger
  require IEx

  @doc """
  Starts the runner for the specified repo.
  """
  def start_link() do
    Agent.start_link(fn ->
      %{
        definition: %{},
        context: nil
      }
    end)
  end

  def add_definition(type, name, opts \\ []) do
    Agent.get_and_update(__MODULE__)
    IEx.pry()
  end

  def start_definition(type, name, opts \\ []) do
    IEx.pry()
  end

  def end_definition() do
    IEx.pry()
  end

  @doc """
  Stores the runner metadata.
  """
  def metadata(runner, opts) do
    prefix = opts[:prefix]
    Process.put(:codegen, %{runner: runner, prefix: prefix && to_string(prefix)})
  end

  @doc """
  Stops the runner.
  """
  def stop() do
    Agent.stop(runner())
  end

  defp runner do
    case Process.get(:codegen) do
      %{runner: runner} -> runner
      _ -> raise "could not find migration runner process for #{inspect(self())}"
    end
  end
end
