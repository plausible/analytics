defmodule Plausible.Twitter.Api do
  def search(link) do
    params = [{"count", 5}, {"tweet_mode", "extended"}, {"q", "https://#{link} -filter:retweets"}]
    params = OAuther.sign("get", "https://api.twitter.com/1.1/search/tweets.json", params, oauth_credentials())
		uri = "https://api.twitter.com/1.1/search/tweets.json?" <> URI.encode_query(params)
    response = HTTPoison.get!(uri)
    Jason.decode!(response.body)
    |> Map.get("statuses")
  end

  defp oauth_credentials() do
    Application.get_env(:plausible, :twitter, %{})
    |> OAuther.credentials()
  end
end
