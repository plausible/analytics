defmodule PlausibleWeb.Live.Components.PrimaModal do
  @moduledoc false
  use PlausibleWeb, :component
  alias Prima.Modal

  attr :id, :string, required: true
  attr :use_portal?, :boolean, default: Mix.env() not in [:test, :ce_test]
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <Modal.modal portal={@use_portal?} id={@id}>
      <Modal.modal_overlay
        transition_enter={{"ease-out duration-300", "opacity-0", "opacity-100"}}
        transition_leave={{"ease-in duration-200", "opacity-100", "opacity-0"}}
        class="fixed inset-0 z-[9999] bg-gray-500/75 dark:bg-gray-800/75"
      />

      <div class="fixed inset-0 z-[9999] w-screen overflow-y-auto sm:pt-[10vmin]">
        <div class="flex min-h-full items-end justify-center p-4 sm:items-start sm:p-0">
          <Modal.modal_panel
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
