defmodule PlausibleWeb.Live.Components.Modal do
  use Phoenix.Component, global_prefixes: ~w(x-)

  alias Phoenix.LiveView.JS

  def live_modal(assigns) do
    ~H"""
    <div
      id={@id}
      class="[&[data-phx-ref]_div.modal-dialog]:hidden [&[data-phx-ref]_div.modal-loading]:block"
      data-modal
      x-cloak
      x-data="{ 
        modalOpen: false, 
        openModal() {
          this.modalOpen = true;
        },
        closeModal() { 
          this.modalOpen = false; 
          liveSocket.execJS($el, $el.dataset.onclose);
        }
      }"
      x-on:open-modal.window={"if ($event.detail === '#{@id}') openModal()"}
      x-on:close-modal.window={"if ($event.detail === '#{@id}') closeModal()"}
      data-onclose={JS.push("reset", target: @target)}
      x-on:keydown.escape.window="closeModal()"
    >
      <div x-show="modalOpen" class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity z-50">
      </div>
      <div
        x-show="modalOpen"
        class="fixed inset-0 flex items-center justify-center mt-16 z-50 overflow-y-auto overflow-x-hidden"
      >
        <div class="modal-dialog w-1/2 h-full" x-on:click.outside="closeModal()">
          <%= render_slot(@inner_block) %>
        </div>
        <div class="modal-loading hidden w-1/2 h-full">
          <div class="max-w-md w-full mx-auto bg-white dark:bg-gray-800 shadow-md rounded px-8 pt-6 pb-8 mb-4 mt-8">
            Loading...
          </div>
        </div>
      </div>
    </div>
    """
  end

  def close(socket, id) do
    Phoenix.LiveView.push_event(socket, "close-modal", %{id: id})
  end
end
