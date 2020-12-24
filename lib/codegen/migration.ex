defmodule Codegen.Gen.Migration do
  # @callback parse_args(args)
  # @callback build_assigns
  # @callback write_files
  # @callback print_post_instructions

  @files_to_be_generated [
    {:eex, "schema.ex" },
    {:engine, "template.ex", "destination.ex", false}
  ]

  def init(args) do
    # schema = build(args, [])
    args
  end

  def build_templates(assigns) do
    # [
    #   {Codegen.Schema, "schema.exs", &dest_path/1, false, &assigns_callback?},
    #   {Codegen.Miration, "migration.exs", &dest_path/1, false, &assigns_callback?}
    #   {Codegen.Schema, "schema.exs", &dest_path/1, false, &assigns_callback?}
    #   {Codegen.Miration, "migration.exs", &dest_path/1, false, &assigns_callback?}
    # ]
  end

  def post_install() do
    Mix.shell().info """

    Remember to update your repository by running migrations:

        $ mix ecto.migrate
    """
  end

  defp template() do
    ~S"""
defmodule <%= inspect schema.repo %>.Migrations.Create<%= Macro.camelize(schema.table) %> do
  use <%= inspect schema.migration_module %>

  def change do
    create table(:<%= schema.table %><%= if schema.binary_id do %>, primary_key: false<% end %>) do
<%= if schema.binary_id do %>      add :id, :binary_id, primary_key: true
<% end %><%= for {k, v} <- schema.attrs do %>      add <%= inspect k %>, <%= inspect v %><%= schema.migration_defaults[k] %>
<% end %><%= for {_, i, _, s} <- schema.assocs do %>      add <%= inspect(i) %>, references(<%= inspect(s) %>, on_delete: :nothing<%= if schema.binary_id do %>, type: :binary_id<% end %>)
<% end %>
      timestamps()
    end
<%= for index <- schema.indexes do %>
    <%= index %><% end %>
  end
end
"""
  end
end
