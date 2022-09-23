defmodule Plausible.Stats.FilterParserTest do
  use ExUnit.Case, async: true
  alias Plausible.Stats.FilterParser

  def assert_parsed(input, expected_output) do
    assert FilterParser.parse_filters(%{"filters" => input}) == expected_output
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
      |> assert_parsed(%{"event:goal" => {:is, :event, "Signup"}})
    end

    test "pageview goal" do
      "event:goal==Visit /blog"
      |> assert_parsed(%{"event:goal" => {:is, :page, "/blog"}})
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
  end
end
