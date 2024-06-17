defmodule PlausibleWeb.StatsView do
  use PlausibleWeb, :view
  use Plausible

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

      is_integer(n) ->
        Integer.to_string(n)
    end
  end

  def stats_container_class(conn) do
    cond do
      conn.assigns[:embedded] && conn.params["width"] == "manual" -> "px-6"
      conn.assigns[:embedded] -> "max-w-screen-xl mx-auto px-6"
      !conn.assigns[:embedded] -> "container print:max-w-full"
    end
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
