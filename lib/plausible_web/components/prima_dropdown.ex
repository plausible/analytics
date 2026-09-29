defmodule PlausibleWeb.Components.PrimaDropdown do
  @moduledoc false
  alias Prima.Dropdown
  use Phoenix.Component

  @dropdown_item_icon_base_class "text-gray-600 dark:text-gray-400 group-hover/item:text-gray-900 group-data-focus/item:text-gray-900 dark:group-hover/item:text-gray-100 dark:group-data-focus/item:text-gray-100"

  # Themes/sizes/base are defined as component classes in
  # assets/css/app.css, shared with the Phoenix `button` component
  # (lib/plausible_web/components/generic.ex). Update there only.
  @trigger_base_class "btn-base focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"

  @trigger_icon_class "btn-icon"

  @trigger_themes %{
    "primary" => "btn-theme-primary",
    "secondary" => "btn-theme-secondary",
    "ghost" => "btn-theme-ghost",
    "link" => "btn-theme-link"
  }

  @trigger_sizes %{
    "xs" => "btn-xs",
    "sm" => "btn-sm",
    "md" => "btn-md"
  }

  defdelegate dropdown(assigns), to: Prima.Dropdown

  attr(:id, :string, required: true)
  attr(:theme, :string, default: "secondary")
  attr(:size, :string, default: "md")
  attr(:icon?, :boolean, default: false)
  attr(:class, :string, default: "")
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def dropdown_trigger(assigns) do
    assigns =
      assign(assigns,
        computed_class: [
          @trigger_base_class,
          @trigger_sizes[assigns.size],
          @trigger_themes[assigns.theme],
          if(assigns.icon?, do: @trigger_icon_class, else: "justify-between"),
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
      match_trigger_width={true}
      class="bg-white rounded-md shadow-lg ring-1 ring-black/5 focus:outline-none p-1.5 dark:bg-gray-800 relative z-10"
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
