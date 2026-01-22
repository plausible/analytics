defmodule PlausibleWeb.Live.Dashboard.PageFilterModal do
  @moduledoc """
  Live component for page filter modal.
  """

  use PlausibleWeb, :live_component

  import PlausibleWeb.Components.Dashboard.Base

  alias Plausible.Stats.ParsedQueryParams

  defmodule PageForm do
    use Ecto.Schema

    import Ecto.Changeset

    embedded_schema do
      field :operator, Ecto.Enum, values: [:is, :is_not, :contains, :does_not_contain]
      field :path, :string
    end

    def changeset(form \\ %__MODULE__{}, params) do
      form
      |> cast(params, [:operator, :path])
    end
  end

  def update(assigns, socket) do
    page_form =
      assigns.params
      |> load_filter("event:page")
      |> PageForm.changeset()
      |> to_form()

    socket =
      assign(socket,
        site: assigns.site,
        params: assigns.params,
        open?: assigns.open?,
        connected?: assigns.connected?,
        page_form: page_form,
        on_apply: assigns.on_apply
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.modal
        id="page-filter-modal"
        on_close={JS.push("close_modal")}
        show={@open?}
        ready={@connected?}
      >
        <.modal_title>
          <div class="flex items-center justify-between gap-3">
            <h1 class="text-base md:text-lg font-bold dark:text-gray-100">Filter by Page</h1>
            <button
              phx-click={Prima.Modal.JS.close()}
              type="button"
              aria-label="Close modal"
              class="text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 20 20"
                fill="currentColor"
                aria-hidden="true"
                data-slot="icon"
                class="size-5"
              >
                <path d="M6.28 5.22a.75.75 0 0 0-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 1 0 1.06 1.06L10 11.06l3.72 3.72a.75.75 0 1 0 1.06-1.06L11.06 10l3.72-3.72a.75.75 0 0 0-1.06-1.06L10 8.94 6.28 5.22Z">
                </path>
              </svg>
            </button>
          </div>

          <div class="mt-2 md:mt-4 border-b border-gray-300 dark:border-gray-700"></div>
        </.modal_title>

        <.form
          :let={f}
          for={@page_form}
          phx-submit="apply_filters"
          phx-target={@myself}
          class="flex flex-col pl-8 pr-8"
        >
          <div class="mt-6">
            <div class="text-sm font-medium text-gray-700 dark:text-gray-300">Page</div>
            <div class="grid mt-1 grid-cols-11">
              <div class="col-span-3">
                <.input
                  type="select"
                  field={f[:operator]}
                  options={[
                    {"is", :is},
                    {"is not", :is_not},
                    {"contains", :contains},
                    {"does not contain", :contains_not}
                  ]}
                />
              </div>
              <div class="col-span-8 ml-2">
                <.input
                  type="text"
                  field={f[:path]}
                />
              </div>
            </div>
          </div>

          <div class="mt-6 mb-3 flex gap-x-4 items-center justify-start">
            <button type="submit" class="button !px-3">Apply filter</button>
            <button
              type="button"
              class="flex items-center py-1 text-sm font-medium whitespace-nowrap text-indigo-600 dark:text-indigo-500 hover:text-indigo-700 dark:hover:text-indigo-600"
            >
              Remove filters
            </button>
          </div>
        </.form>
      </.modal>
    </div>
    """
  end

  def handle_event("apply_filters", params, socket) do
    page_filter =
      params["page_form"]
      |> PageForm.changeset()
      |> Ecto.Changeset.apply_changes()

    new_params =
      ParsedQueryParams.add_or_replace_filter(socket.assigns.params, [
        page_filter.operator,
        "event:page",
        [page_filter.path]
      ])

    socket.assigns.on_apply.(new_params)

    {:noreply, socket}
  end

  defp load_filter(params, field) do
    [operator, _, [value]] =
      Enum.find(params.filters, [:is, field, [""]], fn
        [_operator, ^field, [_value]] -> true
        _ -> false
      end)

    %{operator: operator, path: value}
  end
end
