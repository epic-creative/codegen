defmodule <%= inspect schema.repo %>.Migrations.Create<%= schema.migration_name %> do
  use <%= inspect schema.migration_module %>

  def change do
    create table(:<%= schema.table %><%= if schema.binary_id? do %>, primary_key: false<% end %>) do
<%= if schema.binary_id? do %>      add :id, :binary_id, primary_key: true
<% end %><%= for {key, field} <- schema.fields, not Mix.Codegen.Field.assoc?(field) do %>      add <%= inspect(key)  %>, <%= inspect(field.type) %><%= field.migration_default %>
<% end %><%= for {key, field} <- schema.fields, Mix.Codegen.Field.assoc?(field) do %>      add <%= inspect(key) %>, references(<%= inspect(field.assoc_table) %>, on_delete: :nothing<%= if schema.binary_id? do %>, type: :binary_id<% end %>)
<% end %>
      timestamps()
    end

<%= for {key, field} <- schema.fields, Mix.Codegen.Field.index?(field) do %>    create index(:<%= schema.table %>, [:<%= key %>])
<% end %><%= for {key, field} <- schema.fields, Mix.Codegen.Field.unique?(field) do %>    create unique_index(:<%= schema.table %>, [:<%= key %>])
<% end %>
  end
end
