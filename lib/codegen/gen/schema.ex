defmodule Codegen.Gen.Schema do
  @template_paths [".", :codegen]
  @source_dir "priv/templates/codegen.gen.schema"

  require IEx
  alias Mix.Codegen.Schema

  def build_list(list) do
    Enum.map(list.schemas, fn params ->
      build(Map.put(params, :name, "#{list.context}.#{params.name}"))
    end)
  end

  # @doc false
  # def files_to_be_generated(%Schema{} = schema) do
  #   [{:eex, "schema.ex", schema.file}]
  # end

  @impl Codegen.Generator
  def build(params) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix codegen.gen.schema can only be run inside an application directory")
    end

    context_app = Mix.Codegen.context_app()
    schema = build_schema(params, [])

    # schema = %{

    # }
    assigns = [schema: schema]

    templates = [
      {:eex, "schema.ex", schema.file, false, assigns}
    ]

    templates =
      templates ++
        if schema.migration? do
          [
            {:eex, "migration.exs",
             Mix.Codegen.context_app_path(
               context_app,
               "priv/repo/migrations/#{timestamp()}_create_#{schema.table}.exs"
             ), true, assigns}
          ]
        else
          []
        end

    params = %{
      assigns: [schema: schema],
      source_dir: @source_dir,
      template_paths: @template_paths,
      templates: templates
    }

    IEx.pry()

    params

    # schema = build_schema(params, [])
    # paths = Mix.Codegen.generator_paths()

    # consider moving into a general method
    # schema
    # |> files_to_be_generated()
    # |> Mix.Codegen.prompt_for_conflicts()

    # schema
    # |> copy_new_files(paths, schema: schema)
    # |> print_shell_instructions()

    # if schema.migration? do
    #   migration_path =
    #     Mix.Codegen.context_app_path(
    #       ctx_app,
    #       "priv/repo/migrations/#{timestamp()}_create_#{schema.table}.exs"
    #     )

    #   Mix.Codegen.copy_from(paths, "priv/templates/codegen.gen.schema", binding, [
    #     {:eex, "migration.exs", migration_path}
    #   ])
    # end

    # assigns = schema: schema
    # params = %{
    #   assigns: [schema: schema],
    #   source_dir: @source_dir,
    #   template_paths: @template_paths,
    #   templates: [
    #     {:eex, "schema.ex", schema.file, false, assigns},
    #     {:eex, "migration.exs",
    #      Path.join(test_prefix, "channels/#{assigns[:path]}_channel_test.exs"), true, assigns}
    #   ]
    # }

    # if schema.migration? do
    #   migration_path =
    #     Mix.Codegen.context_app_path(
    #       ctx_app,
    #       "priv/repo/migrations/#{timestamp()}_create_#{schema.table}.exs"
    #     )

    #   params.templates =
    #     params.templates ++
    #       [
    #         {:eex, "migration.exs", migration_path}
    #       ]
    # end
  end

  def generate(list) when is_list(list) do
    ## TODO - Prompt for Conflicts

    Enum.each(list, fn opts ->
      Mix.Codegen.write_templates(opts.template_paths, opts.source_dir, opts.templates)
    end)
  end

  @impl Codegen.Generator
  def generate(opts) when is_map(opts) do
    Mix.Codegen.write_templates(opts.template_paths, opts.source_dir, opts.templates)

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

      String.contains?(plural, ":") or plural != Codegen.Naming.underscore(plural) ->
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
