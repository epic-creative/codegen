defmodule Codegen.Gen.Migration do
  @behaviour Codegen.Generator

  @template_paths [".", :codegen]
  @source_dir "priv/templates/codegen.gen.schema"

  require IEx
  alias Codegen.Generator
  alias Codegen.Template
  alias Codegen.Helper.Schema

  def build(context_list, opts \\ []) when is_list(context_list) do
    for context <- context_list,
        schema <- context.schemas do
      build(schema, opts)
    end
  end

  def build(schema = %Schema{}, opts) do
    if Mix.Project.umbrella?() do
      Mix.raise("You can only generate a migration within an application directory")
    end

    timestamp = Keyword.get(opts, :migration_timestamp, timestamp())

    target_path =
      Codegen.context_app_path(
        Codegen.context_app(),
        "priv/repo/migrations/#{timestamp}_create_#{schema.table}.exs"
      )

    %Generator{
      source_dir: @source_dir,
      template_paths: @template_paths,
      templates: [
        %Template{
          format: :eex,
          source_path: "migration.exs",
          target_path: target_path,
          force_overwrite?: true,
          assigns: [schema: schema]
        }
      ]
    }
  end

  def generate(list) when is_list(list) do
    Enum.each(list, fn opts ->
      Codegen.write_templates(opts.template_paths, opts.source_dir, opts.templates)
    end)
  end

  @impl Codegen.Generator
  def generate(opts) when is_map(opts) do
    IEx.pry()
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
