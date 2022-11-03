defmodule PlausibleWeb.StatsView do
  use PlausibleWeb, :view

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

  def stats_container_class(conn) do
    cond do
      conn.assigns[:embedded] && conn.assigns[:width] == "manual" -> ""
      conn.assigns[:embedded] -> "max-width-screen-lg mx-auto"
      !conn.assigns[:embedded] -> "container"
    end
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

  @doc """
  Returns a readable stats URL.

  Native Phoenix router functions percent-encode all diacritics, resulting in
  ugly URLs, e.g. `https://plausible.io/café.com` transforms into
  `https://plausible.io/caf%C3%A9.com`.

  This function encodes only the slash (`/`) character from the site's domain.

  ## Examples

     iex> PlausibleWeb.StatsView.pretty_stats_url(%Plausible.Site{domain: "user.gittea.io/repo"})
     "http://localhost:8000/user.gittea.io%2Frepo"

     iex> PlausibleWeb.StatsView.pretty_stats_url(%Plausible.Site{domain: "anakin.test"})
     "http://localhost:8000/anakin.test"

     iex> PlausibleWeb.StatsView.pretty_stats_url(%Plausible.Site{domain: "café.test"})
     "http://localhost:8000/café.test"

  """
  def pretty_stats_url(%Plausible.Site{domain: domain}) when is_binary(domain) do
    pretty_domain = String.replace(domain, "/", "%2F")
    "#{plausible_url()}/#{pretty_domain}"
  end
end
