defmodule PlausibleWeb.StatsView do
  use PlausibleWeb, :view

  def bar(count, all, color \\ :blue) do
    ~E"""
    <div class="bar">
      <div class="bar__fill bg-<%= color %>" style="width: <%= bar_width(count, all) %>%;"></div>
    </div>
    """
  end

  defp bar_width(count, all) do
    count / (List.first(all) |> elem(1)) * 100
  end

  defp custom_range_text("custom", dates) do
    {:ok, first} = Timex.format(dates.first, "{Mshort} {D}")
    {:ok, last} = Timex.format(dates.last, "{Mshort} {D}")
    "#{first} - #{last}"
  end

  defp custom_range_text(_, _) do
    "Custom range"
  end
end
