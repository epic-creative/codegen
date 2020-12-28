defmodule Codegen.Generator do
  @moduledoc """
  Behavior for a Codegen Generator
  """

  @doc """
  Given a list of Code Generator configurations, build Generator Directive
  """
  @callback build_list(List.t()) :: [Map.t()]

  @doc """
  Given a single Code Generator configuration, build a single Generator Directive
  """
  @callback build(Keyword.t()) :: Map

  @doc """
  Post Installation instructions provided by the Generator
  """
  @callback post_install(any()) :: String.t()
end
