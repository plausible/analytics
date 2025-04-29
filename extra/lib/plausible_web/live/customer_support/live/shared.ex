defmodule PlausibleWeb.CustomerSupport.Live.Shared do
  use Phoenix.Component

  attr :to, :string, required: true
  attr :tab, :string, required: true
  attr :target, :any, required: true
  slot :inner_block, required: true

  def tab(assigns) do
    ~H"""
    <a
      phx-click="switch"
      phx-value-to={@to}
      phx-target={@target}
      class="group relative min-w-0 flex-1 overflow-hidden rounded-l-lg bg-white px-4 py-4 text-center text-sm font-medium text-gray-500 hover:bg-gray-50 hover:text-gray-700 focus:z-10 cursor-pointer"
    >
      <span class={if(@tab == @to, do: "font-bold text-gray-800")}>
        {render_slot(@inner_block)}
      </span>
      <span
        aria-hidden="true"
        class={[
          "absolute inset-x-0 bottom-0 h-0.5",
          if(@tab == @to, do: "bg-indigo-500", else: "bg-transparent")
        ]}
      >
      </span>
    </a>
    """
  end
end
