defmodule Codegen.Helper.Schema do
  @moduledoc false

  alias Codegen.Helper.Schema
  alias Codegen.Helper.Field

  defstruct fields: nil,
            file: nil,
            opts: [],
            binary_id?: false,
            embedded?: false,
            generate?: true,
            migration?: false,
            migration_module: nil,
            migration_name: nil,
            repo: nil,
            table: nil,
            alias: nil,
            app: nil,
            context: nil,
            collection: nil,
            human_singular: nil,
            human_plural: nil,
            module: nil,
            name: nil,
            plural: nil,
            singular: nil,
            route_helper: nil,
            web_path: nil,
            web_namespace: nil

  @valid_types [
    :integer,
    :float,
    :decimal,
    :boolean,
    :map,
    :string,
    :array,
    :references,
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

  def valid_types, do: @valid_types

  def valid?(schema) do
    schema =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/
  end

  def new(context, name, fields, opts) do
    # Whereami?
    otp_app = Mix.Codegen.otp_app()
    app = Mix.Codegen.context_app()
    base = Mix.Codegen.context_base(otp_app)

    # Naming
    module = Module.concat([base, name])
    basename = Codegen.Helper.Naming.underscore(name)

    name_singular =
      module
      |> Module.split()
      |> List.last()
      |> Codegen.Helper.Naming.underscore()

    name_plural = Inflex.pluralize(name)
    human_singular = Codegen.Helper.Naming.humanize(name_singular)
    human_plural = Codegen.Helper.Naming.humanize(name_plural)
    name_alias = module |> Module.split() |> List.last() |> Module.concat(nil)

    collection =
      if name_plural == name_singular, do: name_singular <> "_collection", else: name_plural

    # Migration
    table = opts[:table] || name_plural
    repo = opts[:repo] || Module.concat([base, "Repo"])
    migration_name = Macro.camelize(table)
    migration_module = migration_module()

    # File to generate
    file = Mix.Codegen.context_lib_path(app, basename <> ".ex")

    # Fields
    {_, fields} =
      Enum.map_reduce(fields, %{}, fn f, acc ->
        field = Field.new(f)
        {field, Map.put(acc, field.key, field)}
      end)

    # Web
    web_namespace = opts[:web] && Codegen.Helper.Naming.camelize(opts[:web])
    web_path = web_namespace && Codegen.Helper.Naming.underscore(web_namespace)
    route_helper = route_helper(web_path, name_singular)

    # TODO
    # opts = Keyword.merge(Application.get_env(otp_app, :generators, []), opts)

    schema = %Schema{
      # Fields
      fields: fields,

      # Helpers
      file: file,
      opts: opts,

      # Flags
      binary_id?: Map.get(opts, :binary_id, false),
      embedded?: Map.get(opts, :embedded, false),
      generate?: Map.get(opts, :generate, true),
      migration?: Map.get(opts, :migration, true),

      # Migration
      migration_module: migration_module,
      migration_name: migration_name,
      repo: repo,
      table: table,

      # Naming
      alias: name_alias,
      app: app,
      context: context,
      collection: collection,
      human_singular: human_singular,
      human_plural: human_plural,
      module: module,
      name: name,
      plural: name_plural,
      singular: name_singular,

      # Web
      route_helper: route_helper,
      web_namespace: web_namespace,
      web_path: web_path
    }

    # IEx.pry()
    IO.inspect(schema)
    schema
  end

  @doc """
  Returns the string value of the default schema param.
  """
  def default_param(%Schema{} = schema, action) do
    schema.params
    |> Map.fetch!(action)
    |> Map.fetch!(schema.params.default_key)
    |> to_string()
  end

  @doc """
  Fetches the unique attributes from attrs.
  """
  def uniques(attrs) do
    attrs
    |> Enum.filter(&String.ends_with?(&1, ":unique"))
    |> Enum.map(&(&1 |> String.split(":", parts: 2) |> hd |> String.to_atom()))
  end

  @doc """
  Parses the attrs as received by generators.
  """
  def attrs(attrs) do
    Enum.map(attrs, fn attr ->
      attr
      |> drop_unique()
      |> String.split(":", parts: 3)
      |> list_to_attr()
      |> validate_attr!()
    end)
  end

  @doc """
  Generates some sample params based on the parsed attributes.
  """
  def params(attrs, action \\ :create) when action in [:create, :update] do
    attrs
    |> Enum.reject(fn
      {_, {:references, _}} -> true
      {_, _} -> false
    end)
    |> Enum.into(%{}, fn {k, t} -> {k, type_to_default(k, t, action)} end)
  end

  @doc """
  Returns the string value for use in EEx templates.
  """
  def value(schema, field, value) do
    schema.types
    |> Map.fetch!(field)
    |> inspect_value(value)
  end

  defp inspect_value(:decimal, value), do: "Decimal.new(\"#{value}\")"
  defp inspect_value(_type, value), do: inspect(value)

  defp drop_unique(info) do
    prefix = byte_size(info) - 7

    case info do
      <<attr::size(prefix)-binary, ":unique">> -> attr
      _ -> info
    end
  end

  defp list_to_attr([key]), do: {String.to_atom(key), :string}
  defp list_to_attr([key, value]), do: {String.to_atom(key), String.to_atom(value)}

  defp list_to_attr([key, comp, value]) do
    {String.to_atom(key), {String.to_atom(comp), String.to_atom(value)}}
  end

  defp type_to_default(key, t, :create) do
    case t do
      {:array, _} -> []
      :integer -> 42
      :float -> 120.5
      :decimal -> "120.5"
      :boolean -> true
      :map -> %{}
      :text -> "some #{key}"
      :date -> ~D[2010-04-17]
      :time -> ~T[14:00:00]
      :time_usec -> ~T[14:00:00.000000]
      :uuid -> "7488a646-e31f-11e4-aace-600308960662"
      :utc_datetime -> ~U[2010-04-17T14:00:00Z]
      :utc_datetime_usec -> ~U[2010-04-17T14:00:00.000000Z]
      :naive_datetime -> ~N[2010-04-17 14:00:00]
      :naive_datetime_usec -> ~N[2010-04-17 14:00:00.000000]
      _ -> "some #{key}"
    end
  end

  defp type_to_default(key, t, :update) do
    case t do
      {:array, _} -> []
      :integer -> 43
      :float -> 456.7
      :decimal -> "456.7"
      :boolean -> false
      :map -> %{}
      :text -> "some updated #{key}"
      :date -> ~D[2011-05-18]
      :time -> ~T[15:01:01]
      :time_usec -> ~T[15:01:01.000000]
      :uuid -> "7488a646-e31f-11e4-aace-600308960668"
      :utc_datetime -> ~U[2011-05-18T15:01:01Z]
      :utc_datetime_usec -> ~U[2011-05-18T15:01:01.000000Z]
      :naive_datetime -> ~N[2011-05-18 15:01:01]
      :naive_datetime_usec -> ~N[2011-05-18 15:01:01.000000]
      _ -> "some updated #{key}"
    end
  end

  defp validate_attr!({name, :datetime}), do: validate_attr!({name, :naive_datetime})

  defp validate_attr!({name, :array}) do
    Mix.raise("""
    Codegen generators expect the type of the array to be given to #{name}:array.
    For example:

        mix codegen.gen.schema Post posts settings:array:string
    """)
  end

  defp validate_attr!({_name, type} = attr) when type in @valid_types, do: attr
  defp validate_attr!({_name, {type, _}} = attr) when type in @valid_types, do: attr

  defp validate_attr!({_, type}) do
    Mix.raise(
      "Unknown type `#{inspect(type)}` given to generator. " <>
        "The supported types are: #{@valid_types |> Enum.sort() |> Enum.join(", ")}"
    )
  end

  defp partition_attrs_and_assocs(schema_module, attrs) do
    {assocs, attrs} =
      Enum.split_with(attrs, fn
        {_, {:references, _}} ->
          true

        {key, :references} ->
          Mix.raise("""
          Codegen generators expect the table to be given to #{key}:references.
          For example:

              mix codegen.gen.schema Comment comments body:text post_id:references:posts
          """)

        _ ->
          false
      end)

    assocs =
      Enum.map(assocs, fn {key_id, {:references, source}} ->
        key = String.replace(Atom.to_string(key_id), "_id", "")
        base = schema_module |> Module.split() |> Enum.drop(-1)
        module = Module.concat(base ++ [Codegen.Helper.Naming.camelize(key)])
        {String.to_atom(key), key_id, inspect(module), source}
      end)

    {assocs, attrs}
  end

  defp schema_defaults(attrs) do
    Enum.into(attrs, %{}, fn
      {key, :boolean} -> {key, ", default: false"}
      {key, _} -> {key, ""}
    end)
  end

  defp string_attr(types) do
    Enum.find_value(types, fn
      {key, {_col, :string}} -> key
      {key, :string} -> key
      _ -> false
    end)
  end

  defp types(attrs) do
    Enum.into(attrs, %{}, fn
      {key, {root, val}} -> {key, {root, schema_type(val)}}
      {key, val} -> {key, schema_type(val)}
    end)
  end

  defp schema_type(:text), do: :string
  defp schema_type(:uuid), do: Ecto.UUID

  defp schema_type(val) do
    if Code.ensure_loaded?(Ecto.Type) and not Ecto.Type.primitive?(val) do
      Mix.raise("Unknown type `#{val}` given to generator")
    else
      val
    end
  end

  # defp indexes(table, assocs, uniques) do
  #   uniques = Enum.map(uniques, fn key -> {key, true} end)
  #   assocs = Enum.map(assocs, fn {_, key, _, _} -> {key, false} end)

  #   (uniques ++ assocs)
  #   |> Enum.uniq_by(fn {key, _} -> key end)
  #   |> Enum.map(fn
  #     {key, false} -> "create index(:#{table}, [:#{key}])"
  #     {key, true} -> "create unique_index(:#{table}, [:#{key}])"
  #   end)
  # end

  # defp migration_defaults(attrs) do
  #   Enum.into(attrs, %{}, fn
  #     {key, :boolean} -> {key, ", default: false, null: false"}
  #     {key, _} -> {key, ""}
  #   end)
  # end

  # defp sample_id(opts) do
  #   if Keyword.get(opts, :binary_id, false) do
  #     Keyword.get(opts, :sample_binary_id, "11111111-1111-1111-1111-111111111111")
  #   else
  #     -1
  #   end
  # end

  defp route_helper(web_path, singular) do
    "#{web_path}_#{singular}"
    |> String.trim_leading("_")
    |> String.replace("/", "_")
  end

  defp migration_module do
    case Application.get_env(:ecto_sql, :migration_module, Ecto.Migration) do
      migration_module when is_atom(migration_module) -> migration_module
      other -> Mix.raise("Expected :migration_module to be a module, got: #{inspect(other)}")
    end
  end
end
