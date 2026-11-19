defmodule PlausibleE2E.Dashboard.TopStatsTest do
  use PlausibleE2E.Case, async: true

  defp press(page, key), do: Keyboard.press!(Page.keyboard(page), key)

  # ChronoUnit.DAYS truncation
  defp start_of_day(dt), do: %{dt | hour: 0, minute: 0, second: 0}
  defp minus_days(dt, n), do: DateTime.add(dt, -n * 86_400, :second)
  defp minus_hours(dt, n), do: DateTime.add(dt, -n * 3_600, :second)
  defp minus_minutes(dt, n), do: DateTime.add(dt, -n * 60, :second)
  defp minus_months(dt, n), do: DateTime.shift(dt, month: -n)

  # DateTimeFormatter.ofPattern('EEE, dd MMM')
  defp day_label(dt), do: Calendar.strftime(dt, "%a, %d %b")

  test "site switcher allows switching between different sites", %{page: page, request: request} do
    suffix = random_id()
    # domain name matters in this test, the sites are sorted alphabetically in the dropdown
    %{domain: domain1, user: user} =
      setup_site(page: page, request: request, domain: "a-#{suffix}.example.com")

    %{domain: domain2} =
      setup_site(page: page, request: request, user: user, domain: "b-#{suffix}.example.com")

    %{domain: domain3} =
      setup_site(page: page, request: request, user: user, domain: "c-#{suffix}.example.com")

    populate_stats(request: request, domain: domain1, events: [%{name: "pageview"}])
    populate_stats(request: request, domain: domain2, events: [%{name: "pageview"}])
    populate_stats(request: request, domain: domain3, events: [%{name: "pageview"}])

    Page.goto!(page, "/" <> domain1, wait_until: :commit)

    switcher_button = Page.get_by_test_id(page, "site-switcher-current-site")

    Expect.to_have_text!(switcher_button, domain1)

    Locator.click!(switcher_button)

    domain1_link = Page.get_by_role(page, :link, name: domain1)
    domain2_link = Page.get_by_role(page, :link, name: domain2)
    domain3_link = Page.get_by_role(page, :link, name: domain3)

    Expect.to_be_visible!(domain1_link)
    Expect.to_have_text!(Locator.locator(domain1_link, "kbd"), "1")
    Expect.to_be_visible!(domain2_link)
    Expect.to_have_text!(Locator.locator(domain2_link, "kbd"), "2")
    Expect.to_be_visible!(domain3_link)
    Expect.to_have_text!(Locator.locator(domain3_link, "kbd"), "3")

    Page.get_by_role(page, :link, name: domain2) |> Locator.click!()

    Expect.to_have_url!(page, "/#{domain2}")
    Expect.to_have_text!(switcher_button, domain2)

    # make sure sites are loaded
    Locator.click!(switcher_button)
    Expect.to_be_visible!(domain3_link)
    # keybind should work when dropdown closed
    Locator.click!(switcher_button)
    press(page, "3")

    Expect.to_have_url!(page, "/#{domain3}")
    Expect.to_have_text!(switcher_button, domain3)

    # make sure sites are loaded
    Locator.click!(switcher_button)
    Expect.to_be_visible!(domain1_link)
    # keybind should work when dropdown open
    press(page, "1")

    Expect.to_have_url!(page, "/#{domain1}")
    Expect.to_have_text!(switcher_button, domain1)
  end

  test "current visitors counter shows number of active visitors", %{
    page: page,
    request: request
  } do
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{name: "pageview", timestamp: %{minutesAgo: 2}},
        %{name: "pageview", timestamp: %{minutesAgo: 3}},
        %{name: "pageview", timestamp: %{minutesAgo: 4}},
        %{name: "pageview", timestamp: %{minutesAgo: 4}},
        %{name: "pageview", timestamp: %{minutesAgo: 20}},
        %{name: "pageview", timestamp: %{minutesAgo: 50}}
      ]
    )

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    Expect.to_be_visible!(Page.get_by_text(page, "4 current visitors"))
  end

  test "top stats show relevant metrics", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{user_id: 123, name: "pageview", pathname: "/", timestamp: %{minutesAgo: 120}},
        %{user_id: 123, name: "pageview", pathname: "/", timestamp: %{minutesAgo: 60}},
        %{user_id: 123, name: "pageview", pathname: "/page1", timestamp: %{minutesAgo: 50}},
        %{user_id: 456, name: "pageview", pathname: "/", timestamp: %{minutesAgo: 80}}
      ]
    )

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    Expect.to_have_title!(page, ~r/Plausible/)

    Expect.to_be_visible!(Page.get_by_role(page, :button, name: domain))

    Expect.to_have_text!(Page.locator(page, "#visitors"), "2")
    Expect.to_have_text!(Page.locator(page, "#visits"), "3")
    Expect.to_have_text!(Page.locator(page, "#pageviews"), "4")
    Expect.to_have_text!(Page.locator(page, "#views_per_visit"), "1.33")
    Expect.to_have_text!(Page.locator(page, "#bounce_rate"), "67%")
    Expect.to_have_text!(Page.locator(page, "#visit_duration"), "3m 20s")
  end

  test "different time ranges are supported", %{page: page, request: request} do
    now = current_time()
    start_of_day = start_of_day(now)
    start_of_yesterday = minus_days(start_of_day, 1)
    start_of_month = %{start_of_day | day: 1}
    start_of_last_month = minus_months(start_of_month, 1)
    start_of_year = %{now | month: 1, day: 1}

    expected_counts = [
      %{from: start_of_day, to: now, key: "d"},
      %{from: start_of_yesterday, to: start_of_day, key: "e"},
      %{from: minus_minutes(now, 30), to: now, key: "r"},
      %{from: minus_hours(now, 24), to: now, key: "h"},
      %{from: minus_days(start_of_day, 7), to: start_of_day, key: "w"},
      %{from: minus_days(start_of_day, 28), to: start_of_day, key: "f"},
      %{from: minus_days(start_of_day, 91), to: start_of_day, key: "n"},
      %{from: start_of_month, to: now, key: "m"},
      %{from: start_of_last_month, to: start_of_month, key: "p"},
      %{from: start_of_year, to: now, key: "y"},
      %{from: minus_months(start_of_month, 12), to: start_of_month, key: "l"}
    ]

    event_times = [
      minus_minutes(now, 20),
      minus_hours(now, 12),
      minus_hours(now, 26),
      minus_hours(now, 30),
      minus_hours(now, 35),
      minus_days(now, 5),
      minus_days(now, 17),
      minus_days(now, 54),
      minus_days(now, 120),
      minus_days(now, 720)
    ]

    expected_counts =
      Enum.map(expected_counts, fn expected ->
        value =
          Enum.count(event_times, fn ts ->
            DateTime.compare(ts, expected.from) != :lt and
              DateTime.compare(ts, expected.to) == :lt
          end)

        Map.put(expected, :value, value)
      end)

    events =
      event_times
      |> Enum.with_index()
      |> Enum.map(fn {ts, idx} ->
        %{user_id: idx + 1, name: "pageview", timestamp: time_to_iso(ts)}
      end)

    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(request: request, domain: domain, events: events)

    Page.goto!(page, "/" <> domain, wait_until: :commit)
    Expect.to_be_visible!(Page.get_by_role(page, :button, name: domain))

    Expect.to_have_text!(Page.get_by_test_id(page, "current-query-period"), "Last 28 days")

    visitors = Page.locator(page, "#visitors")

    for expected <- expected_counts do
      press(page, expected.key)
      Expect.to_have_text!(visitors, "#{expected.value}")
    end

    # Realtime
    press(page, "r")
    Expect.to_have_text!(visitors, "1")

    # All time
    press(page, "a")
    Expect.to_have_text!(visitors, "#{length(events)}")
  end

  test "different graph time intervals are available", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{name: "pageview", timestamp: %{minutesAgo: 60}},
        %{name: "pageview", timestamp: %{daysAgo: 5}}
      ]
    )

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    Expect.to_have_text!(Page.get_by_test_id(page, "current-query-period"), "Last 28 days")

    options_menu = Page.get_by_test_id(page, "dashboard-options-menu")

    Locator.click!(options_menu)
    graph_interval_segments = Page.get_by_test_id(page, "graph-interval")
    Expect.to_have_text!(Page.get_by_test_id(page, "current-graph-interval"), "Days")
    Expect.to_have_count!(graph_interval_segments, 1)
    Expect.to_be_visible!(Locator.filter(graph_interval_segments, has_text: "Weeks"))
    Locator.click!(options_menu)

    Page.get_by_test_id(page, "current-query-period") |> Locator.click!()

    page
    |> Page.get_by_test_id("query-period-picker")
    |> Locator.get_by_role(:link, name: "Today")
    |> Locator.click!()

    Locator.click!(options_menu)
    Expect.to_have_text!(Page.get_by_test_id(page, "current-graph-interval"), "Hours")
    Expect.to_have_count!(graph_interval_segments, 1)
    Locator.filter(graph_interval_segments, has_text: "Min") |> Locator.click!()
    Locator.click!(options_menu)
    Expect.to_have_text!(Page.get_by_test_id(page, "current-graph-interval"), "Min")
  end

  test "navigating dates previous next time periods", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)

    now = current_time()
    start_of_day = start_of_day(now)
    start_of_yesterday = minus_days(start_of_day, 1)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{name: "pageview", timestamp: time_to_iso(now)},
        %{name: "pageview", timestamp: time_to_iso(minus_hours(start_of_day, 3))},
        %{name: "pageview", timestamp: time_to_iso(minus_hours(start_of_day, 4))},
        %{name: "pageview", timestamp: time_to_iso(minus_hours(start_of_yesterday, 3))},
        %{name: "pageview", timestamp: time_to_iso(minus_hours(start_of_yesterday, 4))},
        %{name: "pageview", timestamp: time_to_iso(minus_hours(start_of_yesterday, 5))}
      ]
    )

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    current_query_period = Page.get_by_test_id(page, "current-query-period")
    query_period_picker = Page.get_by_test_id(page, "query-period-picker")
    back_button = Locator.get_by_test_id(query_period_picker, "period-move-back")
    forward_button = Locator.get_by_test_id(query_period_picker, "period-move-forward")
    visitors = Page.locator(page, "#visitors")

    Locator.click!(current_query_period)
    query_period_picker |> Locator.get_by_role(:link, name: "Today") |> Locator.click!()

    Expect.to_have_text!(current_query_period, "Today")
    Expect.to_have_text!(visitors, "1")
    Expect.not_to_have_css!(back_button, "cursor", "not-allowed")
    Expect.to_have_css!(forward_button, "cursor", "not-allowed")

    Locator.click!(back_button)

    yesterday_label = day_label(start_of_yesterday)

    Expect.to_have_text!(current_query_period, yesterday_label)
    Expect.not_to_have_css!(back_button, "cursor", "not-allowed")
    Expect.not_to_have_css!(forward_button, "cursor", "not-allowed")
    Expect.to_have_text!(visitors, "2")

    Locator.click!(back_button)

    before_yesterday_label = start_of_yesterday |> minus_days(1) |> day_label()

    Expect.to_have_text!(current_query_period, before_yesterday_label)
    Expect.to_have_css!(back_button, "cursor", "not-allowed")
    Expect.not_to_have_css!(forward_button, "cursor", "not-allowed")
    Expect.to_have_text!(visitors, "3")

    Locator.click!(forward_button)

    Expect.to_have_text!(current_query_period, yesterday_label)
    Expect.not_to_have_css!(back_button, "cursor", "not-allowed")
    Expect.not_to_have_css!(forward_button, "cursor", "not-allowed")
    Expect.to_have_text!(visitors, "2")

    Locator.click!(forward_button)

    Expect.to_have_text!(current_query_period, "Today")
    Expect.not_to_have_css!(back_button, "cursor", "not-allowed")
    Expect.to_have_css!(forward_button, "cursor", "not-allowed")
    Expect.to_have_text!(visitors, "1")
  end

  test "selecting a custom date range", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)

    # NOTE: As the calendar renders contents dynamically, we cannot tell for sure
    # whether the day before today will be visible without switching month.
    # To make things simpler, we only test a single-day range of today.

    now = current_time()
    start_of_day = start_of_day(now)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{name: "pageview", timestamp: time_to_iso(now)},
        %{name: "pageview", timestamp: time_to_iso(minus_days(start_of_day, 3))}
      ]
    )

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    current_query_period = Page.get_by_test_id(page, "current-query-period")
    query_period_picker = Page.get_by_test_id(page, "query-period-picker")
    visitors = Page.locator(page, "#visitors")

    # The original does not await this click.
    Locator.click!(current_query_period)
    query_period_picker |> Locator.get_by_role(:link, name: "Custom range") |> Locator.click!()

    # DateTimeFormatter.ofPattern('MMMM d, YYYY')
    today_label = Calendar.strftime(start_of_day, "%B %-d, %Y")

    Page.get_by_label(page, today_label) |> Locator.click!()
    Page.get_by_label(page, today_label) |> Locator.click!()

    Expect.to_have_text!(current_query_period, "Today")
    Expect.to_have_text!(visitors, "1")
  end

  test "comparing stats over time is supported", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{name: "pageview", timestamp: %{daysAgo: 2}},
        %{name: "pageview", timestamp: %{daysAgo: 4}},
        %{name: "pageview", timestamp: %{daysAgo: 30}},
        %{name: "pageview", timestamp: %{daysAgo: 30}},
        %{name: "pageview", timestamp: %{daysAgo: 31}},
        %{name: "pageview", timestamp: %{daysAgo: 370}}
      ]
    )

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    Expect.to_have_text!(Page.get_by_test_id(page, "current-query-period"), "Last 28 days")

    Page.get_by_test_id(page, "query-period-picker") |> Locator.click!()

    page
    |> Page.get_by_test_id("query-period-picker")
    |> Locator.get_by_role(:link, name: "Compare")
    |> Locator.click!()

    previous_period_button = Page.get_by_role(page, :button, name: "Previous period")

    Expect.to_be_visible!(previous_period_button)

    visitors = Page.locator(page, "#visitors")
    previous_visitors = Page.locator(page, "#previous-visitors")

    Expect.to_have_text!(visitors, "2")
    Expect.to_have_text!(previous_visitors, "3")

    Locator.click!(previous_period_button)
    Page.get_by_role(page, :link, name: "Year over year") |> Locator.click!()

    Expect.to_be_visible!(Page.get_by_role(page, :button, name: "Year over year"))

    Expect.to_have_text!(visitors, "2")
    Expect.to_have_text!(previous_visitors, "1")
  end
end
