defmodule PlausibleWeb.StatsView do
  use PlausibleWeb, :view

  def admin_email do
    Application.get_env(:plausible, :admin_email)
  end

  def base_domain do
    PlausibleWeb.Endpoint.host()
  end

  def plausible_url do
    PlausibleWeb.Endpoint.url()
  end

  def large_number_format(n) do
    cond do
      n >= 1_000 && n < 1_000_000 ->
        thousands = trunc(n / 100) / 10

        if thousands == trunc(thousands) || n >= 100_000 do
          "#{trunc(thousands)}k"
        else
          "#{thousands}k"
        end

      n >= 1_000_000 && n < 1_000_000_000 ->
        millions = trunc(n / 100_000) / 10

        if millions == trunc(millions) || n > 100_000_000 do
          "#{trunc(millions)}M"
        else
          "#{millions}M"
        end

      n >= 1_000_000_000 && n < 1_000_000_000_000 ->
        billions = trunc(n / 100_000_000) / 10

        if billions == trunc(billions) || n > 100_000_000_000 do
          "#{trunc(billions)}B"
        else
          "#{billions}B"
        end

      true ->
        Integer.to_string(n)
    end
  end

  def bar(count, all, color \\ :blue) do
    ~E"""
    <div class="bg-<%= color %>-100" style="width: <%= bar_width(count, all) %>%; height: 30px"></div>
    """
  end

  defp bar_width(count, all) do
    max =
      Enum.max_by(all, fn
        {_, count} -> count
        {_, count, _} -> count
      end)
      |> elem(1)

    count / max * 100
  end
end
