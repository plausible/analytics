defmodule Plausible.Stats.GoogleSearchConsole do
  @redirect_uri URI.encode_www_form("http://localhost:8000/auth/google/callback")
  @client_id "1067516560281-9ugr4iijgr3uge3j6qir5n131me0o42o.apps.googleusercontent.com"

  def authorize_url(site_id) do
    "https://accounts.google.com/o/oauth2/v2/auth?client_id=#{@client_id}&redirect_uri=#{@redirect_uri}&response_type=code&approval_prompt=force&access_type=offline&scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fwebmasters.readonly&state=#{site_id}"
  end

  def fetch_access_token(code) do
    res = HTTPoison.post!("https://www.googleapis.com/oauth2/v4/token", "client_id=#{@client_id}&client_secret=aeeswPFIzagXeN4Q7a3IQ8aB&code=#{code}&grant_type=authorization_code&redirect_uri=#{@redirect_uri}", ["Content-Type": "application/x-www-form-urlencoded"])
    Jason.decode!(res.body)
  end

  def fetch_stats(_site, nil, _query) do
    nil
  end

  def fetch_stats(site, auth, query) do
    {:ok, overall_performance} = fetch_totals(site.domain, auth, query)
    {:ok, keywords} = fetch_queries(site.domain, auth, query)

    Map.merge(
      overall_performance,
      %{search_terms: keywords}
    )
  end

  defp fetch_queries(domain, auth, query) do
    with_https = URI.encode_www_form("https://#{domain}")
    res = HTTPoison.post!("https://www.googleapis.com/webmasters/v3/sites/#{with_https}/searchAnalytics/query", Jason.encode!(%{
      startDate: Date.to_iso8601(query.date_range.first),
      endDate: Date.to_iso8601(query.date_range.last),
      dimensions: ["query"],
      rowLimit: 20
    }), ["Content-Type": "application/json", "Authorization": "Bearer #{auth.access_token}"])
    case res.status_code do
      200 ->
        {:ok, Jason.decode!(res.body)["rows"]}
      401 ->
        {:error, :invalid_credentials}
      _ ->
        {:error, :unknown}
    end
  end

  defp fetch_totals(domain, auth, query) do
    with_https = URI.encode_www_form("https://#{domain}")
    res = HTTPoison.post!("https://www.googleapis.com/webmasters/v3/sites/#{with_https}/searchAnalytics/query", Jason.encode!(%{
      startDate: Date.to_iso8601(query.date_range.first),
      endDate: Date.to_iso8601(query.date_range.last),
    }), ["Content-Type": "application/json", "Authorization": "Bearer #{auth.access_token}"])
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
