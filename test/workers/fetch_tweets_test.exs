defmodule Plausible.Workers.FetchTweetsTest do
  use Plausible.DataCase
  alias Plausible.Workers.FetchTweets
  import Double

  test "fetches Twitter referrals from the last day" do
    twitter_mock = stub(Plausible.Twitter.Api, :search, fn _link -> [] end)
    FetchTweets.perform(nil, twitter_mock)

    assert_receive({Plausible.Twitter.Api, :search, ["t.co/a-link"]})
  end

  test "fetches Twitter referrals from 5-6 days ago" do
    twitter_mock = stub(Plausible.Twitter.Api, :search, fn _link -> [] end)
    FetchTweets.perform(nil, twitter_mock)

    assert_receive({Plausible.Twitter.Api, :search, ["t.co/b-link"]})
  end

  test "stores twitter results" do
    tweet = %{
      "full_text" => "a Tweet body",
      "id_str" => "the_tweet_id",
      "created_at" => "Mon May 06 20:01:29 +0000 2019",
      "user" => %{
        "screen_name" => "twitter_author",
        "name" => "Twitter Author",
        "profile_image_url_https" => "https://image.com"
      },
      "entities" => %{
        "user_mentions" => [],
        "urls" => []
      }
    }

    twitter_mock =
      stub(Plausible.Twitter.Api, :search, fn
        "t.co/a-link" -> [tweet]
        _link -> []
      end)

    FetchTweets.perform(nil, twitter_mock)

    [found_tweet] = Repo.all(from(t in Plausible.Twitter.Tweet))
    assert found_tweet.tweet_id == "the_tweet_id"
    assert found_tweet.text == "a Tweet body"
    assert found_tweet.author_handle == "twitter_author"
    assert found_tweet.author_name == "Twitter Author"
    assert found_tweet.author_image == "https://image.com"
    assert found_tweet.created == ~N[2019-05-06 20:01:29]
  end

  describe "processing tweet entities" do
    test "inlines links to the body" do
      tweet = %{
        "full_text" => "asd https://t.co/somelink",
        "entities" => %{
          "user_mentions" => [],
          "urls" => [
            %{
              "display_url" => "plausible.io",
              "indices" => [4, 17],
              "url" => "https://t.co/somelink"
            }
          ]
        }
      }

      body = FetchTweets.html_body(tweet)

      assert body == "asd <a href=\"https://t.co/somelink\" target=\"_blank\">plausible.io</a>"
    end

    test "inlines user mentions to the body" do
      tweet = %{
        "full_text" => "asd @hello",
        "entities" => %{
          "user_mentions" => [
            %{
              "screen_name" => "hello",
              "id_str" => "123123"
            }
          ],
          "urls" => []
        }
      }

      body = FetchTweets.html_body(tweet)

      assert body == "asd <a href=\"https://twitter.com/hello\" target=\"_blank\">@hello</a>"
    end
  end
end
