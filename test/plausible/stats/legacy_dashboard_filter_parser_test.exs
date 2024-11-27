defmodule Plausible.Stats.Legacy.DashboardFilterParserTest do
  use ExUnit.Case, async: true
  alias Plausible.Stats.Filters.LegacyDashboardFilterParser

  def assert_parsed(filters, expected_output) do
    assert LegacyDashboardFilterParser.parse_and_prefix(filters) == expected_output
  end

  describe "adding prefix" do
    test "adds appropriate prefix to filter" do
      %{"page" => "/"}
      |> assert_parsed([[:is, "event:page", ["/"], %{}]])

      %{"goal" => "Signup"}
      |> assert_parsed([[:is, "event:goal", ["Signup"], %{}]])

      %{"goal" => "Visit /blog"}
      |> assert_parsed([[:is, "event:goal", ["Visit /blog"], %{}]])

      %{"source" => "Google"}
      |> assert_parsed([[:is, "visit:source", ["Google"], %{}]])

      %{"referrer" => "cnn.com"}
      |> assert_parsed([[:is, "visit:referrer", ["cnn.com"], %{}]])

      %{"utm_medium" => "search"}
      |> assert_parsed([[:is, "visit:utm_medium", ["search"], %{}]])

      %{"utm_source" => "bing"}
      |> assert_parsed([[:is, "visit:utm_source", ["bing"], %{}]])

      %{"utm_content" => "content"}
      |> assert_parsed([[:is, "visit:utm_content", ["content"], %{}]])

      %{"utm_term" => "term"}
      |> assert_parsed([[:is, "visit:utm_term", ["term"], %{}]])

      %{"screen" => "Desktop"}
      |> assert_parsed([[:is, "visit:screen", ["Desktop"], %{}]])

      %{"browser" => "Opera"}
      |> assert_parsed([[:is, "visit:browser", ["Opera"], %{}]])

      %{"browser_version" => "10.1"}
      |> assert_parsed([[:is, "visit:browser_version", ["10.1"], %{}]])

      %{"os" => "Linux"}
      |> assert_parsed([[:is, "visit:os", ["Linux"], %{}]])

      %{"os_version" => "13.0"}
      |> assert_parsed([[:is, "visit:os_version", ["13.0"], %{}]])

      %{"country" => "EE"}
      |> assert_parsed([[:is, "visit:country", ["EE"], %{}]])

      %{"region" => "EE-12"}
      |> assert_parsed([[:is, "visit:region", ["EE-12"], %{}]])

      %{"city" => "123"}
      |> assert_parsed([[:is, "visit:city", ["123"], %{}]])

      %{"entry_page" => "/blog"}
      |> assert_parsed([[:is, "visit:entry_page", ["/blog"], %{}]])

      %{"exit_page" => "/blog"}
      |> assert_parsed([[:is, "visit:exit_page", ["/blog"], %{}]])

      %{"props" => %{"cta" => "Top"}}
      |> assert_parsed([[:is, "event:props:cta", ["Top"], %{}]])

      %{"hostname" => "dummy.site"}
      |> assert_parsed([[:is, "event:hostname", ["dummy.site"], %{}]])
    end
  end

  describe "escaping pipe character" do
    test "in simple is filter" do
      %{"goal" => ~S(Foo \| Bar)}
      |> assert_parsed([[:is, "event:goal", ["Foo | Bar"], %{}]])
    end

    test "in member filter" do
      %{"page" => ~S(/|\|)}
      |> assert_parsed([[:is, "event:page", ["/", "|"], %{}]])
    end
  end

  describe "is not filter type" do
    test "simple is not filter" do
      %{"page" => "!/"}
      |> assert_parsed([[:is_not, "event:page", ["/"], %{}]])

      %{"props" => %{"cta" => "!Top"}}
      |> assert_parsed([[:is_not, "event:props:cta", ["Top"], %{}]])
    end
  end

  describe "is filter type" do
    test "simple is filter" do
      %{"page" => "/|/blog"}
      |> assert_parsed([[:is, "event:page", ["/", "/blog"], %{}]])
    end

    test "escaping pipe character" do
      %{"page" => "/|\\|"}
      |> assert_parsed([[:is, "event:page", ["/", "|"], %{}]])
    end

    test "mixed goals" do
      %{"goal" => "Signup|Visit /thank-you"}
      |> assert_parsed([[:is, "event:goal", ["Signup", "Visit /thank-you"], %{}]])

      %{"goal" => "Visit /thank-you|Signup"}
      |> assert_parsed([[:is, "event:goal", ["Visit /thank-you", "Signup"], %{}]])
    end
  end

  describe "matches_wildcard filter type" do
    test "parses matches filter type" do
      %{"page" => "/|/blog**"}
      |> assert_parsed([[:matches_wildcard, "event:page", ["/", "/blog**"], %{}]])
    end

    test "parses not_matches filter type" do
      %{"page" => "!/|/blog**"}
      |> assert_parsed([[:matches_wildcard_not, "event:page", ["/", "/blog**"], %{}]])
    end

    test "single matches" do
      %{"page" => "~blog"}
      |> assert_parsed([[:contains, "event:page", ["blog"], %{}]])
    end

    test "negated matches" do
      %{"page" => "!~articles"}
      |> assert_parsed([[:matches_wildcard_not, "event:page", ["**articles**"], %{}]])
    end

    test "matches member" do
      %{"page" => "~articles|blog"}
      |> assert_parsed([[:contains, "event:page", ["articles", "blog"], %{}]])
    end

    test "not matches member" do
      %{"page" => "!~articles|blog"}
      |> assert_parsed([[:matches_wildcard_not, "event:page", ["**articles**", "**blog**"], %{}]])
    end

    test "other filters default to `is` even when wildcard is present" do
      %{"country" => "Germa**"}
      |> assert_parsed([[:is, "visit:country", ["Germa**"], %{}]])
    end

    test "can be used with `page` filter" do
      %{"page" => "!/blog/post-*"}
      |> assert_parsed([[:matches_wildcard_not, "event:page", ["/blog/post-*"], %{}]])
    end

    test "other filters default to is_not even when wildcard is present" do
      %{"country" => "!Germa**"}
      |> assert_parsed([[:is_not, "visit:country", ["Germa**"], %{}]])
    end
  end

  describe "is_not filter type" do
    test "simple is_not filter" do
      %{"page" => "!/|/blog"}
      |> assert_parsed([[:is_not, "event:page", ["/", "/blog"], %{}]])
    end

    test "mixed goals" do
      %{"goal" => "!Signup|Visit /thank-you"}
      |> assert_parsed([
        [:is_not, "event:goal", ["Signup", "Visit /thank-you"], %{}]
      ])

      %{"goal" => "!Visit /thank-you|Signup"}
      |> assert_parsed([
        [:is_not, "event:goal", ["Visit /thank-you", "Signup"], %{}]
      ])
    end
  end

  describe "contains prefix filter type" do
    test "can be used with any filter" do
      %{"page" => "~/blog/post"}
      |> assert_parsed([[:contains, "event:page", ["/blog/post"], %{}]])

      %{"source" => "~facebook"}
      |> assert_parsed([[:contains, "visit:source", ["facebook"], %{}]])
    end
  end
end
