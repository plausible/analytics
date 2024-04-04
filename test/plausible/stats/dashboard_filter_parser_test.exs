defmodule Plausible.Stats.DashboardFilterParserTest do
  use ExUnit.Case, async: true
  alias Plausible.Stats.Filters.DashboardFilterParser

  def assert_parsed(filters, expected_output) do
    assert DashboardFilterParser.parse_and_prefix(filters) == expected_output
  end

  describe "adding prefix" do
    test "adds appropriate prefix to filter" do
      %{"page" => "/"}
      |> assert_parsed(%{"event:page" => {:is, "/"}})

      %{"goal" => "Signup"}
      |> assert_parsed(%{"event:goal" => {:is, {:event, "Signup"}}})

      %{"goal" => "Visit /blog"}
      |> assert_parsed(%{"event:goal" => {:is, {:page, "/blog"}}})

      %{"source" => "Google"}
      |> assert_parsed(%{"visit:source" => {:is, "Google"}})

      %{"referrer" => "cnn.com"}
      |> assert_parsed(%{"visit:referrer" => {:is, "cnn.com"}})

      %{"utm_medium" => "search"}
      |> assert_parsed(%{"visit:utm_medium" => {:is, "search"}})

      %{"utm_source" => "bing"}
      |> assert_parsed(%{"visit:utm_source" => {:is, "bing"}})

      %{"utm_content" => "content"}
      |> assert_parsed(%{"visit:utm_content" => {:is, "content"}})

      %{"utm_term" => "term"}
      |> assert_parsed(%{"visit:utm_term" => {:is, "term"}})

      %{"screen" => "Desktop"}
      |> assert_parsed(%{"visit:screen" => {:is, "Desktop"}})

      %{"browser" => "Opera"}
      |> assert_parsed(%{"visit:browser" => {:is, "Opera"}})

      %{"browser_version" => "10.1"}
      |> assert_parsed(%{"visit:browser_version" => {:is, "10.1"}})

      %{"os" => "Linux"}
      |> assert_parsed(%{"visit:os" => {:is, "Linux"}})

      %{"os_version" => "13.0"}
      |> assert_parsed(%{"visit:os_version" => {:is, "13.0"}})

      %{"country" => "EE"}
      |> assert_parsed(%{"visit:country" => {:is, "EE"}})

      %{"region" => "EE-12"}
      |> assert_parsed(%{"visit:region" => {:is, "EE-12"}})

      %{"city" => "123"}
      |> assert_parsed(%{"visit:city" => {:is, "123"}})

      %{"entry_page" => "/blog"}
      |> assert_parsed(%{"visit:entry_page" => {:is, "/blog"}})

      %{"exit_page" => "/blog"}
      |> assert_parsed(%{"visit:exit_page" => {:is, "/blog"}})

      %{"props" => %{"cta" => "Top"}}
      |> assert_parsed(%{"event:props:cta" => {:is, "Top"}})

      %{"hostname" => "dummy.site"}
      |> assert_parsed(%{"event:hostname" => {:is, "dummy.site"}})
    end
  end

  describe "escaping pipe character" do
    test "in simple is filter" do
      %{"goal" => ~S(Foo \| Bar)}
      |> assert_parsed(%{"event:goal" => {:is, {:event, "Foo | Bar"}}})
    end

    test "in member filter" do
      %{"page" => ~S(/|\|)}
      |> assert_parsed(%{"event:page" => {:member, ["/", "|"]}})
    end
  end

  describe "is not filter type" do
    test "simple is not filter" do
      %{"page" => "!/"}
      |> assert_parsed(%{"event:page" => {:is_not, "/"}})

      %{"props" => %{"cta" => "!Top"}}
      |> assert_parsed(%{"event:props:cta" => {:is_not, "Top"}})
    end
  end

  describe "member filter type" do
    test "simple member filter" do
      %{"page" => "/|/blog"}
      |> assert_parsed(%{"event:page" => {:member, ["/", "/blog"]}})
    end

    test "escaping pipe character" do
      %{"page" => "/|\\|"}
      |> assert_parsed(%{"event:page" => {:member, ["/", "|"]}})
    end

    test "mixed goals" do
      %{"goal" => "Signup|Visit /thank-you"}
      |> assert_parsed(%{"event:goal" => {:member, [{:event, "Signup"}, {:page, "/thank-you"}]}})

      %{"goal" => "Visit /thank-you|Signup"}
      |> assert_parsed(%{"event:goal" => {:member, [{:page, "/thank-you"}, {:event, "Signup"}]}})
    end
  end

  describe "matches_member filter type" do
    test "parses matches_member filter type" do
      %{"page" => "/|/blog**"}
      |> assert_parsed(%{"event:page" => {:matches_member, ["/", "/blog**"]}})
    end

    test "parses not_matches_member filter type" do
      %{"page" => "!/|/blog**"}
      |> assert_parsed(%{"event:page" => {:not_matches_member, ["/", "/blog**"]}})
    end
  end

  describe "contains filter type" do
    test "single contains" do
      %{"page" => "~blog"}
      |> assert_parsed(%{"event:page" => {:matches, "**blog**"}})
    end

    test "negated contains" do
      %{"page" => "!~articles"}
      |> assert_parsed(%{"event:page" => {:does_not_match, "**articles**"}})
    end

    test "contains member" do
      %{"page" => "~articles|blog"}
      |> assert_parsed(%{"event:page" => {:matches_member, ["**articles**", "**blog**"]}})
    end

    test "not contains member" do
      %{"page" => "!~articles|blog"}
      |> assert_parsed(%{"event:page" => {:not_matches_member, ["**articles**", "**blog**"]}})
    end
  end

  describe "not_member filter type" do
    test "simple not_member filter" do
      %{"page" => "!/|/blog"}
      |> assert_parsed(%{"event:page" => {:not_member, ["/", "/blog"]}})
    end

    test "mixed goals" do
      %{"goal" => "!Signup|Visit /thank-you"}
      |> assert_parsed(%{
        "event:goal" => {:not_member, [{:event, "Signup"}, {:page, "/thank-you"}]}
      })

      %{"goal" => "!Visit /thank-you|Signup"}
      |> assert_parsed(%{
        "event:goal" => {:not_member, [{:page, "/thank-you"}, {:event, "Signup"}]}
      })
    end
  end

  describe "matches filter type" do
    test "can be used with `goal` or `page` filters" do
      %{"page" => "/blog/post-*"}
      |> assert_parsed(%{"event:page" => {:matches, "/blog/post-*"}})

      %{"goal" => "Visit /blog/post-*"}
      |> assert_parsed(%{"event:goal" => {:matches, {:page, "/blog/post-*"}}})
    end

    test "other filters default to `is` even when wildcard is present" do
      %{"country" => "Germa**"}
      |> assert_parsed(%{"visit:country" => {:is, "Germa**"}})
    end
  end

  describe "does_not_match filter type" do
    test "can be used with `page` filter" do
      %{"page" => "!/blog/post-*"}
      |> assert_parsed(%{"event:page" => {:does_not_match, "/blog/post-*"}})
    end

    test "other filters default to is_not even when wildcard is present" do
      %{"country" => "!Germa**"}
      |> assert_parsed(%{"visit:country" => {:is_not, "Germa**"}})
    end
  end

  describe "contains prefix filter type" do
    test "can be used with any filter" do
      %{"page" => "~/blog/post"}
      |> assert_parsed(%{"event:page" => {:matches, "**/blog/post**"}})

      %{"source" => "~facebook"}
      |> assert_parsed(%{"visit:source" => {:matches, "**facebook**"}})
    end
  end
end
