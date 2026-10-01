defmodule PlausibleWeb.Live.Components.PrimaCombobox do
  @moduledoc false
  use PlausibleWeb, :live_component

  import Prima.Combobox

  def mount(socket) do
    socket =
      socket
      |> stream_configure(:suggestions, dom_id: &"suggestions-#{hash(&1)}")
      |> stream(:suggestions, socket.assigns[:options] || [])

    {:ok, socket}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(
        :enable_callbacks,
        !!(assigns[:on_selection_added] || assigns[:on_selection_removed])
      )

    {:ok, socket}
  end

  attr(:id, :string, required: true)
  attr(:selected, :any)
  attr(:placeholder, :string, default: "Select option or search by typing")
  attr(:class, :string, default: "")
  attr(:input_class, :string, default: "")
  attr(:dropdown_class, :string, default: "")
  attr(:submit_name, :string, required: true)
  attr(:options, :list, default: [])
  attr(:callbacks, :boolean, default: false)

  def render(assigns) do
    ~H"""
    <div id={"combobox-container-#{@id}"}>
      <.combobox id={@id} class={@class} callbacks={@enable_callbacks}>
        <div class="relative pl-2 pr-8 py-1 w-full dark:bg-gray-750 dark:text-gray-300 rounded-md shadow-xs border border-gray-300 dark:border-gray-750 focus-within:outline-none focus-within:ring-3 focus-within:ring-indigo-500/20 dark:focus-within:ring-indigo-500/25 focus-within:border-indigo-500">
          <.combobox_input
            name={@submit_name}
            class={
              Enum.join(
                [
                  "text-sm [&.phx-change-loading+svg.spinner]:block border-none py-1.5 px-1.5 w-full inline-block rounded-md focus:outline-hidden focus:ring-0",
                  @input_class
                ],
                " "
              )
            }
            phx-change="async_combobox_search"
            phx-target={@myself}
            placeholder={@placeholder}
          />

          <.spinner class="spinner absolute inset-y-3 right-8 invisible peer-[.phx-change-loading]:visible" />

          <.combobox_options
            id={"input-picker-dropdown-#{@id}"}
            phx-update="replace"
            offset={4}
            class={
              Enum.join([
                "relative max-h-60 w-64 overflow-y-auto overflow-x-hidden rounded-md bg-white py-1 text-base shadow-lg ring-1 ring-gray-200 focus:outline-none sm:text-sm z-50",
                @dropdown_class
              ])
            }
          >
            <%= for {idx, {value, display_name, opts}} <- @streams.suggestions do %>
              <hr :if={opts[:separator?]} class="mt-2" />

              <div
                :if={opts[:title]}
                class="m-2 truncate text-left text-xs uppercase text-gray-500 dark:text-gray-400 font-semibold"
              >
                {opts[:title]}
              </div>

              <.combobox_option
                id={"input-picker-dropdown-#{@id}-option-#{idx}"}
                class="relative whitespace-nowrap cursor-default select-none py-2 pl-3 pr-9 text-gray-900 data-focus:bg-indigo-600 data-focus:text-white flex gap-2"
                value={value}
                display={display_name}
              >
                <.icon :if={opts[:icon]} name={opts[:icon]} />
                <span :if={!opts[:icon]} class="inline-block size-4"></span>
                <span class="inline-block">{display_name}</span>
              </.combobox_option>
            <% end %>
          </.combobox_options>
        </div>
      </.combobox>
    </div>
    """
  end

  @icons %{
    cursor: &PlausibleWeb.Components.Icons.cursor_icon/1,
    pencil: &PlausibleWeb.Components.Icons.pencil_icon/1
  }

  defp icon(assigns) do
    {name, assigns} = Map.pop(assigns, :name)

    assigns = assign(assigns, :class, "inline-block size-4")

    if icon_component = @icons[name] do
      icon_component.(assigns)
    else
      ~H""
    end
  end

  def handle_event("async_combobox_search", params, socket) do
    input = get_in(params, params["_target"])
    options = socket.assigns[:options] || []

    suggestions =
      if suggest_fun = socket.assigns[:suggest_fun] do
        suggest_fun.(input, options)
      else
        Enum.filter(options, fn option ->
          String.contains?(String.downcase(option), String.downcase(input))
        end)
      end

    {:noreply, stream(socket, :suggestions, suggestions, reset: true)}
  end

  def handle_event("add_selection", %{"id" => id, "value" => value}, socket) do
    if cb = socket.assigns[:on_selection_added] do
      cb.(value, id)
    end

    {:noreply, socket}
  end

  def handle_event("remove_selection", %{"id" => id, "value" => value}, socket) do
    if cb = socket.assigns[:on_selection_removed] do
      cb.(value, id)
    end

    {:noreply, socket}
  end

  defp hash(value) do
    value
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:md5, &1))
    |> Base.encode16()
    |> String.downcase()
  end
end
