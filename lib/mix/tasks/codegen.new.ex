defmodule Mix.Tasks.Codegen.New do
  use Mix.Task

  import Macro, only: [camelize: 1, underscore: 1]
  import Mix.Generator

  @shortdoc "Generates a new codegen script for the project"

  @switches [
    config: :string,
    timestamp: :string,
    codegen_path: :string
  ]

  @moduledoc """
  Generates a new Codegen script for the project

  ## Examples
      mix codegen.gen.codegen accounts_context
      mix codegen.gen.codegen blog_context

  Codegen scripts are used during the development process to codify
  the parameters for sending to scaffolding helpers.

  The generated script filename will be prefixed with the current
  date in UTC which is used for versioning and ordering.
  By default, the migration will be generated to the
  "priv/codegen" directory of the current application
  but it can be configured to be any subdirectory of `priv` by
  specifying the `:priv` key under the repository configuration.

    * `--codegen-path` - the path to put the codegen script, defaults to `priv/codegen`
    * `--timestamp`    - the timestamp prefix for the file
  """

  @impl true
  def run(args) do
    case OptionParser.parse!(args, strict: @switches) do
      {opts, [name]} ->
        path = opts[:codegen_path] || Path.join("priv", "codegen")
        timestamp = opts[:timestamp] || timestamp()
        base_name = "#{underscore(name)}.exs"

        file = Path.join(path, "#{timestamp}_#{base_name}")
        unless File.dir?(path), do: create_directory(path)

        fuzzy_path = Path.join(path, "*_#{base_name}")

        if Path.wildcard(fuzzy_path) != [] do
          Mix.raise(
            "codegen script can't be created, there is already a codegen file with name #{name}."
          )
        end

        ctx_app = opts[:context_app] || Codegen.context_app()
        base = Module.concat([Codegen.context_base(ctx_app)])

        # otp_app = Codegen.otp_app()
        # app = Codegen.context_app()
        # require IEx
        # IEx.pry()

        assigns = [
          config: opts[:config] || default_config(),
          mod: Module.concat([base, Codegen, Generate, camelize(name)])
        ]

        create_file(file, codegen_template(assigns))

        post_install(file, base_name)
        file

      {_, _} ->
        Mix.raise(
          "expected codegen.gen.codegen to receive the codegen file name, " <>
            "got: #{inspect(Enum.join(args, " "))}"
        )
    end
  end

  defp post_install(file, name) do
    Mix.shell().info("""

    You can now configure your Code Generator by editing the file
    that you just created:

      #{inspect(file)}

    After you have configured your generator, you may run it with

      mix codegen.run #{name}
    """)
  end

  defp default_config() do
    "%{
      generator: MyGenerator,
      params: %{}
    }"
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)

  embed_template(:codegen, """
  defmodule <%= inspect @mod %> do
    def config do
      <%= @config %>
    end
  end
  """)
end
