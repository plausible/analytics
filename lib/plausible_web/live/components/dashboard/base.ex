defmodule PlausibleWeb.Components.Dashboard.Base do
  @moduledoc """
  Common components for dasbhaord.
  """

  use PlausibleWeb, :component

  alias Plausible.Stats.DashboardQuerySerializer

  attr :site, Plausible.Site, required: true
  attr :params, :map, required: true
  attr :path, :string, default: ""
  attr :class, :string, default: ""
  attr :rest, :global

  slot :inner_block, required: true

  def dashboard_link(assigns) do
    query_string = DashboardQuerySerializer.serialize(assigns.params)
    url = "/" <> assigns.site.domain <> assigns.path

    url =
      if query_string != "" do
        url <> "?" <> query_string
      else
        url
      end

    assigns = assign(assigns, :url, url)

    ~H"""
    <.link
      data-type="dashboard-link"
      patch={@url}
      class={@class}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :site, Plausible.Site, required: true
  attr :params, :map, required: true
  attr :filter, :list, required: true
  attr :class, :string, default: ""
  attr :rest, :global

  slot :inner_block, required: true

  def filter_link(assigns) do
    params_string = replace_filter(assigns.params, assigns.filter)

    assigns = assign(assigns, :params_string, params_string)

    ~H"""
    <.dashboard_link site={@site} params={@params} class={@class} {@rest}>
      {render_slot(@inner_block)}
    </.dashboard_link>
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
        style={"width: #{@width_percent}%"}
      >
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp replace_filter(params, filter) do
    [:is, dimension, _values] = filter

    filters =
      Enum.reject(params.filters, fn
        {:is, ^dimension, _} -> true
        _ -> false
      end)

    %{params | filters: [filter | filters]}
  end
end
