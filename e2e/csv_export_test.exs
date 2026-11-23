defmodule PlausibleE2E.Dashboard.CsvExportTest do
  use PlausibleE2E.Case, async: true

  alias Playwright.Download

  @expected_headers %{
    default_visitors_csv:
      ~w(date visitors pageviews visits views_per_visit bounce_rate visit_duration),
    page_filtered_visitors_csv:
      ~w(date visitors pageviews visits bounce_rate time_on_page scroll_depth),
    goal_filtered_visitors_csv: ~w(date unique_conversions total_conversions conversion_rate),
    pages_breakdown: ~w(name visitors pageviews bounce_rate time_on_page scroll_depth),
    entry_pages_breakdown: ~w(name unique_entrances total_entrances bounce_rate visit_duration),
    exit_pages_breakdown: ~w(name unique_exits total_exits exit_rate),
    exit_pages_no_exit_rate: ~w(name unique_exits total_exits),
    common_breakdown: ~w(name visitors bounce_rate visit_duration),
    common_goal_filtered_breakdown: ~w(name conversions conversion_rate),
    name_and_visitors: ~w(name visitors),
    name_version_and_visitors: ~w(name version visitors),
    name_version_goal_filtered: ~w(name version conversions conversion_rate),
    custom_props_default: ~w(property value visitors events percentage),
    custom_props_goal_filtered: ~w(property value visitors events conversion_rate),
    conversions_breakdown: ~w(name unique_conversions total_conversions)
  }

  @utm_and_source_reports ~w(sources.csv channels.csv referrers.csv utm_mediums.csv utm_sources.csv utm_campaigns.csv utm_contents.csv utm_terms.csv)

  @simple_location_and_device_reports ~w(countries.csv regions.csv cities.csv browsers.csv operating_systems.csv devices.csv)

  @version_reports ~w(browser_versions.csv operating_system_versions.csv)

  defp parse_all_csvs(files) do
    Map.new(files, fn {filename, content} ->
      rows =
        content
        |> String.split(~r/\r?\n/)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&String.split(&1, ","))

      {filename, rows}
    end)
  end

  defp get_csv(csvs, filename) do
    case csvs do
      %{^filename => rows} -> rows
      _ -> raise "Expected #{filename} in CSV export"
    end
  end

  test "csv export column headers match expected metrics for each report", %{
    page: page,
    request: request
  } do
    %{domain: domain} = setup_site(page: page, request: request)
    add_custom_prop(page: page, domain: domain, name: "author")

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{name: "pageview", "meta.key": ["author"], "meta.value": ["john"]},
        %{name: "Signup", "meta.key": ["author"], "meta.value": ["john"]}
      ]
    )

    Test.step "without any filters" do
      Page.goto!(page, "/#{domain}?period=all", wait_until: :commit)

      csvs = parse_all_csvs(trigger_export_and_await_download(page))

      assert get_csv(csvs, "visitors.csv") |> hd() == @expected_headers.default_visitors_csv
      assert get_csv(csvs, "pages.csv") |> hd() == @expected_headers.pages_breakdown
      assert get_csv(csvs, "entry_pages.csv") |> hd() == @expected_headers.entry_pages_breakdown
      assert get_csv(csvs, "exit_pages.csv") |> hd() == @expected_headers.exit_pages_breakdown

      for filename <- @utm_and_source_reports do
        assert get_csv(csvs, filename) |> hd() == @expected_headers.common_breakdown
      end

      for filename <- @simple_location_and_device_reports do
        assert get_csv(csvs, filename) |> hd() == @expected_headers.name_and_visitors
      end

      for filename <- @version_reports do
        assert get_csv(csvs, filename) |> hd() == @expected_headers.name_version_and_visitors
      end

      assert get_csv(csvs, "custom_props.csv") |> hd() == @expected_headers.custom_props_default
      assert get_csv(csvs, "conversions.csv") |> hd() == @expected_headers.conversions_breakdown
    end

    Test.step "with a page filter" do
      Page.goto!(page, "/#{domain}?period=all&f=is,page,/", wait_until: :commit)

      Expect.to_be_visible!(Page.get_by_role(page, :button, name: "Remove filter: Page is /"))

      csvs = parse_all_csvs(trigger_export_and_await_download(page))

      assert get_csv(csvs, "visitors.csv") |> hd() == @expected_headers.page_filtered_visitors_csv
      assert get_csv(csvs, "pages.csv") |> hd() == @expected_headers.pages_breakdown
      assert get_csv(csvs, "entry_pages.csv") |> hd() == @expected_headers.entry_pages_breakdown
      assert get_csv(csvs, "exit_pages.csv") |> hd() == @expected_headers.exit_pages_no_exit_rate

      for filename <- @utm_and_source_reports do
        assert get_csv(csvs, filename) |> hd() == @expected_headers.common_breakdown
      end

      for filename <- @simple_location_and_device_reports do
        assert get_csv(csvs, filename) |> hd() == @expected_headers.name_and_visitors
      end

      for filename <- @version_reports do
        assert get_csv(csvs, filename) |> hd() == @expected_headers.name_version_and_visitors
      end

      assert get_csv(csvs, "custom_props.csv") |> hd() == @expected_headers.custom_props_default
      assert get_csv(csvs, "conversions.csv") |> hd() == @expected_headers.conversions_breakdown
    end

    Test.step "with a goal filter" do
      add_goal(request: request, domain: domain, params: %{event_name: "Signup"})

      Page.goto!(page, "/#{domain}?period=all&f=is,goal,Signup", wait_until: :commit)

      Expect.to_be_visible!(
        Page.get_by_role(page, :button, name: "Remove filter: Goal is Signup")
      )

      csvs = parse_all_csvs(trigger_export_and_await_download(page))

      assert get_csv(csvs, "visitors.csv") |> hd() == @expected_headers.goal_filtered_visitors_csv

      for filename <-
            ["pages.csv", "entry_pages.csv", "exit_pages.csv"] ++
              @utm_and_source_reports ++ @simple_location_and_device_reports do
        assert get_csv(csvs, filename) |> hd() == @expected_headers.common_goal_filtered_breakdown
      end

      for filename <- @version_reports do
        assert get_csv(csvs, filename) |> hd() == @expected_headers.name_version_goal_filtered
      end

      assert get_csv(csvs, "custom_props.csv") |> hd() ==
               @expected_headers.custom_props_goal_filtered

      assert get_csv(csvs, "conversions.csv") |> hd() == @expected_headers.conversions_breakdown
    end

    Test.step "with a custom prop filter" do
      Page.goto!(page, "/#{domain}?period=all&f=is,props:author,john", wait_until: :commit)

      Expect.to_be_visible!(
        Page.get_by_role(page, :button, name: "Remove filter: Property 'author' is john")
      )

      csvs = parse_all_csvs(trigger_export_and_await_download(page))

      assert get_csv(csvs, "visitors.csv") |> hd() == @expected_headers.default_visitors_csv
      assert get_csv(csvs, "pages.csv") |> hd() == @expected_headers.pages_breakdown
      assert get_csv(csvs, "entry_pages.csv") |> hd() == @expected_headers.entry_pages_breakdown
      assert get_csv(csvs, "exit_pages.csv") |> hd() == @expected_headers.exit_pages_no_exit_rate

      for filename <- @utm_and_source_reports do
        assert get_csv(csvs, filename) |> hd() == @expected_headers.common_breakdown
      end

      for filename <- @simple_location_and_device_reports do
        assert get_csv(csvs, filename) |> hd() == @expected_headers.name_and_visitors
      end

      for filename <- @version_reports do
        assert get_csv(csvs, filename) |> hd() == @expected_headers.name_version_and_visitors
      end

      assert get_csv(csvs, "custom_props.csv") |> hd() == @expected_headers.custom_props_default
      assert get_csv(csvs, "conversions.csv") |> hd() == @expected_headers.conversions_breakdown
    end
  end

  test "filters out empty visit:* dimension values", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)

    base = %{
      name: "pageview",
      pathname: "/",
      timestamp: "2021-01-01 12:00:00",
      utm_medium: "t",
      utm_source: "t",
      utm_campaign: "t",
      utm_content: "t",
      utm_term: "t",
      country_code: "EE",
      subdivision1_code: "EE-37",
      city_geoname_id: 588_409
    }

    populate_stats(
      request: request,
      domain: domain,
      events: [
        # session with empty entry page: excluded from entry_pages.csv
        Map.merge(base, %{user_id: 1, pathname: ""}),
        Map.merge(base, %{user_id: 1, pathname: "/", timestamp: "2021-01-01 12:01:00"}),
        # session with empty exit page: excluded from exit_pages.csv
        Map.merge(base, %{user_id: 2, pathname: "/"}),
        Map.merge(base, %{user_id: 2, pathname: "", timestamp: "2021-01-01 12:01:00"}),
        # one bad utm_* per session: each excluded from its own report
        Map.merge(base, %{user_id: 3, utm_medium: ""}),
        Map.merge(base, %{user_id: 4, utm_source: ""}),
        Map.merge(base, %{user_id: 5, utm_campaign: ""}),
        Map.merge(base, %{user_id: 6, utm_content: ""}),
        Map.merge(base, %{user_id: 7, utm_term: ""}),
        # one bad location per session: each excluded from its own report
        Map.merge(base, %{user_id: 8, country_code: "ZZ"}),
        Map.merge(base, %{user_id: 9, subdivision1_code: ""}),
        Map.merge(base, %{user_id: 10, city_geoname_id: 0})
      ]
    )

    Page.goto!(page, "/#{domain}?period=all", wait_until: :commit)

    csvs = parse_all_csvs(trigger_export_and_await_download(page))

    for filename <-
          ~w(entry_pages.csv exit_pages.csv utm_mediums.csv utm_sources.csv utm_campaigns.csv utm_contents.csv utm_terms.csv countries.csv regions.csv cities.csv) do
      Test.step filename do
        assert csvs |> get_csv(filename) |> tl() |> length() == 1
      end
    end
  end

  # Returns %{filename => content}. Races the download against a `pageerror`, so a page error
  # fails fast.
  defp trigger_export_and_await_download(page) do
    Page.get_by_test_id(page, "dashboard-options-menu") |> Locator.click!()
    Page.get_by_text(page, "Export stats") |> Locator.wait_for!(state: :visible)

    race =
      Promise.race([
        Page.wait_for_event(page, :download),
        Page.wait_for_event(page, :page_error)
      ])

    Page.get_by_text(page, "Export stats") |> Locator.click!()
    result = Promise.await!(race)

    download =
      case result do
        %Download{} -> result
        error -> raise error
      end

    zip_path = Download.path!(download)
    if !zip_path, do: raise("Download path unavailable")

    {:ok, files} = :zip.unzip(String.to_charlist(zip_path), [:memory])
    Map.new(files, fn {name, data} -> {List.to_string(name), data} end)
  end
end
