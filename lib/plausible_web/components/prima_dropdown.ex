defmodule PlausibleWeb.Components.PrimaDropdown do
  @moduledoc false
  alias Prima.Dropdown
  use Phoenix.Component

  @dropdown_item_icon_base_class "text-gray-600 dark:text-gray-400 group-hover/item:text-gray-900 group-data-focus/item:text-gray-900 dark:group-hover/item:text-gray-100 dark:group-data-focus/item:text-gray-100"

  defdelegate dropdown(assigns), to: Prima.Dropdown
  defdelegate dropdown_trigger(assigns), to: Prima.Dropdown

  slot(:inner_block, required: true)

  def dropdown_menu(assigns) do
    ~H"""
    <Dropdown.dropdown_menu class="bg-white rounded-md shadow-lg ring-1 ring-black/5 focus:outline-none p-1.5 dark:bg-gray-800">
      {render_slot(@inner_block)}
    </Dropdown.dropdown_menu>
    """
  end

  attr(:as, :any, default: nil)
  attr(:disabled, :boolean, default: false)
  attr(:class, :string, default: "")
  attr(:rest, :global, include: ~w(navigate patch href))
  slot(:inner_block, required: true)

  def dropdown_item(assigns) do
    classes = [
      "flex items-center gap-x-2 min-w-max w-full rounded-md px-3 py-1.5 text-gray-700 text-sm dark:text-gray-300 data-focus:bg-gray-100 dark:data-focus:bg-gray-700 data-focus:text-gray-900 dark:data-focus:text-gray-100",
      assigns.class
    ]

    assigns = assign(assigns, :class, Enum.join(classes, " "))

    ~H"""
    <Dropdown.dropdown_item
      as={@as}
      disabled={@disabled}
      class={@class}
      {@rest}
    >
      {render_slot(@inner_block)}
    </Dropdown.dropdown_item>
    """
  end

  attr(:class, :string, default: "")
  attr(:rest, :global)

  def dropdown_separator(assigns) do
    classes = ["mx-3.5 my-1 h-px border-0 bg-gray-950/5 dark:bg-white/10", assigns.class]
    assigns = assign(assigns, :classes, Enum.join(classes, " "))

    ~H"""
    <Dropdown.dropdown_separator class={@classes} {@rest} />
    """
  end

  attr(:class, :string, default: "")
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def dropdown_section(assigns) do
    ~H"""
    <Dropdown.dropdown_section class={@class} {@rest}>
      {render_slot(@inner_block)}
    </Dropdown.dropdown_section>
    """
  end

  attr(:class, :string, default: "")
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def dropdown_heading(assigns) do
    classes = ["px-3 py-1.5 text-xs text-gray-500 dark:text-gray-400", assigns.class]
    assigns = assign(assigns, :classes, Enum.join(classes, " "))

    ~H"""
    <Dropdown.dropdown_heading class={@classes} {@rest}>
      {render_slot(@inner_block)}
    </Dropdown.dropdown_heading>
    """
  end

  def dropdown_item_icon_class(size \\ "size-4") do
    "#{size} #{@dropdown_item_icon_base_class}"
  end
end
