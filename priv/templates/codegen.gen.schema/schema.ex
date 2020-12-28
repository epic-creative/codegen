defmodule <%= inspect schema.module %> do
  @moduledoc """
  The <%= schema.name %> schema model.
  """
  use Ecto.Schema
  import Ecto.Changeset

<%= if schema.binary_id? do %>
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id<% end %>
  schema <%= inspect schema.table %> do
<%= for field <- schema.fields, not Codegen.Field.assoc?(field) do %>    field <%= inspect field.key %>, <%= inspect field.type %><%= field.default %>
<% end %><%= for field <- schema.fields, Codegen.Field.assoc?(field) do %>    field <%= inspect field.key %>, <%= if schema.binary_id? do %>:binary_id<% else %>:id<% end %>
<% end %>
    timestamps()
  end

  @doc false
  def changeset(<%= schema.singular %>, attrs) do
    <%= schema.singular %>
    |> cast(attrs, [<%= Enum.map_join(schema.fields, ", ", &inspect(&1.key)) %>])
    |> validate_required([<%= Enum.map_join(schema.fields, ", ", &inspect(&1.key)) %>])
<%= for field <- schema.fields, Codegen.Field.unique?(field) do %>    |> unique_constraint(<%= inspect field.key %>)
<% end %>  end
end
