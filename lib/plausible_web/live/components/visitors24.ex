defmodule PlausibleWeb.Live.Components.Visitors do
  use Phoenix.Component

  # Proof of concept, TODOs:
  # - make it asynchronous,
  # - move under Live.Components or .Components depending on how it turns out,
  # - make it render once per site - currently both mounts call it

  attr :site, Plausible.Site, required: true
  attr :height, :integer, default: 50

  def chart(assigns) do
    site = assigns.site
    q = Plausible.Stats.Query.from(site, %{"period" => "day", "interval" => "hour"})

    points =
      site
      |> Plausible.Stats.timeseries(q, [:visitors])
      |> scale(assigns.height)
      |> Enum.with_index(fn scaled_value, index -> "#{(index - 1) * 20},#{scaled_value}" end)
      |> Enum.join(" ")

    assigns = assign(assigns, :points, points)

    ~H"""
    <svg viewBox={"0 0 #{24 * 20} #{@height + 1}"} class="chart w-full mb-2">
      <polyline fill="none" stroke="#6366f1" stroke-width="3" points={@points} />
    </svg>
    """
  end

  defp scale(data, target_range) do
    max_value = Enum.max_by(data, fn %{visitors: visitors} -> visitors end)

    scaling_factor =
      if max_value.visitors > 0, do: div(target_range, max_value.visitors), else: 0

    Enum.map(data, fn %{visitors: visitors} ->
      target_range - visitors * scaling_factor
    end)
  end
end
