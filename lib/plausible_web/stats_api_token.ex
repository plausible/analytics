defmodule PlausibleWeb.StatsApiToken do
  @one_day 86400

  def sign(site) do
    Phoenix.Token.sign(PlausibleWeb.Endpoint, "stats_api_token", %{
      domain: site.domain,
      timezone: site.timezone
    })
  end

  def verify(token) do
    Phoenix.Token.verify(PlausibleWeb.Endpoint, "stats_api_token", token, max_age: @one_day)
  end
end
