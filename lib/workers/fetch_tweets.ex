defmodule Plausible.Workers.FetchTweets do
  use Plausible.Repo
  use Oban.Worker, queue: :fetch_tweets
  alias Plausible.Twitter.Tweet
	@oauth_credentials Application.get_env(:plausible, :twitter, %{}) |> OAuther.credentials()

  @impl Oban.Worker
  def perform(_args, _job) do
    new_links = Repo.all(
      from e in Plausible.Event,
      where: e.timestamp > fragment("(now() - '6 days'::interval)") and e.timestamp < fragment("(now() - '5 days'::interval)"),
      or_where: e.timestamp > fragment("(now() - '1 days'::interval)"),
      where: e.referrer_source == "Twitter",
      where: e.referrer not in ["t.co", "t.co/"],
      distinct: true,
      select: e.referrer
    )

    for link <- new_links do
      results = search(link)

      for tweet <- results do
        {:ok, created} = Timex.parse(tweet["created_at"], "{WDshort} {Mshort} {D} {ISOtime} {Z} {YYYY}")

        Tweet.changeset(%Tweet{}, %{
          link: link,
          tweet_id: tweet["id_str"],
          author_handle: tweet["user"]["screen_name"],
          author_name: tweet["user"]["name"],
          author_image: tweet["user"]["profile_image_url_https"],
          text: html_body(tweet),
          created: created
        }) |> Repo.insert!(on_conflict: :nothing)
      end
    end
    :ok
  end

  def html_body(tweet) do
    body = Enum.reduce(tweet["entities"]["urls"], tweet["full_text"], fn url, text ->
      html = "<a href=\"#{url["url"]}\" target=\"_blank\">#{url["display_url"]}</a>"
      String.replace(text, url["url"], html)
    end)

    Enum.reduce(tweet["entities"]["user_mentions"], body, fn mention, text ->
      link = "https://twitter.com/#{mention["screen_name"]}"
      html = "<a href=\"#{link}\" target=\"_blank\">@#{mention["screen_name"]}</a>"
      String.replace(text, "@" <> mention["screen_name"], html)
    end)
  end

  defp search(link) do
    params = [{"count", 5}, {"tweet_mode", "extended"}, {"q", "https://#{link} -filter:retweets"}]
    params = OAuther.sign("get", "https://api.twitter.com/1.1/search/tweets.json", params, @oauth_credentials)
		uri = "https://api.twitter.com/1.1/search/tweets.json?" <> URI.encode_query(params)
    response = HTTPoison.get!(uri)
    Jason.decode!(response.body)
    |> Map.get("statuses")
  end
end
