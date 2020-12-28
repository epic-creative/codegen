defmodule Mix.Tasks.Codegen do
  use Mix.Task

  @shortdoc "Prints Codegen help information"

  @moduledoc """
  Prints Codegen tasks and their information.
      mix codegen
  """

  @doc false
  def run(args) do
    {_opts, args} = OptionParser.parse!(args, strict: [])

    case args do
      [] -> general()
      _ -> Mix.raise("Invalid arguments, expected: mix codegen")
    end
  end

  defp general() do
    Mix.shell().info("A code generation toolkit for Elixir.")
    Mix.shell().info("\nAvailable tasks:\n")
    Mix.Tasks.Help.run(["--search", "codegen."])
  end
end
