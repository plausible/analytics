defmodule Plausible.Google.SearchConsole.FiltersTest do
  alias Plausible.Google.SearchConsole.Filters
  use Plausible.DataCase, async: true

  test "transforms simple page filter" do
    filters = %{
      "visit:entry_page" => {:is, "/page"}
    }

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters)

    assert transformed == [
             %{filters: [%{dimension: "page", expression: "https://plausible.io/page"}]}
           ]
  end

  test "transforms matches page filter" do
    filters = %{
      "visit:entry_page" => {:matches, "*page*"}
    }

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters)

    assert transformed == [
             %{
               filters: [
                 %{
                   dimension: "page",
                   operator: "includingRegex",
                   expression: "^https://plausible\\.io.*page.*$"
                 }
               ]
             }
           ]
  end

  test "transforms member page filter" do
    filters = %{
      "visit:entry_page" => {:member, ["/pageA", "/pageB"]}
    }

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters)

    assert transformed == [
             %{
               filters: [
                 %{
                   dimension: "page",
                   operator: "includingRegex",
                   expression: "https://plausible.io/pageA|https://plausible.io/pageB"
                 }
               ]
             }
           ]
  end

  test "transforms matches_member page filter" do
    filters = %{
      "visit:entry_page" => {:matches_member, ["/pageA*", "/pageB*"]}
    }

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters)

    assert transformed == [
             %{
               filters: [
                 %{
                   dimension: "page",
                   operator: "includingRegex",
                   expression: "^https://plausible\\.io/pageA.*$|^https://plausible\\.io/pageB.*$"
                 }
               ]
             }
           ]
  end

  test "transforms event:page exactly like visit:entry_page" do
    filters = %{
      "event:page" => {:matches_member, ["/pageA*", "/pageB*"]}
    }

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters)

    assert transformed == [
             %{
               filters: [
                 %{
                   dimension: "page",
                   operator: "includingRegex",
                   expression: "^https://plausible\\.io/pageA.*$|^https://plausible\\.io/pageB.*$"
                 }
               ]
             }
           ]
  end

  test "transforms simple visit:screen filter" do
    filters = %{
      "visit:screen" => {:is, "Desktop"}
    }

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters)

    assert transformed == [%{filters: [%{dimension: "device", expression: "DESKTOP"}]}]
  end

  test "transforms member visit:screen filter" do
    filters = %{
      "visit:screen" => {:member, ["Mobile", "Tablet"]}
    }

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters)

    assert transformed == [
             %{
               filters: [
                 %{dimension: "device", operator: "includingRegex", expression: "Mobile|Tablet"}
               ]
             }
           ]
  end

  test "transforms simple visit:country filter to alpha3" do
    filters = %{
      "visit:country" => {:is, "EE"}
    }

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters)

    assert transformed == [%{filters: [%{dimension: "country", expression: "EST"}]}]
  end

  test "transforms member visit:country filter" do
    filters = %{
      "visit:country" => {:member, ["EE", "PL"]}
    }

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters)

    assert transformed == [
             %{
               filters: [
                 %{dimension: "country", operator: "includingRegex", expression: "EST|POL"}
               ]
             }
           ]
  end

  test "filters can be combined" do
    filters = %{
      "visit:entry_page" => {:matches, "*web-analytics*"},
      "visit:screen" => {:is, "Desktop"},
      "visit:country" => {:member, ["EE", "PL"]}
    }

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters)

    assert transformed == [
             %{
               filters: [
                 %{dimension: "device", expression: "DESKTOP"},
                 %{
                   dimension: "page",
                   operator: "includingRegex",
                   expression: "^https://plausible\\.io.*web\\-analytics.*$"
                 },
                 %{dimension: "country", operator: "includingRegex", expression: "EST|POL"}
               ]
             }
           ]
  end

  test "when unsupported filter is included the whole set becomes invalid" do
    filters = %{
      "visit:entry_page" => {:matches, "*web-analytics*"},
      "visit:screen" => {:is, "Desktop"},
      "visit:country" => {:member, ["EE", "PL"]},
      "visit:utm_medium" => {:is, "facebook"}
    }

    assert :unsupported_filters = Filters.transform("sc-domain:plausible.io", filters)
  end
end
