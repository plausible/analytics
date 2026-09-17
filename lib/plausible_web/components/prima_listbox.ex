defmodule PlausibleWeb.Components.PrimaListbox do
  @moduledoc false
  alias Prima.Listbox
  use Phoenix.Component

  @trigger_base_class "inline-flex items-center justify-between font-medium rounded-md px-3 py-2.5 text-sm border border-gray-300 dark:border-gray-750 text-gray-800 dark:text-gray-100 dark:bg-gray-750 dark:hover:bg-gray-700 focus-visible:outline-gray-100 whitespace-nowrap truncate shadow-xs hover:shadow-sm transition-all duration-150 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:bg-gray-400 dark:disabled:text-white dark:disabled:text-gray-400 dark:disabled:bg-gray-700"
  @options_base_class "relative z-50 p-1.5 w-max rounded-md shadow-lg overflow-hidden bg-white dark:bg-gray-800 ring-1 ring-black/5 focus:outline-none"
  @option_class "block rounded-md text-sm/6 text-gray-900 dark:text-gray-100 px-3 py-1.5 cursor-pointer data-focus:bg-gray-100 dark:data-focus:bg-gray-700/80 data-disabled:pointer-events-none data-disabled:cursor-not-allowed"

  defdelegate listbox(assigns), to: Listbox
  defdelegate listbox_value(assigns), to: Listbox

  attr(:id, :string, required: true)
  attr(:class, :string, default: "")
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def listbox_trigger(assigns) do
    assigns = assign(assigns, computed_class: [@trigger_base_class, assigns.class])

    ~H"""
    <Listbox.listbox_trigger id={@id} class={@computed_class} {@rest}>
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
end
