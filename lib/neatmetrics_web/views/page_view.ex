defmodule NeatmetricsWeb.PageView do
  use NeatmetricsWeb, :view

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
end
