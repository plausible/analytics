defmodule PlausibleWeb.Components.PrimaDropdown do
  @moduledoc false
  alias Prima.Dropdown
  use Phoenix.Component

  @dropdown_item_icon_base_class "text-gray-600 dark:text-gray-400 group-hover/item:text-gray-900 group-data-focus/item:text-gray-900 dark:group-hover/item:text-gray-100 dark:group-data-focus/item:text-gray-100"

  defdelegate dropdown(assigns), to: Prima.Dropdown
  defdelegate dropdown_trigger(assigns), to: Prima.Dropdown

  slot(:inner_block, required: true)

  # placement: bottom-end should probably be default in prima. Feels more natural
  # for dropdown menus than bottom-start which is the current default
  def dropdown_menu(assigns) do
    ~H"""
    <Dropdown.dropdown_menu
      placement="bottom-end"
      class="bg-white rounded-md shadow-lg ring-1 ring-black/5 focus:outline-none p-1.5 dark:bg-gray-800"
    >
      {render_slot(@inner_block)}
    </Dropdown.dropdown_menu>
    """
  end

  attr(:as, :any, default: nil)
  attr(:disabled, :boolean, default: false)
  attr(:rest, :global, include: ~w(navigate patch href))
  slot(:inner_block, required: true)

  def dropdown_item(assigns) do
    ~H"""
    <Dropdown.dropdown_item
      as={@as}
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
