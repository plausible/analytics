defmodule PlausibleWeb.Live.Components.Visitors do
  @moduledoc """
  Component rendering mini-graph of site's visitors over the last 24 hours.

  The `gradient_defs` component should be rendered once before using `chart`
  one or more times.

  Accepts input generated via `Plausible.Stats.Clickhouse.last_24h_visitors_hourly_intervals/2`.
  """

  use Phoenix.Component

  attr :intervals, :list, required: true
  attr :height, :integer, default: 50
  attr :tick, :integer, default: 20

  def chart(assigns) do
    points =
      assigns.intervals
      |> scale(assigns.height)
      |> Enum.with_index(fn scaled_value, index ->
        "#{index * assigns.tick},#{scaled_value}"
      end)

    clip_points =
      List.flatten([
        "0,#{assigns.height + 1}",
        points,
        "#{(length(points) - 1) * assigns.tick},#{assigns.height + 1}",
        "0,#{assigns.height + 1}"
      ])

    assigns =
      assigns
      |> assign(:points_len, length(points))
      |> assign(:points, Enum.join(points, " "))
      |> assign(:clip_points, Enum.join(clip_points, " "))
      |> assign(:id, Ecto.UUID.generate())

    ~H"""
    <svg viewBox={"0 -1 #{(@points_len - 1) * @tick} #{@height + 3}"} class="chart w-full mb-2">
      <defs>
        <clipPath id={"gradient-cut-off-#{@id}"}>
          <polyline points={@clip_points} />
        </clipPath>
      </defs>
      <rect
        x="0"
        y="1"
        width={@points_len * @tick}
        height={@height}
        fill="url(#chart-gradient-cut-off)"
        clip-path={"url(#gradient-cut-off-#{@id})"}
      />
      <polyline fill="none" stroke="rgba(101,116,205)" stroke-width="2.6" points={@points} />
    </svg>
    """
  end

  def gradient_defs(assigns) do
    ~H"""
    <svg width="0" height="0">
      <defs class="text-white dark:text-indigo-800">
        <linearGradient id="chart-gradient-cut-off" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%" stop-color="rgba(101,116,205,0.2)" />
          <stop offset="100%" stop-color="rgba(101,116,205,0)" />
        </linearGradient>
      </defs>
    </svg>
    """
  end

  defp scale(data, target_range) do
    max_value = Enum.max_by(data, fn %{visitors: visitors} -> visitors end)

    scaling_factor = if max_value.visitors > 0, do: target_range / max_value.visitors, else: 0

    Enum.map(data, fn %{visitors: visitors} ->
      round(target_range - visitors * scaling_factor)
    end)
  end
end
