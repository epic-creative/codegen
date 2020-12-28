defmodule Codegen.Generator do
  @moduledoc """
  Behavior for a Codegen Generator
  """

  @doc """
  Given a single Code Generator configuration, build a single Generator Directive
  """
  @callback build(Keyword.t()) :: Map

  @doc """
  Post Installation instructions provided by the Generator
  """
  @callback generate(any()) :: String.t()
end
