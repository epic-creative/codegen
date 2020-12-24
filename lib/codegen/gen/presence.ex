defmodule Codegen.Gen.Presence do
  @template_paths [".", :codegen]
  @source_dir "priv/templates/codegen.gen.presence"

  def build_list(list) do
    Enum.map(list, fn name -> build(name) end)
  end

  @impl Codegen.Generator
  def build(name) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix codegen.gen.presence can only be run inside an application directory")
    end

    context_app = Mix.Codegen.context_app()
    otp_app = Mix.Codegen.otp_app()
    web_prefix = Mix.Codegen.web_path(context_app)
    inflections = Mix.Codegen.inflect(name)

    inflections =
      Keyword.put(inflections, :module, "#{inflections[:web_module]}.#{inflections[:scoped]}")

    assigns =
      inflections ++
        [
          otp_app: otp_app,
          pubsub_server: Module.concat(inflections[:base], "PubSub")
        ]

    %{
      otp_app: otp_app,
      context_app: context_app,
      assigns: assigns,
      source_dir: @source_dir,
      template_paths: @template_paths,
      templates: [
        {:eex, "presence.ex", Path.join(web_prefix, "channels/#{assigns[:path]}.ex"), true,
         assigns}
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
    Add your new module to your supervision tree,
    in lib/#{opts.otp_app}/application.ex:

        children = [
          ...
          #{opts.assigns[:module]}
        ]

    You're all set! See the Codegen.Presence docs for more details:
    http://hexdocs.pm/codegen/Codegen.Presence.html
    """
  end
end
