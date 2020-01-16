defmodule Mix.Tasks.FetchTweetsTest do
  use Plausible.DataCase
  alias Mix.Tasks.FetchTweets

  describe "processing tweet entities" do
    test "inlines links to the body" do
      tweet = %{
        "full_text" => "asd https://t.co/somelink",
        "entities" => %{
          "user_mentions" => [],
          "urls" => [%{
            "display_url" => "plausible.io",
            "indices" => [4, 17],
            "url" => "https://t.co/somelink"
          }]
        }
      }
      body = FetchTweets.html_body(tweet)

      assert body == "asd <a href=\"https://t.co/somelink\" target=\"_blank\">plausible.io</a>"
    end

    test "inlines user mentions to the body" do
      tweet = %{
        "full_text" => "asd @hello",
        "entities" => %{
          "user_mentions" => [%{
            "screen_name" => "hello",
            "id_str" => "123123"
          }],
          "urls" => []
        }
      }
      body = FetchTweets.html_body(tweet)

      assert body == "asd <a href=\"https://twitter.com/hello\" target=\"_blank\">@hello</a>"
    end
  end

end
