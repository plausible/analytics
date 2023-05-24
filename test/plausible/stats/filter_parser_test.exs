defmodule Plausible.Stats.FilterParserTest do
  use ExUnit.Case, async: true
  alias Plausible.Stats.FilterParser

  doctest Plausible.Stats.FilterParser

  def assert_parsed(input, expected_output) do
    assert FilterParser.parse_filters(input) == expected_output
  end

  describe "parses filter expression" do
    test "simple positive" do
      "event:name==pageview"
      |> assert_parsed(%{"event:name" => {:is, "pageview"}})
    end

    test "simple negative" do
      "event:name!=pageview"
      |> assert_parsed(%{"event:name" => {:is_not, "pageview"}})
    end

    test "whitespace is trimmed" do
      " event:name == pageview "
      |> assert_parsed(%{"event:name" => {:is, "pageview"}})
    end

    test "wildcard" do
      "event:page==/blog/post-*"
      |> assert_parsed(%{"event:page" => {:matches, "/blog/post-*"}})
    end

    test "negative wildcard" do
      "event:page!=/blog/post-*"
      |> assert_parsed(%{"event:page" => {:does_not_match, "/blog/post-*"}})
    end

    test "custom event goal" do
      "event:goal==Signup"
      |> assert_parsed(%{"event:goal" => {:is, {:event, "Signup"}}})
    end

    test "pageview goal" do
      "event:goal==Visit /blog"
      |> assert_parsed(%{"event:goal" => {:is, {:page, "/blog"}}})
    end

    test "member" do
      "visit:country==FR|GB|DE"
      |> assert_parsed(%{"visit:country" => {:member, ["FR", "GB", "DE"]}})
    end

    test "member + wildcard" do
      "event:page==/blog**|/newsletter|/*/"
      |> assert_parsed(%{"event:page" => {:matches, "/blog**|/newsletter|/*/"}})
    end

    test "combined with \";\"" do
      "event:page==/blog**|/newsletter|/*/ ; visit:country==FR|GB|DE"
      |> assert_parsed(%{
        "event:page" => {:matches, "/blog**|/newsletter|/*/"},
        "visit:country" => {:member, ["FR", "GB", "DE"]}
      })
    end

    test "escaping pipe character" do
      "utm_campaign==campaign \\| 1"
      |> assert_parsed(%{"utm_campaign" => {:is, "campaign | 1"}})
    end

    test "escaping pipe character in member filter" do
      "utm_campaign==campaign \\| 1|campaign \\| 2"
      |> assert_parsed(%{"utm_campaign" => {:member, ["campaign | 1", "campaign | 2"]}})
    end

    test "keeps escape characters in member + wildcard filter" do
      "event:page==/**\\|page|/other/page"
      |> assert_parsed(%{"event:page" => {:matches, "/**\\|page|/other/page"}})
    end

    test "gracefully fails to parse garbage" do
      "bfg10309\uff1cs1\ufe65s2\u02bas3\u02b9hjl10309"
      |> assert_parsed(%{})
    end

    test "gracefully fails to parse garbage with double quotes" do
      "\";print(md5(31337));$a=\""
      |> assert_parsed(%{})
    end

    test "gracefully fails to parse garbage country code" do
      "visit:country==AKSJSDFKJSS"
      |> assert_parsed(%{})
    end

    test "gracefully fails to parse garbage country code (with pipes)" do
      "visit:country==ET'||DBMS_PIPE.RECEIVE_MESSAGE(CHR(98)||CHR(98)||CHR(98),15)||'"
      |> assert_parsed(%{})
    end
  end
end
