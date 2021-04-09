defmodule Codegen.Gen.Channel do
  @moduledoc """
  Generate a Phoenix Channel
  """
  @behaviour Codegen.Generator

  @template_paths [".", :codegen]
  @source_dir "priv/templates/codegen.gen.channel"

  def build(name_list) when is_list(name_list) do
    Enum.map(name_list, fn name -> build(name) end)
  end

  @impl Codegen.Generator
  def build(name) when is_binary(name) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix codegen.gen.channel can only be run inside an application directory")
    end

    context_app = Codegen.context_app()
    assigns = Codegen.inflect(name)
    assigns = Keyword.put(assigns, :module, "#{assigns[:web_module]}.#{assigns[:scoped]}")
    web_prefix = Codegen.web_path(context_app)
    test_prefix = Codegen.web_test_path(context_app)

    %{
      context_app: context_app,
      assigns: assigns,
      source_dir: @source_dir,
      template_paths: @template_paths,
      templates: [
        {:eex, "channel.ex", Path.join(web_prefix, "channels/#{assigns[:path]}_channel.ex"),
         false, assigns},
        {:eex, "channel_test.exs",
         Path.join(test_prefix, "channels/#{assigns[:path]}_channel_test.exs"), true, assigns}
      ]
    }
  end

  def generate(list) when is_list(list) do
    Enum.each(list, fn opts ->
      Codegen.write_templates(opts.template_paths, opts.source_dir, opts.templates)
    end)
  end

  @impl Codegen.Generator
  def generate(opts) when is_map(opts) do
    Codegen.write_templates(opts.template_paths, opts.source_dir, opts.templates)

    post_install(opts)
  end

  @impl Codegen.Generator
  def post_install(opts) do
    """
    Add the channel to your `#{Codegen.web_path(opts.context_app, "channels/user_socket.ex")}` handler, for example:

        channel "#{opts.assigns[:singular]}:lobby", #{opts.assigns[:module]}Channel
    """
  end
end
