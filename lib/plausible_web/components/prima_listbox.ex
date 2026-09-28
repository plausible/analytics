defmodule PlausibleWeb.Components.PrimaListbox do
  @moduledoc false
  alias Prima.Listbox
  use Phoenix.Component

  # Themes/sizes/base are defined as component classes in
  # assets/css/app.css, shared with the Phoenix `button` component
  # (lib/plausible_web/components/generic.ex). Update there only.
  @trigger_base_class "btn-base justify-between focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"

  @trigger_themes %{
    "secondary" => "btn-theme-secondary",
    "ghost" => "btn-theme-ghost",
    "link" => "btn-theme-link"
  }

  @trigger_sizes %{
    "xs" => "btn-xs",
    "sm" => "btn-sm",
    "md" => "btn-md"
  }

  @options_base_class "relative z-50 p-1.5 w-max rounded-md shadow-lg overflow-hidden bg-white dark:bg-gray-800 ring-1 ring-black/5 focus:outline-none"
  @option_class "group block rounded-md text-sm/6 text-gray-900 dark:text-gray-100 px-3 py-1.5 cursor-pointer data-focus:bg-gray-100 dark:data-focus:bg-gray-700/80 data-disabled:pointer-events-none data-disabled:cursor-not-allowed data-disabled:text-gray-300 dark:data-disabled:text-gray-600"

  defdelegate listbox_value(assigns), to: Listbox

  attr(:id, :string, required: true)
  attr(:name, :string, required: true)
  attr(:value, :any, default: nil)
  attr(:disabled, :boolean, default: false)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def listbox(assigns) do
    ~H"""
    <Listbox.listbox
      id={@id}
      name={@name}
      value={@value}
      class={@disabled && "cursor-not-allowed"}
      {@rest}
    >
      {render_slot(@inner_block)}
    </Listbox.listbox>
    """
  end

  attr(:id, :string, required: true)
  attr(:theme, :string, default: "secondary")
  attr(:size, :string, default: "md")
  attr(:class, :string, default: "")
  attr(:disabled, :boolean, default: false)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def listbox_trigger(assigns) do
    assigns =
      assign(assigns,
        computed_class: [
          @trigger_base_class,
          @trigger_sizes[assigns.size],
          @trigger_themes[assigns.theme],
          assigns.class,
          assigns.disabled && "pointer-events-none !text-gray-300 dark:!text-gray-600"
        ]
      )

    ~H"""
    <Listbox.listbox_trigger
      id={@id}
      class={@computed_class}
      aria-disabled={@disabled && "true"}
      tabindex={@disabled && "-1"}
      {@rest}
    >
      {render_slot(@inner_block)}
    </Listbox.listbox_trigger>
    """
  end

  attr(:id, :string, required: true)
  attr(:class, :string, default: "")
  slot(:inner_block, required: true)

  def listbox_options(assigns) do
    assigns = assign(assigns, computed_class: [@options_base_class, assigns.class])

    ~H"""
    <Listbox.listbox_options
      id={@id}
      placement="bottom-end"
      offset={8}
      match_trigger_width={false}
      transition_enter={
        {"transition ease-out duration-100", "opacity-0 scale-95", "opacity-100 scale-100"}
      }
      transition_leave={
        {"transition ease-in duration-75", "opacity-100 scale-100", "opacity-0 scale-95"}
      }
      class={@computed_class}
    >
      {render_slot(@inner_block)}
    </Listbox.listbox_options>
    """
  end

  attr(:id, :string, required: true)
  attr(:value, :any, required: true)
  attr(:display, :string, default: nil)
  attr(:disabled, :boolean, default: false)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def listbox_option(assigns) do
    assigns = assign(assigns, :option_class, @option_class)

    ~H"""
    <Listbox.listbox_option
      id={@id}
      value={@value}
      display={@display}
      disabled={@disabled}
      class={@option_class}
      {@rest}
    >
      {render_slot(@inner_block)}
    </Listbox.listbox_option>
    """
  end

  attr(:class, :string, default: "")
  attr(:disabled, :boolean, default: false)
  slot(:inner_block, required: true)

  def option_description(assigns) do
    ~H"""
    <div class={[
      "text-xs/5",
      if(@disabled,
        do: "text-gray-300 dark:text-gray-600",
        else: "text-gray-500 dark:text-gray-400"
      ),
      @class
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
