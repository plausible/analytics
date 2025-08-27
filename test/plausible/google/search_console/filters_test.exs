defmodule Plausible.Google.SearchConsole.FiltersTest do
  alias Plausible.Google.SearchConsole.Filters
  use Plausible.DataCase, async: true

  test "transforms simple page filter" do
    filters = [
      [:is, "visit:entry_page", ["/page"]]
    ]

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters, "")

    assert transformed == [
             %{
               filters: [
                 %{
                   dimension: "page",
                   operator: "includingRegex",
                   expression: "https://plausible.io/page"
                 }
               ]
             }
           ]
  end

  test "transforms matches_wildcard page filter" do
    filters = [
      [:matches_wildcard, "visit:entry_page", ["*page*"]]
    ]

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters, "")

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

  test "transforms is page filter" do
    filters = [
      [:is, "visit:entry_page", ["/pageA", "/pageB"]]
    ]

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters, "")

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

  test "transforms matches multiple page filter" do
    filters = [
      [:matches_wildcard, "visit:entry_page", ["/pageA*", "/pageB*"]]
    ]

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters, "")

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
    filters = [
      [:matches_wildcard, "event:page", ["/pageA*", "/pageB*"]]
    ]

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters, "")

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
    filters = [
      [:is, "visit:screen", ["Desktop"]]
    ]

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters, "")

    assert transformed == [
             %{
               filters: [
                 %{dimension: "device", operator: "includingRegex", expression: "DESKTOP"}
               ]
             }
           ]
  end

  test "transforms is visit:screen filter" do
    filters = [
      [:is, "visit:screen", ["Mobile", "Tablet"]]
    ]

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters, "")

    assert transformed == [
             %{
               filters: [
                 %{dimension: "device", operator: "includingRegex", expression: "MOBILE|TABLET"}
               ]
             }
           ]
  end

  test "transforms simple visit:country filter to alpha3" do
    filters = [
      [:is, "visit:country", ["EE"]]
    ]

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters, "")

    assert transformed == [
             %{filters: [%{dimension: "country", operator: "includingRegex", expression: "EST"}]}
           ]
  end

  test "transforms member visit:country filter" do
    filters = [
      [:is, "visit:country", ["EE", "PL"]]
    ]

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters, "")

    assert transformed == [
             %{
               filters: [
                 %{dimension: "country", operator: "includingRegex", expression: "EST|POL"}
               ]
             }
           ]
  end

  test "filters can be combined" do
    filters = [
      [:is, "visit:country", ["EE", "PL"]],
      [:matches_wildcard, "visit:entry_page", ["*web-analytics*"]],
      [:is, "visit:screen", ["Desktop"]]
    ]

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters, "")

    assert transformed == [
             %{
               filters: [
                 %{dimension: "device", operator: "includingRegex", expression: "DESKTOP"},
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

  test "visit:source and visit:channel filters are ignored" do
    filters = [
      [:is, "visit:source", ["Google"]],
      [:is, "visit:channel", ["Organic search"]],
      [:is, "visit:screen", ["Desktop"]]
    ]

    {:ok, transformed} = Filters.transform("sc-domain:plausible.io", filters, "")

    assert transformed == [
             %{
               filters: [
                 %{dimension: "device", operator: "includingRegex", expression: "DESKTOP"}
               ]
             }
           ]
  end

  test "when unsupported filter is included the whole set becomes invalid" do
    filters = [
      [:matches_wildcard, "visit:entry_page", "*web-analytics*"],
      [:is, "visit:screen", "Desktop"],
      [:member, "visit:country", ["EE", "PL"]],
      [:is, "visit:utm_medium", "facebook"]
    ]

    assert :unsupported_filters = Filters.transform("sc-domain:plausible.io", filters, "")
  end
end
