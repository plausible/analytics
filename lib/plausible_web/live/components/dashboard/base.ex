defmodule PlausibleWeb.Components.Dashboard.Base do
  @moduledoc """
  Common components for dasbhaord.
  """

  use PlausibleWeb, :component

  alias Prima.Modal

  attr :to, :string, required: true
  attr :class, :string, default: ""
  attr :rest, :global

  slot :inner_block, required: true

  def dashboard_link(assigns) do
    ~H"""
    <.link
      data-type="dashboard-link"
      patch={@to}
      class={@class}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :style, :string, default: ""
  attr :background_class, :string, default: ""
  attr :width, :integer, required: true
  attr :max_width, :integer, required: true

  slot :inner_block, required: true

  def bar(assigns) do
    width_percent = assigns.width / assigns.max_width * 100

    assigns = assign(assigns, :width_percent, width_percent)

    ~H"""
    <div class="w-full h-full relative" style={@style}>
      <div
        class={"absolute top-0 left-0 h-full rounded-sm transition-[width] duration-200 ease-in-out #{@background_class || ""}"}
        data-test-id="bar-indicator"
        style={"width: #{@width_percent}%"}
      >
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :id, :string, required: true
  attr :on_close, JS, default: %JS{}
  attr :show, :boolean, default: false
  attr :ready, :boolean, default: true
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      :if={@show and not @ready}
      transition_enter={JS.show(transition: {"ease-out duration-300", "opacity-0", "opacity-100"})}
      class="fixed inset-0 z-[9999] bg-gray-500/75 dark:bg-gray-800/75"
    >
    </div>
    <div
      :if={@show and not @ready}
      class="fixed inset-0 z-[9999] w-screen overflow-y-auto sm:pt-[10vmin]"
    >
      <div class="flex min-h-full items-end justify-center p-4 sm:items-start sm:p-0">
        <div class="mx-auto loading">
          <div></div>
        </div>
      </div>
    </div>
    <Modal.modal portal={false} id={@id} on_close={@on_close} show={@show}>
      <Modal.modal_overlay
        transition_enter={{"ease-out duration-300", "opacity-0", "opacity-100"}}
        transition_leave={{"ease-in duration-200", "opacity-100", "opacity-0"}}
        class="fixed inset-0 z-[9999] bg-gray-500/75 dark:bg-gray-800/75"
      />

      <div class="fixed inset-0 z-[9999] w-screen overflow-y-auto sm:pt-[10vmin]">
        <div class="flex min-h-full items-end justify-center p-4 sm:items-start sm:p-0">
          <Modal.modal_loader>
            <div :if={not @ready} class="mx-auto loading">
              <div></div>
            </div>
          </Modal.modal_loader>
          <Modal.modal_panel
            :if={@ready}
            id={@id <> "-panel"}
            class="relative overflow-hidden rounded-lg bg-white dark:bg-gray-900 text-left shadow-xl sm:w-full sm:max-w-lg"
            transition_enter={
              {"ease-out duration-300", "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
               "opacity-100 translate-y-0 sm:scale-100"}
            }
            transition_leave={
              {"ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
               "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
            }
          >
            {render_slot(@inner_block)}
          </Modal.modal_panel>
        </div>
      </div>
    </Modal.modal>
    """
  end

  slot :inner_block, required: true

  def modal_title(assigns) do
    ~H"""
    <Modal.modal_title as={&h2/1} class="text-lg font-semibold text-gray-900 dark:text-gray-100">
      {render_slot(@inner_block)}
    </Modal.modal_title>
    """
  end
end
