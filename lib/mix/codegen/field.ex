defmodule Mix.Codegen.Field do
  @moduledoc false

  alias Mix.Codegen.Field

  defstruct name: nil,
            key: nil,
            type: nil,
            default: nil,
            unique?: false,
            index?: false,
            assoc_table: nil,
            migration_default: nil,
            create_param: nil,
            update_param: nil

  @simple_types [
    :integer,
    :float,
    :decimal,
    :boolean,
    :map,
    :string,
    :text,
    :date,
    :time,
    :time_usec,
    :naive_datetime,
    :naive_datetime_usec,
    :utc_datetime,
    :utc_datetime_usec,
    :uuid,
    :binary
  ]
  @complex_types [:array, :unique]

  @ref_types [:references, :belongs_to]

  def valid_types, do: @simple_types

  # field = Field.new("body", :string)
  # %Field{
  #   name: "body", type: :string, default: "", unique?: false, migration_default: "",
  #   create_param: "some body", update_param: "some updated body"
  # }

  # field = Field.new("published", :boolean)
  # %Field{
  #   name: "published", type: :boolean, default: "", unique?: false,
  #   migration_default: ", default: false, null: false",
  #   create_param: true, update_param: false
  # }

  # field = Field.new("title", :string, unique: true)
  # %Field{
  #   name: "title", type: :string, default: "", unique?: true, migration_default: "",
  #   create_param: "some title", update_param: "some updated title"
  # }

  # field = Field.new("tags", {:array, :string})
  # %Field{
  #   name: "tags", type: {:array, :string}, default: "", unique?: false, migration_default: "",
  #   create_param: [], update_param: []
  # }

  # Field.new("body")
  # Field.new("body:string")
  # Field.new("title:unique:string")
  # Field.new("tags:array:string")
  # Field.new("user_id:references:users")
  # Field.new({"body"})
  # Field.new({"body",:string})
  # Field.new({"tags",:array, :string})
  # Field.new({"user_id",:references, "users"})
  # Field.new("body", :string)
  # Field.new("title", :string, unique: true)

  # "body" -> ["body"]
  # "body:string" -> ["body", "string"]
  # "title:unique" -> ["title", "unique"]
  # "title:unique:string" -> ["title", "unique", "string"]
  # "title:unique:string:extra" -> ["title", "unique", "string:extra"]
  def new(field) when is_binary(field) do
    case String.split(field, ":", parts: 3) do
      [name] -> Field.new({name, :string})
      [name, type] -> Field.new({name, String.to_atom(type)})
      [name, one, two] -> Field.new({name, String.to_atom(one), String.to_atom(two)})
      _ -> Mix.raise("Invalid Field Definition")
    end
  end

  # Field.new(["body"]) - defaults to :string
  # def new([name]), do: Field.new(name, :string)
  # Field.new(["body", "string"])
  # def new([name, type]) when type in @simple_types, do: Field.new(name, type)
  # Field.new(["title", "unique"]) - defaults to :string
  # def new([name, "unique"]), do: Field.new(name, :string, unique: true)

  # def new([name, "unique", type]) when type in @simple_types,
  # do: Field.new(name, type, unique: true)

  # def new([name, complex]) when complex in @complex_types, do: Field.new(name, {complex, :string})
  # # Field.new(["title","unique","string"]) - defaults to :string
  # def new([name, complex, type]) when complex in @complex_types,
  #   do: Field.new(name, {complex, type})

  # # Field.new("user_id:references:users")
  # def new([name, ref_type, reference]) when ref_type in @ref_types,
  #   do: Field.new(name, :assoc, ref_table: reference)

  def new({name}), do: Field.new(name, :string)
  def new({name, type}) when type in @simple_types, do: Field.new(name, type)
  def new({name, :unique}), do: Field.new(name, :string, unique: true)

  def new({name, :unique, type}) when type in @simple_types,
    do: Field.new(name, type, unique: true)

  def new({name, complex}) when complex in @complex_types, do: Field.new(name, {complex, :string})

  def new({name, complex, type}) when complex in @complex_types,
    do: Field.new(name, {complex, type})

  def new({name, ref_type, table}) when ref_type in @ref_types,
    do: Field.new(name, :assoc, assoc_table: table)

  def new(name, type, opts \\ []) do
    unique? = Keyword.get(opts, :unique, false)
    assoc_table = Keyword.get(opts, :assoc_table, nil)

    %Field{
      name: name,
      key: String.to_atom(name),
      type: type,
      unique?: unique?,
      default: schema_default(type),
      assoc_table: assoc_table,
      migration_default: migration_default(type),
      create_param: type_to_default(name, type, :create),
      update_param: type_to_default(name, type, :update)
    }
  end

  # defp validate_attr!(name, :datetime), do: validate_attr!({name, :naive_datetime})

  # defp validate_attr!(name, :array) do
  #   Mix.raise("""
  #   Codegen generators expect the type of the array to be given to #{name}:array.
  #   For example:

  #       mix codegen.gen.schema Post posts settings:array:string
  #   """)
  # end

  # defp validate_attr!(name, type) when type in @valid_types, do: {name, type}
  # defp validate_attr!(name, {type, _}) when type in @valid_types, do: {name, type}

  # defp validate_attr!({_, type}) do
  #   Mix.raise(
  #     "Unknown type `#{inspect(type)}` given to generator. " <>
  #       "The supported types are: #{@valid_types |> Enum.sort() |> Enum.join(", ")}"
  #   )
  # end

  @doc """
  Comprehension test to see if a field is unique
  """
  def unique?(%Field{} = field) do
    field.unique? == true
  end

  @doc """
  Comprehension test to see if a field is an index
  """
  def index?(%Field{} = field) do
    field.index? == true
  end

  @doc """
  Comprehension test to see if a field is an association
  """
  def assoc?(%Field{} = field) do
    field.type == :assoc
  end

  defp indexes(table, assocs, uniques) do
    uniques = Enum.map(uniques, fn key -> {key, true} end)
    assocs = Enum.map(assocs, fn {_, key, _, _} -> {key, false} end)

    (uniques ++ assocs)
    |> Enum.uniq_by(fn {key, _} -> key end)
    |> Enum.map(fn
      {key, false} -> "create index(:#{table}, [:#{key}])"
      {key, true} -> "create unique_index(:#{table}, [:#{key}])"
    end)
  end

  defp type_to_default(name, type, :create) do
    case type do
      {:array, _} -> []
      :integer -> 42
      :float -> 120.5
      :decimal -> "120.5"
      :boolean -> true
      :map -> %{}
      :text -> "some #{name}"
      :date -> ~D[2010-04-17]
      :time -> ~T[14:00:00]
      :time_usec -> ~T[14:00:00.000000]
      :uuid -> "7488a646-e31f-11e4-aace-600308960662"
      :utc_datetime -> ~U[2010-04-17T14:00:00Z]
      :utc_datetime_usec -> ~U[2010-04-17T14:00:00.000000Z]
      :naive_datetime -> ~N[2010-04-17 14:00:00]
      :naive_datetime_usec -> ~N[2010-04-17 14:00:00.000000]
      _ -> "some #{name}"
    end
  end

  defp type_to_default(name, type, :update) do
    case type do
      {:array, _} -> []
      :integer -> 43
      :float -> 456.7
      :decimal -> "456.7"
      :boolean -> false
      :map -> %{}
      :text -> "some updated #{name}"
      :date -> ~D[2011-05-18]
      :time -> ~T[15:01:01]
      :time_usec -> ~T[15:01:01.000000]
      :uuid -> "7488a646-e31f-11e4-aace-600308960668"
      :utc_datetime -> ~U[2011-05-18T15:01:01Z]
      :utc_datetime_usec -> ~U[2011-05-18T15:01:01.000000Z]
      :naive_datetime -> ~N[2011-05-18 15:01:01]
      :naive_datetime_usec -> ~N[2011-05-18 15:01:01.000000]
      _ -> "some updated #{name}"
    end
  end

  defp migration_default(:boolean) do
    ", default: false, null: false"
  end

  defp migration_default(_) do
    ""
  end

  defp schema_default(:boolean) do
    ", default: false"
  end

  defp schema_default(_) do
    ""
  end
end
