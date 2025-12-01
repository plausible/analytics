defmodule PlausibleWeb.Live.Dashboard.Details.Pages do
  @moduledoc """
  Component for detailed pages breakdown.
  """

  use PlausibleWeb, :live_component

  alias PlausibleWeb.Live.Components.PrimaModal

  def update(_assigns, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <PrimaModal.modal
        id="details-pages-breakdown-modal"
        on_close={JS.dispatch("dashboard:close_modal")}
      >
        <div class="flex flex-col gap-y-4 text-center sm:text-left">
          <PrimaModal.modal_title>
            Pages
          </PrimaModal.modal_title>
        </div>
        <div class="text-sm text-gray-100">
          Some content will come here real soon now.
        </div>
      </PrimaModal.modal>
    </div>
    """
  end
end
