defmodule Codegen.Helper.Context do
  @moduledoc false

  alias Codegen.Helper.Context
  alias Codegen.Helper.Schema
  require IEx

  defstruct name: nil,
            module: nil,
            schemas: nil,
            alias: nil,
            base_module: nil,
            web_module: nil,
            basename: nil,
            file: nil,
            test_file: nil,
            test_fixtures_file: nil,
            dir: nil,
            generate?: true,
            context_app: nil,
            opts: []

  def valid?(context) do
    context =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/
  end

  def new(name, schemas, opts) do
    ctx_app = opts[:context_app] || Codegen.context_app()
    base = Module.concat([Codegen.context_base(ctx_app)])
    module = Module.concat(base, name)
    alias = Module.concat([module |> Module.split() |> List.last()])
    basedir = Codegen.Helper.Naming.underscore(name)
    basename = Path.basename(basedir)
    dir = Codegen.context_lib_path(ctx_app, basedir)
    file = dir <> ".ex"
    test_dir = Codegen.context_test_path(ctx_app, basedir)
    test_file = test_dir <> "_test.exs"
    test_fixtures_dir = Codegen.context_app_path(ctx_app, "test/support/fixtures")
    test_fixtures_file = Path.join([test_fixtures_dir, basedir <> "_fixtures.ex"])
    # generate? = Keyword.get(opts, :context, true)

    schemas =
      for {:schema, name, opts, fields} <- schemas do
        Schema.new(ctx_app, name, fields, opts)
      end

    %Context{
      name: name,
      module: module,
      schemas: schemas,
      alias: alias,
      base_module: base,
      web_module: web_module(),
      basename: basename,
      file: file,
      test_file: test_file,
      test_fixtures_file: test_fixtures_file,
      dir: dir,
      # generate?: generate?,
      context_app: ctx_app,
      opts: opts
    }
  end

  def pre_existing?(%Context{file: file}), do: File.exists?(file)

  def pre_existing_tests?(%Context{test_file: file}), do: File.exists?(file)

  def pre_existing_test_fixtures?(%Context{test_fixtures_file: file}), do: File.exists?(file)

  def function_count(%Context{file: file}) do
    {_ast, count} =
      file
      |> File.read!()
      |> Code.string_to_quoted!()
      |> Macro.postwalk(0, fn
        {:def, _, _} = node, count -> {node, count + 1}
        {:defdelegate, _, _} = node, count -> {node, count + 1}
        node, count -> {node, count}
      end)

    count
  end

  def file_count(%Context{dir: dir}) do
    dir
    |> Path.join("**/*.ex")
    |> Path.wildcard()
    |> Enum.count()
  end

  defp web_module do
    base = Codegen.base()

    cond do
      Codegen.context_app() != Codegen.otp_app() ->
        Module.concat([base])

      String.ends_with?(base, "Web") ->
        Module.concat([base])

      true ->
        Module.concat(["#{base}Web"])
    end
  end
end
