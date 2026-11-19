defmodule PlausibleE2E.Dashboard.MainGraph do
  @moduledoc false

  alias Playwright.{Expect, Locator, Page}
  require Playwright.Test

  def graph_tooltip(page), do: Page.get_by_test_id(page, "graph-tooltip")
  def main_series_line(page), do: Page.get_by_test_id(page, "graph-line-series-1")

  def main_series_dot(page, bucket_index),
    do: Page.get_by_test_id(page, "graph-dot-series-1-bucket-#{bucket_index}")

  # Each metric case is {selector, expected_metric_label, [{bucket_index, time_label, metric_value}]}
  def run_metric_cases(page, metric_cases) do
    graph_line = main_series_line(page)
    Expect.to_be_visible!(graph_line)

    for {selector, expected_metric_label, expected_buckets} <- metric_cases do
      Playwright.Test.step "selecting #{expected_metric_label}" do
        Page.locator(page, selector) |> Locator.click!()
        Expect.to_be_visible!(graph_line)

        for {bucket_index, time_label, metric_value} <- expected_buckets do
          main_series_dot(page, bucket_index) |> Locator.hover!()

          Expect.to_have_text!(
            graph_tooltip(page),
            Enum.join([
              expected_metric_label,
              time_label,
              metric_value,
              "Right click for more actions"
            ])
          )
        end
      end
    end
  end
end

defmodule PlausibleE2E.Dashboard.MainGraphNoFiltersTest do
  use PlausibleE2E.Case, async: true

  import PlausibleE2E.Dashboard.MainGraph

  describe "plotting all metrics" do
    # Time label rendering depends on locale. Set it to one with 24h clock
    @describetag Test.use(locale: "en-GB")

    test "with no filters applied", %{page: page, request: request} do
      %{domain: domain} = setup_site(page: page, request: request)
      url = "/" <> domain <> "?period=day&date=2021-01-01"

      populate_stats(
        request: request,
        domain: domain,
        events: [
          %{user_id: 1, name: "pageview", pathname: "/", timestamp: "2021-01-01 00:00:00"},
          %{user_id: 1, name: "pageview", pathname: "/page1", timestamp: "2021-01-01 00:10:00"},
          %{user_id: 1, name: "pageview", pathname: "/page2", timestamp: "2021-01-01 00:20:00"},
          %{user_id: 2, name: "pageview", pathname: "/", timestamp: "2021-01-01 05:00:00"}
        ]
      )

      Page.goto!(page, url, wait_until: :commit)

      run_metric_cases(page, [
        {"#visitors", "Unique visitors",
         [{0, "00:00", "1"}, {1, "01:00", "0"}, {5, "05:00", "1"}]},
        {"#visits", "Total visits", [{0, "00:00", "1"}, {1, "01:00", "0"}, {5, "05:00", "1"}]},
        {"#pageviews", "Total pageviews",
         [{0, "00:00", "3"}, {1, "01:00", "0"}, {5, "05:00", "1"}]},
        {"#views_per_visit", "Views per visit",
         [{0, "00:00", "3"}, {1, "01:00", "0"}, {5, "05:00", "1"}]},
        {"#bounce_rate", "Bounce rate",
         [{0, "00:00", "0%"}, {1, "01:00", "0%"}, {5, "05:00", "100%"}]},
        {"#visit_duration", "Visit duration",
         [{0, "00:00", "20m 00s"}, {1, "01:00", "-"}, {5, "05:00", "0s"}]}
      ])

      Test.step "keeps the last selected metric selected on page reload" do
        Page.reload!(page, wait_until: :commit)
        Expect.to_be_visible!(main_series_line(page))
        main_series_dot(page, 0) |> Locator.hover!()

        Expect.to_have_text!(
          graph_tooltip(page),
          Enum.join(["Visit duration", "00:00", "20m 00s", "Right click for more actions"])
        )
      end

      Test.step "if the last selected metric is not available in the view on page reload, corrects it to default" do
        metric_storage_key = "metric__#{domain}"
        # set stored metric that's invalid for this view
        Page.evaluate!(page, "k => localStorage.setItem(k, 'scroll_depth')", metric_storage_key)
        Page.reload!(page, wait_until: :commit)
        Expect.to_be_visible!(main_series_line(page))
        main_series_dot(page, 0) |> Locator.hover!()

        Expect.to_have_text!(
          graph_tooltip(page),
          Enum.join(["Unique visitors", "00:00", "1", "Right click for more actions"])
        )
      end
    end
  end
