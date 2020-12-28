defmodule <%= inspect schema.repo %>.Migrations.Create<%= schema.migration_name %> do
  use <%= inspect schema.migration_module %>

  def change do
    create table(:<%= schema.table %><%= if schema.binary_id? do %>, primary_key: false<% end %>) do
<%= if schema.binary_id? do %>      add(:id, :binary_id, primary_key: true)
<% end %><%= for field <- schema.fields, not Codegen.Field.assoc?(field) do %>      add(<%= inspect(field.key)  %>, <%= inspect(field.type) %><%= field.migration_default %>)
<% end %><%= for field <- schema.fields, Codegen.Field.assoc?(field) do %>      add(<%= inspect(field.key) %>, references(<%= inspect(field.assoc_table) %>, on_delete: :nothing<%= if schema.binary_id? do %>, type: :binary_id<% end %>)
<% end %>
      timestamps(<%= if not is_nil(schema.timestamp_column) do schema.timestamp_column end %>)
    end

<%= for field <- schema.fields, Codegen.Field.index?(field) do %>    create index(:<%= schema.table %>, [:<%= field.key %>])
<% end %><%= for field <- schema.fields, Codegen.Field.unique?(field) do %>    create unique_index(:<%= schema.table %>, [:<%= field.key %>])
<% end %>
  end
end
