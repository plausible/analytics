defmodule PlausibleWeb.Live.Components.PrimaCombobox do
  @moduledoc false
  use PlausibleWeb, :live_component

  import Prima.Combobox

  def mount(socket) do
    socket =
      socket
      |> stream(:suggestions, socket.assigns[:options] || [])

    {:ok, socket}
  end

  def update(assigns, socket) do
    selected =
      case assigns[:selected] do
        {value, display_name} -> %{value: value, display: display_name}
        _ -> socket.assigns[:selected]
      end

    socket =
      socket
      |> assign(assigns)
      |> assign(:selected, selected)
      |> assign_new(:suggestions, fn -> [] end)

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

  def render(assigns) do
    ~H"""
    <div
      id={"combobox-container-#{@id}"}
      class="relative [&_[data-prima-ref=options-wrapper]]:w-full"
    >
      <.combobox :let={input_value} name={@submit_name} id={@id} class={@class} selections={@selected}>
        <.combobox_input
          value={input_value}
          class={
            Enum.join(
              [
                "peer input-base input-md w-full pr-10",
                @input_class
              ],
              " "
            )
          }
          on_search="async_combobox_search"
          phx-target={@myself}
          placeholder={@placeholder}
        />

        <.spinner class="absolute inset-y-3 right-3.5 invisible phx-hook-loading:peer-focus:visible" />

        <.combobox_options
          id={"input-picker-dropdown-#{@id}"}
          phx-update="replace"
          offset={4}
          class={
            Enum.join(
              [
                "relative z-50 max-h-60 w-full overflow-y-auto overflow-x-hidden p-1 rounded-md shadow-lg bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-800 focus:outline-hidden",
                @dropdown_class
              ],
              " "
            )
          }
        >
          <div class="flex flex-col gap-0.5">
            <%= for {idx, {value, display_name, opts}} <- @suggestions do %>
              <div
                :if={opts[:separator?]}
                class="my-0.5 -mx-1 border-b border-gray-200 dark:border-gray-700"
              />

              <div
                :if={opts[:title]}
                class="px-4 py-2.5 truncate text-xs uppercase font-medium text-gray-500 dark:text-gray-400"
              >
                {opts[:title]}
              </div>

              <.combobox_option
                id={"input-picker-dropdown-#{@id}-option-#{idx}"}
                class="px-4 py-2.5 leading-5 rounded-md text-sm text-gray-800 dark:text-gray-200 hover:text-gray-900 dark:hover:text-gray-100 cursor-pointer select-none data-focus:bg-gray-100 data-focus:text-gray-900 dark:data-focus:bg-gray-700 dark:data-focus:text-gray-100 data-selected:bg-gray-100 data-selected:text-gray-900 dark:data-selected:bg-gray-700 dark:data-selected:text-gray-100"
                value={value}
                display={display_name}
              >
                <span class="flex items-center gap-2">
                  <.icon :if={opts[:icon]} name={opts[:icon]} />
                  <span class="truncate">{display_name}</span>
                </span>
              </.combobox_option>
            <% end %>

            <div
              :if={@suggestions == []}
              class="px-4 py-2.5 text-sm text-gray-500 dark:text-gray-400 cursor-default select-none"
            >
              No matches found. Try searching for something different.
            </div>
          </div>
        </.combobox_options>
      </.combobox>
    </div>
    """
  end

  @icons %{
    cursor: &PlausibleWeb.Components.Icons.cursor_icon/1,
    eye: &Heroicons.eye/1
  }

  defp icon(assigns) do
    {name, assigns} = Map.pop(assigns, :name)

    assigns = assign(assigns, :class, "size-4 shrink-0")

    if icon_component = @icons[name] do
      icon_component.(assigns)
    else
      ~H""
    end
  end

  def handle_event("async_combobox_search", %{"query" => query}, socket) do
    options = socket.assigns[:options] || []

    suggestions =
      if suggest_fun = socket.assigns[:suggest_fun] do
        suggest_fun.(query, options)
      else
        Enum.filter(options, fn option ->
          String.contains?(String.downcase(option), String.downcase(query))
        end)
      end
      |> Enum.map(&{hash(&1), &1})

    {:noreply, assign(socket, :suggestions, suggestions)}
  end

  defp hash(value) do
    value
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:md5, &1))
    |> Base.encode16()
    |> String.downcase()
  end
end
