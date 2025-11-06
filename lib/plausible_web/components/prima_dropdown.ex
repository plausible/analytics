defmodule PlausibleWeb.Components.PrimaDropdown do
  alias Prima.Dropdown
  use Phoenix.Component

  defdelegate dropdown(assigns), to: Prima.Dropdown
  defdelegate dropdown_trigger(assigns), to: Prima.Dropdown

  slot :inner_block, required: true

  # placement: bottom-end should probably be default in prima. Feels more natural
  # for dropdown menus than bottom-start which is the current default
  def dropdown_menu(assigns) do
    ~H"""
    <Dropdown.dropdown_menu
      placement="bottom-end"
      class="p-1.5 rounded-md bg-white shadow-xs ring-1 ring-gray-300 focus:outline-none"
    >
      {render_slot(@inner_block)}
    </Dropdown.dropdown_menu>
    """
  end

  attr :as, :any, default: nil
  attr :disabled, :boolean, default: false
  attr :rest, :global, include: ~w(navigate patch href)
  slot :inner_block, required: true

  def dropdown_item(assigns) do
    ~H"""
    <Dropdown.dropdown_item
      as={@as}
      disabled={@disabled}
      class="rounded-md text-gray-700 data-focus:bg-gray-100 data-focus:text-gray-900 block px-4 py-2 text-sm"
      {@rest}
    >
      {render_slot(@inner_block)}
    </Dropdown.dropdown_item>
    """
  end
end
