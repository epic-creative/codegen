defmodule Codegen.Gen.Channel do
  @moduledoc """
  Generate a Phoenix Channel
  """
  @behaviour Codegen.Generator

  @template_paths [".", :codegen]
  @source_dir "priv/templates/codegen.gen.channel"

  def build_list(list) do
    Enum.map(list, fn name -> build(name) end)
  end

  @impl Codegen.Generator
  def build(name) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix codegen.gen.channel can only be run inside an application directory")
    end

    context_app = Mix.Codegen.context_app()
    assigns = Mix.Codegen.inflect(name)
    assigns = Keyword.put(assigns, :module, "#{assigns[:web_module]}.#{assigns[:scoped]}")
    web_prefix = Mix.Codegen.web_path(context_app)
    test_prefix = Mix.Codegen.web_test_path(context_app)

    %{
      # channel_name: name,
      context_app: context_app,
      # web_prefix: web_prefix,
      # test_prefix: test_prefix,
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
      Mix.Codegen.write_templates(opts.template_paths, opts.source_dir, opts.templates)
    end)
  end

  @impl Codegen.Generator
  def generate(opts) when is_map(opts) do
    Mix.Codegen.write_templates(opts.template_paths, opts.source_dir, opts.templates)

    post_install(opts)
  end

  @impl Codegen.Generator
  def post_install(opts) do
    """
    Add the channel to your `#{Mix.Codegen.web_path(opts.context_app, "channels/user_socket.ex")}` handler, for example:

        channel "#{opts.assigns[:singular]}:lobby", #{opts.assigns[:module]}Channel
    """
  end
end
