defmodule Plausible.Stats.GoogleSearchConsole do
  @access_token "ya29.GlxHB8u0F7DrvyEXqAhqX9NHkxBoDxLa0vdoUUiOlw3Zd2n-SeB3WZCTatgBAF0ZOjyFLOncoCx4uxMRPBTzWnYAjaPfjZLF13cRbatyNeEifUEzcCrCqnL9Gx0fWw"

  def fetch_queries(domain) do
    with_https = URI.encode_www_form("https://#{domain}")
    res = HTTPoison.post!("https://www.googleapis.com/webmasters/v3/sites/#{with_https}/searchAnalytics/query", Jason.encode!(%{
      startDate: "2019-06-16",
      endDate: "2019-07-16",
      dimensions: ["query"],
      rowLimit: 20
    }), ["Content-Type": "application/json", "Authorization": "Bearer #{@access_token}"])
    case res.status_code do
      200 ->
        {:ok, Jason.decode!(res.body)["rows"]}
      401 ->
        {:error, :invalid_credentials}
      _ ->
        {:error, :unknown}
    end
  end

  def fetch_totals(domain) do
    with_https = URI.encode_www_form("https://#{domain}")
    res = HTTPoison.post!("https://www.googleapis.com/webmasters/v3/sites/#{with_https}/searchAnalytics/query", Jason.encode!(%{
      startDate: "2019-06-16",
      endDate: "2019-07-16"
    }), ["Content-Type": "application/json", "Authorization": "Bearer #{@access_token}"])
    case res.status_code do
      200 ->
        [result] = Jason.decode!(res.body)["rows"]
        {:ok, result}
      401 ->
        {:error, :invalid_credentials}
      _ ->
        {:error, :unknown}
    end
  end
end
