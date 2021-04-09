defmodule Codegen.Template do
  defstruct format: :eex,
            source_path: nil,
            target_path: nil,
            force_overwrite?: false,
            assigns: nil

  @type format :: :eex | :text
  @type t :: %__MODULE__{
          format: format,
          source_path: String.t(),
          target_path: String.t(),
          force_overwrite?: boolean(),
          assigns: map()
        }
end
