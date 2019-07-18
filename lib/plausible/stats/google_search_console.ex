defmodule Plausible.Stats.GoogleSearchConsole do
  @access_token "ya29.GlxIB0yxe2BvXWvEli4HvxXn2MYqtgDvRFww-4c9yt13PhINv8SJnAdzmPArRvjUrfuwQrWbFDcJd2nE2K8_PccWKfQVj9e2e84d2PPiGLF7d20SxTk13Xk_cocMPw"

  def fetch_queries(domain, query) do
    with_https = URI.encode_www_form("https://#{domain}")
    res = HTTPoison.post!("https://www.googleapis.com/webmasters/v3/sites/#{with_https}/searchAnalytics/query", Jason.encode!(%{
      startDate: Date.to_iso8601(query.date_range.first),
      endDate: Date.to_iso8601(query.date_range.last),
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

  def fetch_totals(domain, query) do
    with_https = URI.encode_www_form("https://#{domain}")
    res = HTTPoison.post!("https://www.googleapis.com/webmasters/v3/sites/#{with_https}/searchAnalytics/query", Jason.encode!(%{
      startDate: Date.to_iso8601(query.date_range.first),
      endDate: Date.to_iso8601(query.date_range.last),
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
