defmodule <%= inspect context.web_module %>.ModalComponent do
  use <%= inspect context.web_module %>, :live_component

  @impl true
  def render(assigns) do
    ~L"""
    <div id="<%%= @id %>" class="codegen-modal"
      codegen-capture-click="close"
      codegen-window-keydown="close"
      codegen-key="escape"
      codegen-target="#<%%= @id %>"
      codegen-page-loading>

      <div class="codegen-modal-content">
        <%%= live_patch raw("&times;"), to: @return_to, class: "codegen-modal-close" %>
        <%%= live_component @socket, @component, @opts %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("close", _, socket) do
    {:noreply, push_patch(socket, to: socket.assigns.return_to)}
  end
end
