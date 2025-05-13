defmodule PlausibleWeb.CustomerSupport.Live.Shared do
  @moduledoc false
  use Phoenix.Component

  attr :to, :string, required: true
  attr :tab, :string, required: true
  slot :inner_block, required: true

  def tab(assigns) do
    title = """
      hello
    """

    ~H"""
    <.link
      patch={"?tab=#{@to}"}
      class="group relative min-w-0 flex-1 overflow-hidden rounded-l-lg px-4 py-4 text-center text-sm font-medium focus:z-10 cursor-pointer text-gray-800 dark:text-gray-200"
    >
      <span class={if(@tab == @to, do: "font-bold")}>
        {render_slot(@inner_block)}
      </span>
      <span
        aria-hidden="true"
        class={[
          "absolute inset-x-0 bottom-0 h-0.5",
          if(@tab == @to, do: "dark:bg-indigo-300 bg-indigo-500", else: "bg-transparent")
        ]}
      >
      </span>
    </.link>
    """
  end
end
