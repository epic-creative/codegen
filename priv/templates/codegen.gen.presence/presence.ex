defmodule <%= module %> do
  @moduledoc """
  Provides presence tracking to channels and processes.

  See the [`Codegen.Presence`](http://hexdocs.pm/codegen/Codegen.Presence.html)
  docs for more details.
  """
  use Codegen.Presence, otp_app: <%= inspect otp_app %>,
                        pubsub_server: <%= inspect pubsub_server %>
end