end

defmodule PlausibleE2E.Dashboard.MainGraphGoalTest do
  use PlausibleE2E.Case, async: true

  import PlausibleE2E.Dashboard.MainGraph

  describe "plotting all metrics" do
    # Time label rendering depends on locale. Set it to one with 24h clock
    @describetag Test.use(locale: "en-GB")

    test "filtered by goal", %{page: page, request: request} do
      goal_name = "Signup"
      %{domain: domain} = setup_site(page: page, request: request)
      url = "/" <> domain <> "?period=day&date=2021-01-01&f=is,goal,Signup"

      add_goal(request: request, domain: domain, params: %{event_name: goal_name})

      populate_stats(
        request: request,
        domain: domain,
        events: [
          %{user_id: 1, name: "pageview", timestamp: "2021-01-01 00:00:00"},
          %{user_id: 2, name: goal_name, timestamp: "2021-01-01 10:00:00"},
          %{user_id: 2, name: goal_name, timestamp: "2021-01-01 10:10:00"},
          %{user_id: 4, name: "pageview", timestamp: "2021-01-01 10:00:00"},
          %{user_id: 5, name: goal_name, timestamp: "2021-01-01 23:00:00"}
        ]
      )

      Page.goto!(page, url, wait_until: :commit)

      run_metric_cases(page, [
        {"#visitors", "Unique conversions",
         [{0, "00:00", "0"}, {1, "01:00", "0"}, {10, "10:00", "1"}, {23, "23:00", "1"}]},
        {"#events", "Total conversions",
         [{0, "00:00", "0"}, {1, "01:00", "0"}, {10, "10:00", "2"}, {23, "23:00", "1"}]},
        {"#conversion_rate", "Conversion rate",
         [{0, "00:00", "0%"}, {1, "01:00", "0%"}, {10, "10:00", "50%"}, {23, "23:00", "100%"}]}
      ])
    end
  end
end

defmodule PlausibleE2E.Dashboard.MainGraphPageTest do
  use PlausibleE2E.Case, async: true

  import PlausibleE2E.Dashboard.MainGraph

  describe "plotting all metrics" do
    # Time label rendering depends on locale. Set it to one with 24h clock
    @describetag Test.use(locale: "en-GB")

    test "filtered by page", %{page: page, request: request} do
      %{domain: domain} = setup_site(page: page, request: request)
      url = "/" <> domain <> "?period=day&date=2021-01-01&f=is,page,/one"

      populate_stats(
        request: request,
        domain: domain,
        events: [
          %{user_id: 1, name: "pageview", pathname: "/one", timestamp: "2021-01-01 00:00:00"},
          %{user_id: 2, name: "pageview", pathname: "/one", timestamp: "2021-01-01 05:30:00"},
          %{
            user_id: 2,
            name: "engagement",
            pathname: "/one",
            scroll_depth: 90,
            engagement_time: 20 * 60 * 1000,
            timestamp: "2021-01-01 05:50:00"
          },
          %{user_id: 2, name: "pageview", pathname: "/two", timestamp: "2021-01-01 05:50:00"},
          %{user_id: 3, pathname: "/two", name: "pageview", timestamp: "2021-01-01 00:00:00"}
        ]
      )

      Page.goto!(page, url, wait_until: :commit)

      run_metric_cases(page, [
        {"#visitors", "Unique visitors",
         [{0, "00:00", "1"}, {5, "05:00", "1"}, {10, "10:00", "0"}]},
        {"#visits", "Total visits", [{0, "00:00", "1"}, {5, "05:00", "1"}, {10, "10:00", "0"}]},
        {"#pageviews", "Total pageviews",
         [{0, "00:00", "1"}, {5, "05:00", "1"}, {10, "10:00", "0"}]},
        {"#bounce_rate", "Bounce rate",
         [{0, "00:00", "100%"}, {5, "05:00", "0%"}, {10, "10:00", "0%"}]},
        {"#scroll_depth", "Scroll depth",
         [{0, "00:00", "-"}, {5, "05:00", "90%"}, {10, "10:00", "-"}]},
        {"#time_on_page", "Time on page",
         [{0, "00:00", "-"}, {5, "05:00", "20m 00s"}, {10, "10:00", "-"}]}
      ])
    end
  end
end
