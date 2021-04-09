defmodule Codegen.Gen.Context do
  @behaviour Codegen.Generator

  @template_paths [".", :codegen]
  @source_dir "priv/templates/codegen.gen.context"

  require IEx
  alias Codegen.{Generator, Template}
  alias Codegen.Helper.{Context, Schema, Field}

  def build(context_list, opts \\ []) when is_list(context_list) do
    for context <- context_list do
      build(context, opts)
    end
  end

  @impl Codegen.Generator
  def build(%Context{} = context, opts) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix codegen.gen.schema can only be run inside an application directory")
    end

    assigns = [context: context]

    templates = [
      %Template{
        source_path: "context.ex",
        target_path: context.file,
        assigns: assigns
      },
      %Template{
        source_path: "context_test.ex",
        target_path: context.test_file,
        assigns: assigns
      }
    ]

    %Generator{
      source_dir: @source_dir,
      template_paths: @template_paths,
      templates: templates
    }
  end

  def generate(list) when is_list(list) do
    ## TODO - Prompt for Conflicts

    Enum.each(list, fn opts ->
      Codegen.write_templates(opts.template_paths, opts.source_dir, opts.templates)
      # post_install(opts)
    end)
  end

  @impl Codegen.Generator
  def generate(opts) when is_map(opts) do
    Codegen.write_templates(opts.template_paths, opts.source_dir, opts.templates)

    post_install(opts)
  end

  @impl Codegen.Generator
  def post_install(opts) do
    if opts.migration? do
      """

      Remember to update your repository by running migrations:

          $ mix ecto.migrate
      """
    end
  end

  @doc false
  defp build_schema(args, parent_opts, help \\ __MODULE__) do
    fields = Enum.map(args.fields, fn t -> Tuple.to_list(t) |> Enum.join(":") end)
    opts = %{table: args.table, migration: args.migration, web: args.web}

    opts =
      parent_opts
      |> Keyword.merge(Map.to_list(args))
      |> put_context_app(args[:context_app])

    Schema.new(args.name, args.table, fields, opts)
  end

  defp validate_args!([schema, plural | _] = args, help) do
    cond do
      not Schema.valid?(schema) ->
        help.raise_with_help(
          "Expected the schema argument, #{inspect(schema)}, to be a valid module name"
        )

      String.contains?(plural, ":") or plural != Codegen.Helper.Naming.underscore(plural) ->
        help.raise_with_help(
          "Expected the plural argument, #{inspect(plural)}, to be all lowercase using snake_case convention"
        )

      true ->
        args
    end
  end

  defp validate_args!(_, help) do
    help.raise_with_help("Invalid arguments")
  end

  defp put_context_app(opts, nil), do: opts

  defp put_context_app(opts, string) do
    Keyword.put(opts, :context_app, String.to_atom(string))
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)
end
