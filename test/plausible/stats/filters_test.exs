defmodule Plausible.Stats.FiltersTest do
  use ExUnit.Case, async: true
  alias Plausible.Stats.Filters

  doctest Plausible.Stats.Filters
  doctest Plausible.Stats.Filters.Utils

  describe "page regex" do
    test "matches escaped pipes literally" do
      regex = Regex.compile!(Filters.Utils.page_regex("/post\\|1"))

      assert Regex.match?(regex, "/post|1")
      refute Regex.match?(regex, "/post")
      refute Regex.match?(regex, "1")
      refute Regex.match?(regex, "/post|1/more")
    end

    test "anchors every alternative to the whole path" do
      regex = Regex.compile!(Filters.Utils.page_regex("/pricing|/plans"))

      for path <- ["/pricing", "/plans"], do: assert(Regex.match?(regex, path))

      for path <- ["/pricing/enterprise", "/legacy/plans", "/pricing|/plans", "/about"] do
        refute Regex.match?(regex, path)
      end
    end

    test "matches * within a whole path" do
      regex = Regex.compile!(Filters.Utils.page_regex("/pricing/*"))

      assert Regex.match?(regex, "/pricing/")
      assert Regex.match?(regex, "/pricing/team")
      assert Regex.match?(regex, "/pricing/team/monthly")
      refute Regex.match?(regex, "/legacy/pricing/team")
      refute Regex.match?(regex, "/pricing")
    end

    test "matches ** within a whole path" do
      regex = Regex.compile!(Filters.Utils.page_regex("/plans/**"))

      assert Regex.match?(regex, "/plans/")
      assert Regex.match?(regex, "/plans/team/monthly")
      refute Regex.match?(regex, "/legacy/plans/team")
    end

    test "escapes other regex syntax" do
      regex = Regex.compile!(Filters.Utils.page_regex("/file.json"))

      assert Regex.match?(regex, "/file.json")
      refute Regex.match?(regex, "/fileXjson")
      refute Regex.match?(regex, "/file.json/more")
    end
  end

  def assert_parsed(input, expected_output) do
    assert Filters.parse(input) == expected_output
  end

  describe "parses filter expression" do
    test "simple positive" do
      "event:name==pageview"
      |> assert_parsed([[:is, "event:name", ["pageview"]]])
    end

    test "simple negative" do
      "event:name!=pageview"
      |> assert_parsed([[:is_not, "event:name", ["pageview"]]])
    end

    test "whitespace is trimmed" do
      " event:name == pageview "
      |> assert_parsed([[:is, "event:name", ["pageview"]]])
    end

    test "wildcard" do
      "event:page==/blog/post-*"
      |> assert_parsed([[:matches_wildcard, "event:page", ["/blog/post-*"]]])
    end

    test "negative wildcard" do
      "event:page!=/blog/post-*"
      |> assert_parsed([[:matches_wildcard_not, "event:page", ["/blog/post-*"]]])
    end

    test "custom event goal" do
      "event:goal==Signup"
      |> assert_parsed([[:is, "event:goal", ["Signup"]]])
    end

    test "pageview goal" do
      "event:goal==Visit /blog"
      |> assert_parsed([[:is, "event:goal", ["Visit /blog"]]])
    end

    test "is" do
      "visit:country==FR|GB|DE"
      |> assert_parsed([[:is, "visit:country", ["FR", "GB", "DE"]]])
    end

    test "member + wildcard" do
      "event:page==/blog**|/newsletter|/*/"
      |> assert_parsed([[:matches_wildcard, "event:page", ["/blog**|/newsletter|/*/"]]])
    end

    test "combined with \";\"" do
      "event:page==/blog**|/newsletter|/*/ ; visit:country==FR|GB|DE"
      |> assert_parsed([
        [:matches_wildcard, "event:page", ["/blog**|/newsletter|/*/"]],
        [:is, "visit:country", ["FR", "GB", "DE"]]
      ])
    end

    test "escaping pipe character" do
      "utm_campaign==campaign \\| 1"
      |> assert_parsed([[:is, "utm_campaign", ["campaign | 1"]]])
    end

    test "escaping pipe character in is filter" do
      "utm_campaign==campaign \\| 1|campaign \\| 2"
      |> assert_parsed([[:is, "utm_campaign", ["campaign | 1", "campaign | 2"]]])
    end

    test "keeps escape characters in is + wildcard filter" do
      "event:page==/**\\|page|/other/page"
      |> assert_parsed([[:matches_wildcard, "event:page", ["/**\\|page|/other/page"]]])
    end

    test "gracefully fails to parse garbage" do
      "bfg10309\uff1cs1\ufe65s2\u02bas3\u02b9hjl10309"
      |> assert_parsed([])
    end

    test "gracefully fails to parse garbage with double quotes" do
      "\";print(md5(31337));$a=\""
      |> assert_parsed([])
    end

    test "gracefully fails to parse garbage country code" do
      "visit:country==AKSJSDFKJSS"
      |> assert_parsed([])
    end

    test "gracefully fails to parse garbage country code (with pipes)" do
      "visit:country==ET'||DBMS_PIPE.RECEIVE_MESSAGE(CHR(98)||CHR(98)||CHR(98),15)||'"
      |> assert_parsed([])
    end
  end

  describe "parses filters list" do
    test "simple" do
      [["is", "event:name", ["pageview"]]]
      |> Jason.encode!()
      |> assert_parsed([[:is, "event:name", ["pageview"]]])
    end
  end
end
