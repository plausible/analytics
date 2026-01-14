defmodule PlausibleWeb.Components.Dashboard.Base do
  @moduledoc """
  Common components for dasbhaord.
  """

  use PlausibleWeb, :component

  attr :to, :string, required: true
  attr :class, :string, default: ""
  attr :rest, :global

  slot :inner_block, required: true

  def dashboard_link(assigns) do
    ~H"""
    <.link
      data-type="dashboard-link"
      patch={@to}
      class={@class}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :style, :string, default: ""
  attr :background_class, :string, default: ""
  attr :width, :integer, required: true
  attr :max_width, :integer, required: true

  slot :inner_block, required: true

  def bar(assigns) do
    width_percent = assigns.width / assigns.max_width * 100

    assigns = assign(assigns, :width_percent, width_percent)

    ~H"""
    <div class="w-full h-full relative" style={@style}>
      <div
        class={"absolute top-0 left-0 h-full rounded-sm transition-colors duration-150 #{@background_class || ""}"}
        data-test-id="bar-indicator"
        style={"width: #{@width_percent}%"}
      >
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
