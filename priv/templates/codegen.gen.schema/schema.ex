defmodule <%= inspect schema.module %> do
  use Ecto.Schema
  import Ecto.Changeset

<%= if schema.binary_id? do %>
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id<% end %>
  schema <%= inspect schema.table %> do
<%= for {key, field} <- schema.fields, not Mix.Codegen.Field.assoc?(field) do %>    field <%= inspect key %>, <%= inspect field.type %><%= field.default %>
<% end %><%= for {key, field} <- schema.fields, Mix.Codegen.Field.assoc?(field) do %>    field <%= inspect key %>, <%= if schema.binary_id? do %>:binary_id<% else %>:id<% end %>
<% end %>
    timestamps()
  end

  @doc false
  def changeset(<%= schema.singular %>, attrs) do
    <%= schema.singular %>
    |> cast(attrs, [<%= Enum.map_join(schema.fields, ", ", &inspect(elem(&1, 0))) %>])
    |> validate_required([<%= Enum.map_join(schema.fields, ", ", &inspect(elem(&1, 0))) %>])
<%= for {key, field} <- schema.fields, Mix.Codegen.Field.unique?(field) do %>    |> unique_constraint(<%= inspect key %>)
<% end %>  end
end
