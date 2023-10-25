defmodule PlausibleWeb.Live.Components.Visitors do
  @moduledoc """
  Component rendering mini-graph of site's visitors over the last 24 hours.
  """

  use Phoenix.Component

  # Proof of concept, TODOs:
  # - make it asynchronous,
  # - move under Live.Components or .Components depending on how it turns out,
  # - make it render once per site - currently both mounts call it

  attr :intervals, :list, required: true
  attr :height, :integer, default: 50
  attr :tick, :integer, default: 20

  def chart(assigns) do
    points =
      assigns.intervals
      |> scale(assigns.height)
      |> Enum.with_index(fn scaled_value, index ->
        "#{(index - 1) * assigns.tick},#{scaled_value}"
      end)

    clip_points =
      List.flatten([
        "-#{assigns.tick},#{assigns.height + 1}",
        points,
        "#{(length(points) - 2) * assigns.tick},#{assigns.height + 1}",
        "-#{assigns.tick},#{assigns.height + 1}"
      ])

    assigns =
      assigns
      |> assign(:points, Enum.join(points, " "))
      |> assign(:clip_points, Enum.join(clip_points, " "))
      |> assign(:id, Ecto.UUID.generate())

    ~H"""
    <svg viewBox={"0 0 #{24 * 20} #{@height + 1}"} class="chart w-full mb-2">
      <defs>
        <clipPath id={"gradient-cut-off-#{@id}"}>
          <polyline points={@clip_points} />
        </clipPath>
      </defs>
      <rect
        x="-20"
        y="0"
        width={24 * 20}
        height={@height + 1}
        fill="url(#chart-gradient-cut-off)"
        clip-path={"url(#gradient-cut-off-#{@id})"}
      />
      <polyline fill="none" stroke="#6366f1" stroke-width="3" points={@points} />
    </svg>
    """
  end

  def gradient_defs(assigns) do
    ~H"""
    <svg class="inline-block">
      <defs>
        <linearGradient id="chart-gradient-cut-off" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%" stop-color="#C5CAE9" />
          <stop offset="100%" stop-color="white" />
        </linearGradient>
      </defs>
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
