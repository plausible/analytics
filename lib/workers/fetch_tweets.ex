defmodule Plausible.Workers.FetchTweets do
  use Plausible.Repo
  alias Plausible.Twitter.Tweet
  use Oban.Worker, queue: :fetch_tweets

  @impl Oban.Worker
  def perform(_job, twitter_api \\ Plausible.Twitter.Api) do
    new_links =
      Plausible.ClickhouseRepo.all(
        from e in Plausible.ClickhouseEvent,
          where:
            e.timestamp > fragment("(now() - INTERVAL 6 day)") and
              e.timestamp < fragment("(now() - INTERVAL 5 day)"),
          or_where: e.timestamp > fragment("(now() - INTERVAL 1 day)"),
          where: e.referrer_source == "Twitter",
          where: e.referrer not in ["t.co", "t.co/"],
          distinct: true,
          select: e.referrer
      )

    for link <- new_links do
      results = twitter_api.search(link)

      for tweet <- results do
        {:ok, created} =
          Timex.parse(tweet["created_at"], "{WDshort} {Mshort} {D} {ISOtime} {Z} {YYYY}")

        Tweet.changeset(%Tweet{}, %{
          link: link,
          tweet_id: tweet["id_str"],
          author_handle: tweet["user"]["screen_name"],
          author_name: tweet["user"]["name"],
          author_image: tweet["user"]["profile_image_url_https"],
          text: html_body(tweet),
          created: created
        })
        |> Repo.insert!(on_conflict: :nothing)
      end
    end

    :ok
  end

  def html_body(tweet) do
    body =
      Enum.reduce(tweet["entities"]["urls"], tweet["full_text"], fn url, text ->
        html = "<a href=\"#{url["url"]}\" target=\"_blank\">#{url["display_url"]}</a>"
        String.replace(text, url["url"], html)
      end)

    Enum.reduce(tweet["entities"]["user_mentions"], body, fn mention, text ->
      link = "https://twitter.com/#{mention["screen_name"]}"
      html = "<a href=\"#{link}\" target=\"_blank\">@#{mention["screen_name"]}</a>"
      String.replace(text, "@" <> mention["screen_name"], html)
    end)
  end
end
