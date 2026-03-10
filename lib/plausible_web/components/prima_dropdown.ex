defmodule PlausibleWeb.Components.PrimaDropdown do
  @moduledoc false
  alias Prima.Dropdown
  use Phoenix.Component

  @dropdown_item_icon_base_class "text-gray-600 dark:text-gray-400 group-hover/item:text-gray-900 group-data-focus/item:text-gray-900 dark:group-hover/item:text-gray-100 dark:group-data-focus/item:text-gray-100"

  @trigger_button_base_class "whitespace-nowrap truncate inline-flex items-center justify-between gap-x-2 text-sm font-medium rounded-md cursor-pointer disabled:cursor-not-allowed"

  @trigger_button_themes %{
    "primary" =>
      "border border-indigo-600 bg-indigo-600 text-white hover:bg-indigo-700 focus-visible:outline-indigo-600 disabled:bg-indigo-400/60 disabled:dark:bg-indigo-600/30 disabled:dark:text-white/35",
    "secondary" =>
      "border border-gray-300 dark:border-gray-700 bg-white dark:bg-gray-700 text-gray-800 dark:text-gray-100 hover:border-gray-400/60 hover:text-gray-900 dark:hover:border-gray-500 dark:hover:text-white disabled:text-gray-700/40 dark:disabled:text-gray-500 dark:disabled:bg-gray-800 dark:disabled:border-gray-800",
    "ghost" =>
      "text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-gray-100 disabled:text-gray-500 disabled:dark:text-gray-600"
  }

  @trigger_button_sizes %{
    "sm" => "px-3 py-2",
    "md" => "px-3.5 py-2.5"
  }

  defdelegate dropdown(assigns), to: Prima.Dropdown

  attr(:id, :string, required: true)
  attr(:theme, :string, default: "secondary")
  attr(:size, :string, default: "md")
  attr(:class, :string, default: "")
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def dropdown_trigger(assigns) do
    assigns =
      assign(assigns,
        computed_class: [
          @trigger_button_base_class,
          @trigger_button_sizes[assigns.size],
          @trigger_button_themes[assigns.theme],
          assigns.class
        ]
      )

    ~H"""
    <Dropdown.dropdown_trigger id={@id} class={@computed_class} {@rest}>
      {render_slot(@inner_block)}
    </Dropdown.dropdown_trigger>
    """
  end

  attr(:id, :string, required: true)
  slot(:inner_block, required: true)

  # placement: bottom-end should probably be default in prima. Feels more natural
  # for dropdown menus than bottom-start which is the current default
  def dropdown_menu(assigns) do
    ~H"""
    <Dropdown.dropdown_menu
      id={@id}
      placement="bottom-end"
      class="bg-white rounded-md shadow-lg ring-1 ring-black/5 focus:outline-none p-1.5 dark:bg-gray-800"
    >
      {render_slot(@inner_block)}
    </Dropdown.dropdown_menu>
    """
  end

  attr(:as, :any, default: nil)
  attr(:id, :string, required: true)
  attr(:disabled, :boolean, default: false)
  attr(:rest, :global, include: ~w(navigate patch href))
  slot(:inner_block, required: true)

  def dropdown_item(assigns) do
    ~H"""
    <Dropdown.dropdown_item
      as={@as}
      id={@id}
      disabled={@disabled}
      class="group/item z-50 flex items-center gap-x-2 min-w-max w-full rounded-md pl-3 pr-5 py-2 text-gray-700 text-sm dark:text-gray-300 data-focus:bg-gray-100 dark:data-focus:bg-gray-700 data-focus:text-gray-900 dark:data-focus:text-gray-100"
      {@rest}
    >
      {render_slot(@inner_block)}
    </Dropdown.dropdown_item>
    """
  end

  def dropdown_item_icon_class(size \\ "size-4") do
    "#{size} #{@dropdown_item_icon_base_class}"
  end
end
