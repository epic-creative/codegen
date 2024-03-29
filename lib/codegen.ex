defmodule Codegen do
  @moduledoc """
  Library to generate Code for Elixir projects
  """
  alias Codegen.Helper.{Context, Schema, Field}
  alias Codegen.Generator

  @doc "Run the code generator with the passed configuration"
  def run(module) do
    # Grab the Generator Definition
    definition =
      for obj <- module.define() do
        define_helper(obj)
      end

    # Build the list of Generators

    module.generate()
    |> Enum.reduce([], fn builder, acc ->
      gen = build_generator(builder, definition)
      acc ++ gen
    end)
    |> Enum.each(fn generator -> generate(generator) end)
  end

  def define_helper({:context, name, opts, schemas}) do
    Context.new(name, schemas, opts)
  end

  def define_helper({:schema, name, opts, fields}) do
    Schema.new(name, opts, fields)
  end

  def define_helper({:field, name, opts}) do
    Field.new(name, opts)
  end

  def build_generator({:migration, opts}, definition) do
    Codegen.Gen.Migration.build(definition, opts)
  end

  def build_generator({:schema, opts}, definition) do
    Codegen.Gen.Schema.build(definition, opts)
  end

  def build_generator({:context, opts}, definition) do
    Codegen.Gen.Context.build(definition, opts)
  end

  def build_generator(_opts, _definition) do
    IO.puts("Please define a generator")
  end

  def generate(generator = %Generator{}) do
    Codegen.write_templates(generator.template_paths, generator.source_dir, generator.templates)
  end

  @doc """
  Evals EEx files from source dir.

  Files are evaluated against EEx according to
  the given binding.
  """
  def eval_from(apps, source_file_path, binding) do
    sources = Enum.map(apps, &to_app_source(&1, source_file_path))

    content =
      Enum.find_value(sources, fn source ->
        File.exists?(source) && File.read!(source)
      end) || raise "could not find #{source_file_path} in any of the sources"

    EEx.eval_string(content, binding)
  end

  @doc """
  Copies files from source dir to target dir
  according to the given map.

  Files are evaluated against EEx according to
  the given binding.
  """
  def copy_from(apps, source_dir, binding, mapping) when is_list(mapping) do
    roots = Enum.map(apps, &to_app_source(&1, source_dir))

    for {format, source_file_path, target} <- mapping do
      source =
        Enum.find_value(roots, fn root ->
          source = Path.join(root, source_file_path)
          if File.exists?(source), do: source
        end) || raise "could not find #{source_file_path} in any of the sources"

      case format do
        :text ->
          Mix.Generator.create_file(target, File.read!(source))

        :eex ->
          Mix.Generator.create_file(target, EEx.eval_file(source, binding))

        :new_eex ->
          if File.exists?(target) do
            :ok
          else
            Mix.Generator.create_file(target, EEx.eval_file(source, binding))
          end
      end
    end
  end

  @doc """
  Copies files from source dir to target dir
  according to the given map.

  Files are evaluated against EEx according to
  the given binding.
  """
  def write_templates(apps, source_dir, mapping) when is_list(mapping) do
    roots = Enum.map(apps, &to_app_source(&1, source_dir))

    for t <- mapping do
      source =
        Enum.find_value(roots, fn root ->
          source = Path.join(root, t.source_path)
          if File.exists?(source), do: source
        end) || raise "could not find #{t.source_path} in any of the sources"

      case t.format do
        :text ->
          Mix.Generator.create_file(t.target_path, File.read!(t.source_path),
            force: t.force_overwrite?
          )

        :eex ->
          Mix.Generator.create_file(t.target_path, EEx.eval_file(source, t.assigns),
            force: t.force_overwrite?
          )
      end
    end
  end

  defp to_app_source(path, source_dir) when is_binary(path),
    do: Path.join(path, source_dir)

  defp to_app_source(app, source_dir) when is_atom(app),
    do: Application.app_dir(app, source_dir)

  @doc """
  Inflects path, scope, alias and more from the given name.

  ## Examples

      iex> Codegen.inflect("user")
      [alias: "User",
       human: "User",
       base: "Codegen",
       web_module: "CodegenWeb",
       module: "Codegen.User",
       scoped: "User",
       singular: "user",
       path: "user"]

      iex> Codegen.inflect("Admin.User")
      [alias: "User",
       human: "User",
       base: "Codegen",
       web_module: "CodegenWeb",
       module: "Codegen.Admin.User",
       scoped: "Admin.User",
       singular: "user",
       path: "admin/user"]

      iex> Codegen.inflect("Admin.SuperUser")
      [alias: "SuperUser",
       human: "Super user",
       base: "Codegen",
       web_module: "CodegenWeb",
       module: "Codegen.Admin.SuperUser",
       scoped: "Admin.SuperUser",
       singular: "super_user",
       path: "admin/super_user"]

  """
  def inflect(singular) do
    base = Codegen.base()
    web_module = base |> web_module() |> inspect()
    scoped = Codegen.Helper.Naming.camelize(singular)
    path = Codegen.Helper.Naming.underscore(scoped)
    singular = String.split(path, "/") |> List.last()
    module = Module.concat(base, scoped) |> inspect
    alias = String.split(module, ".") |> List.last()
    human = Codegen.Helper.Naming.humanize(singular)

    [
      alias: alias,
      human: human,
      base: base,
      web_module: web_module,
      module: module,
      scoped: scoped,
      singular: singular,
      path: path
    ]
  end

  @doc """
  Checks the availability of a given module name.
  """
  def check_module_name_availability!(name) do
    name = Module.concat(Elixir, name)

    if Code.ensure_loaded?(name) do
      Mix.raise("Module name #{inspect(name)} is already taken, please choose another name")
    end
  end

  @doc """
  Returns the module base name based on the configuration value.

      config :my_app
        namespace: My.App

  """
  def base do
    app_base(otp_app())
  end

  @doc """
  Returns the context module base name based on the configuration value.

      config :my_app
        namespace: My.App

  """
  def context_base(ctx_app) do
    app_base(ctx_app)
  end

  defp app_base(app) do
    case Application.get_env(app, :namespace, app) do
      ^app -> app |> to_string() |> Codegen.Helper.Naming.camelize()
      mod -> mod |> inspect()
    end
  end

  @doc """
  Returns the OTP app from the Mix project configuration.
  """
  def otp_app do
    Mix.Project.config() |> Keyword.fetch!(:app)
  end

  @doc """
  Returns all compiled modules in a project.
  """
  def modules do
    Mix.Project.compile_path()
    |> Path.join("*.beam")
    |> Path.wildcard()
    |> Enum.map(&beam_to_module/1)
  end

  defp beam_to_module(path) do
    path |> Path.basename(".beam") |> String.to_atom()
  end

  @doc """
  The paths to look for template files for generators.

  Defaults to checking the current app's `priv` directory,
  and falls back to Codegen's `priv` directory.
  """
  def generator_paths do
    [".", :codegen]
  end

  @doc """
  Checks if the given `app_path` is inside an umbrella.
  """
  def in_umbrella?(app_path) do
    umbrella = Path.expand(Path.join([app_path, "..", ".."]))
    mix_path = Path.join(umbrella, "mix.exs")
    apps_path = Path.join(umbrella, "apps")
    File.exists?(mix_path) && File.exists?(apps_path)
  end

  @doc """
  Returns the web prefix to be used in generated file specs.
  """
  def web_path(ctx_app, rel_path \\ "") when is_atom(ctx_app) do
    this_app = otp_app()

    if ctx_app == this_app do
      Path.join(["lib", "#{this_app}_web", rel_path])
    else
      Path.join(["lib", to_string(this_app), rel_path])
    end
  end

  @doc """
  Returns the context app path prefix to be used in generated context files.
  """
  def context_app_path(ctx_app, rel_path) when is_atom(ctx_app) do
    this_app = otp_app()

    if ctx_app == this_app do
      rel_path
    else
      app_path =
        case Application.get_env(this_app, :generators)[:context_app] do
          {^ctx_app, path} -> Path.relative_to_cwd(path)
          _ -> mix_app_path(ctx_app, this_app)
        end

      Path.join(app_path, rel_path)
    end
  end

  @doc """
  Returns the context lib path to be used in generated context files.
  """
  def context_lib_path(ctx_app, rel_path) when is_atom(ctx_app) do
    context_app_path(ctx_app, Path.join(["lib", to_string(ctx_app), rel_path]))
  end

  @doc """
  Returns the context test path to be used in generated context files.
  """
  def context_test_path(ctx_app, rel_path) when is_atom(ctx_app) do
    context_app_path(ctx_app, Path.join(["test", to_string(ctx_app), rel_path]))
  end

  @doc """
  Returns the OTP context app.
  """
  def context_app do
    this_app = otp_app()

    case fetch_context_app(this_app) do
      {:ok, app} -> app
      :error -> this_app
    end
  end

  @doc """
  Returns the test prefix to be used in generated file specs.
  """
  def web_test_path(ctx_app, rel_path \\ "") when is_atom(ctx_app) do
    this_app = otp_app()

    if ctx_app == this_app do
      Path.join(["test", "#{this_app}_web", rel_path])
    else
      Path.join(["test", to_string(this_app), rel_path])
    end
  end

  defp fetch_context_app(this_otp_app) do
    case Application.get_env(this_otp_app, :generators)[:context_app] do
      nil ->
        :error

      false ->
        Mix.raise("""
        no context_app configured for current application #{this_otp_app}.

        Add the context_app generators config in config.exs, or pass the
        --context-app option explicitly to the generators. For example:

        via config:

            config :#{this_otp_app}, :generators,
              context_app: :some_app

        via cli option:

            mix codegen.gen.[task] --context-app some_app

        Note: cli option only works when `context_app` is not set to `false`
        in the config.
        """)

      {app, _path} ->
        {:ok, app}

      app ->
        {:ok, app}
    end
  end

  defp mix_app_path(app, this_otp_app) do
    case Mix.Project.deps_paths() do
      %{^app => path} ->
        Path.relative_to_cwd(path)

      deps ->
        Mix.raise("""
        no directory for context_app #{inspect(app)} found in #{this_otp_app}'s deps.

        Ensure you have listed #{inspect(app)} as an in_umbrella dependency in mix.exs:

            def deps do
              [
                {:#{app}, in_umbrella: true},
                ...
              ]
            end

        Existing deps:

            #{inspect(Map.keys(deps))}

        """)
    end
  end

  @doc """
  Prompts to continue if any files exist.
  """
  def prompt_for_conflicts(generator_files) do
    file_paths =
      Enum.flat_map(generator_files, fn
        {:new_eex, _, _path} -> []
        {_kind, _, path} -> [path]
      end)

    case Enum.filter(file_paths, &File.exists?(&1)) do
      [] ->
        :ok

      conflicts ->
        Mix.shell().info("""
        The following files conflict with new files to be generated:

        #{conflicts |> Enum.map(&"  * #{&1}") |> Enum.join("\n")}

        See the --web option to namespace similarly named resources
        """)

        unless Mix.shell().yes?("Proceed with interactive overwrite?") do
          System.halt()
        end
    end
  end

  @doc """
  Returns the web module prefix.
  """
  def web_module(base) do
    if base |> to_string() |> String.ends_with?("Web") do
      Module.concat([base])
    else
      Module.concat(["#{base}Web"])
    end
  end
end
