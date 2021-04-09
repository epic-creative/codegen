defmodule Codegen.Generator do
  @moduledoc """
  Behavior for a Codegen Generator
  """
  alias Codegen.Helper.Field
  alias Codegen.Resolver

  @doc """
  Given a single Code Generator configuration, build a single Generator Directive
  """
  @callback build(any()) :: Map

  @doc """
  Post Installation instructions provided by the Generator
  """
  @callback generate(any()) :: String.t()

  # require IEx

  @enforce_keys [:source_dir]
  defstruct action: :add,
            source_dir: nil,
            template_paths: [".", :codegen],
            templates: nil

  @type action :: :add | :edit | :remove
  @type t :: %__MODULE__{
          action: action,
          source_dir: String.t(),
          template_paths: [],
          templates: []
        }

  @doc false
  defmacro __using__(_) do
    quote location: :keep do
      import Codegen.Generator
      # @before_compile Codegen.Generator
    end
  end

  defmacro assign(type, name, opts, do: block) do
    expand_assign(type, name, opts, block)
  end

  defmacro context(name, opts, do: block) do
    expand_assign(:context, name, opts, block)
  end

  defmacro schema(name, opts, do: block) do
    expand_assign(:schema, name, opts, block)
  end

  def field(name, opts) do
    expand_assign(:field, name, opts)
  end

  def channel(name, opts \\ []) do
    expand_assign(:channel, name, opts)
  end

  def presence(name, opts \\ []) do
    expand_assign(:presence, name, opts)
  end

  defp expand_assign(type, name, opts) do
    Resolver.add_definition(type, name, opts)
  end

  defp expand_assign(type, name, opts, block) do
    quote do
      Resolver.start_definition(type, name, opts)
      unquote(block)
      Resolver.end_definition()
    end
  end

  # defmacro context(name, generator, do: block) do
  #   quote do
  #     name = unquote(name)
  #     require IEx
  #     IEx.pry()
  #     unquote(block)
  #   end
  # end

  # defmacro schema(name, options \\ %{}, do: block) do
  #   IEx.pry()

  #   quote do
  #     # Start new Schema
  #     return = unquote(block)
  #     # End Schema
  #   end
  # end

  # def field(name, type, options \\ %{}) do
  #   # Add Field to Schema
  #   Field.new(name, type, options)
  # end

  # def field(field_definition) do
  #   Field.new(field_definition)
  # end
end
