defmodule PlausibleE2E.Dashboard.BreakdownsSourcesTest do
  use PlausibleE2E.Case, async: true

  test "sources breakdown", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{
          name: "pageview",
          referrer_source: "DuckDuckGo",
          referrer: "https://duckduckgo.com/a1",
          utm_medium: "paid"
        },
        %{
          name: "pageview",
          referrer_source: "DuckDuckGo",
          referrer: "https://duckduckgo.com/a2",
          click_id_param: "gclid"
        },
        %{name: "pageview", referrer_source: "Facebook", utm_source: "fb"},
        %{name: "pageview", referrer_source: "theguardian.com"},
        %{name: "pageview", referrer_source: "ablog.example.com"},
        %{
          name: "pageview",
          referrer_source: "Google",
          utm_medium: "SomeUTMMedium",
          utm_source: "SomeUTMSource",
          utm_campaign: "SomeUTMCampaign",
          utm_content: "SomeUTMContent",
          utm_term: "SomeUTMTerm"
        }
      ]
    )

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    report = Page.get_by_test_id(page, "report-sources")

    Test.step "sources tab" do
      sources_tab_button = tab_button(report, "Sources")
      report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()
      Expect.to_have_attribute!(sources_tab_button, "data-active", "true")

      expect_headers(report, ["Source", "Visitors"])

      expect_rows(report, [
        "DuckDuckGo",
        "Facebook",
        "Google",
        "ablog.example.com",
        "theguardian.com"
      ])

      expect_metric_values(report, "DuckDuckGo", ["2", "33.3%"])
      expect_metric_values(report, "Facebook", ["1", "16.7%"])
      expect_metric_values(report, "Google", ["1", "16.7%"])
      expect_metric_values(report, "ablog.example.com", ["1", "16.7%"])
      expect_metric_values(report, "theguardian.com", ["1", "16.7%"])
    end

    Test.step "sources modal" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Sources"))

      expect_headers(modal(page), ["Source", ~r/Visitors/, ~r/Bounce rate/, ~r/Visit duration/])

      expect_rows(modal(page), [
        "DuckDuckGo",
        "Facebook",
        "Google",
        "ablog.example.com",
        "theguardian.com"
      ])

      expect_metric_values(modal(page), "DuckDuckGo", ["2", "100%", "0s"])

      close_modal_button(page) |> Locator.click!()
    end

    Test.step "clicking sources entry shows referrers" do
      row_link(report, "DuckDuckGo") |> Locator.click!()
      Expect.to_have_url!(page, ~r/f=is,source,DuckDuckGo/)

      Expect.to_have_attribute!(tab_button(report, "Top referrers"), "data-active", "true")

      # Move mouse away from report rows
      tab_button(report, "Top referrers") |> Locator.hover!()

      expect_headers(report, ["Referrer", "Visitors"])

      expect_rows(report, ["https://duckduckgo.com/a1", "https://duckduckgo.com/a2"])
    end

    Test.step "referrers modal" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(
        modal(page)
        |> Locator.get_by_role(:heading, name: "Referrer drilldown")
      )

      expect_headers(modal(page), ["Referrer", ~r/Visitors/, ~r/Bounce rate/, ~r/Visit duration/])

      expect_rows(modal(page), ["https://duckduckgo.com/a1", "https://duckduckgo.com/a2"])

      close_modal_button(page) |> Locator.click!()

      Page.get_by_role(page, :button, name: "Remove filter: Source is DuckDuckGo")
      |> Locator.click!()
    end

    # Tests against values from Plausible.Google.API.Mock
    Test.step "clicking Google source entry opens search terms" do
      row_link(report, "Google") |> Locator.click!()
      Expect.to_have_url!(page, ~r/f=is,source,Google/)

      Expect.to_have_attribute!(tab_button(report, "Search terms"), "data-active", "true")

      # Move mouse away from report rows
      tab_button(report, "Search terms") |> Locator.hover!()

      expect_headers(report, ["Search term", "Visitors"])

      expect_metric_values(report, "simple web analytics", ["25"])
      expect_metric_values(report, "open-source analytics", ["15"])
    end

    Test.step "search-terms modal" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(
        modal(page)
        |> Locator.get_by_role(:heading, name: "Google search terms")
      )

      expect_headers(modal(page), ["Search term", "Visitors", "Impressions", "CTR", "Position"])

      close_modal_button(page) |> Locator.click!()
    end

    Page.get_by_role(page, :button, name: "Remove filter: Source is Google") |> Locator.click!()

    Test.step "channels tab" do
      channels_tab_button = tab_button(report, "Channels")
      Locator.click!(channels_tab_button)
      Expect.to_have_attribute!(channels_tab_button, "data-active", "true")

      expect_headers(report, ["Channel", "Visitors"])

      expect_rows(report, ["Organic Search", "Referral", "Organic Social", "Paid Search"])

      expect_metric_values(report, "Organic Search", ["2", "33.3%"])
      expect_metric_values(report, "Referral", ["2", "33.3%"])
      expect_metric_values(report, "Organic Social", ["1", "16.7%"])
      expect_metric_values(report, "Paid Search", ["1", "16.7%"])
    end

    Test.step "channels modal" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(
        modal(page)
        |> Locator.get_by_role(:heading, name: "Acquisition channels")
      )

      expect_headers(modal(page), ["Channel", ~r/Visitors/, ~r/Bounce rate/, ~r/Visit duration/])

      expect_rows(modal(page), ["Organic Search", "Referral", "Organic Social", "Paid Search"])

      expect_metric_values(modal(page), "Referral", ["2", "100%", "0s"])

      close_modal_button(page) |> Locator.click!()
    end

    Test.step "campaigns > UTM mediums tab" do
      tab_button(report, "Campaigns") |> Locator.click!()
      dropdown(report) |> Locator.get_by_role(:button, name: "UTM mediums") |> Locator.click!()

      Expect.to_have_attribute!(tab_button(report, "UTM mediums"), "data-active", "true")

      expect_headers(report, ["UTM medium", "Visitors"])

      expect_rows(report, ["SomeUTMMedium", "paid"])

      expect_metric_values(report, "SomeUTMMedium", ["1", "50%"])
      expect_metric_values(report, "paid", ["1", "50%"])
    end

    Test.step "UTM mediums modal" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "UTM mediums"))

      expect_headers(modal(page), [
        "UTM medium",
        ~r/Visitors/,
        ~r/Bounce rate/,
        ~r/Visit duration/
      ])

      expect_rows(modal(page), ["SomeUTMMedium", "paid"])

      expect_metric_values(modal(page), "SomeUTMMedium", ["1", "100%", "0s"])

      close_modal_button(page) |> Locator.click!()
    end

    Test.step "campaigns > UTM sources tab" do
      tab_button(report, "UTM mediums") |> Locator.click!()
      dropdown(report) |> Locator.get_by_role(:button, name: "UTM sources") |> Locator.click!()

      Expect.to_have_attribute!(tab_button(report, "UTM sources"), "data-active", "true")

      expect_headers(report, ["UTM source", "Visitors"])

      expect_rows(report, ["SomeUTMSource", "fb"])

      expect_metric_values(report, "SomeUTMSource", ["1", "50%"])
      expect_metric_values(report, "fb", ["1", "50%"])
    end

    Test.step "UTM sources modal" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "UTM sources"))

      expect_headers(modal(page), [
        "UTM source",
        ~r/Visitors/,
        ~r/Bounce rate/,
        ~r/Visit duration/
      ])

      expect_rows(modal(page), ["SomeUTMSource", "fb"])

      expect_metric_values(modal(page), "SomeUTMSource", ["1", "100%", "0s"])

      close_modal_button(page) |> Locator.click!()
    end

    Test.step "campaigns > UTM campaigns tab" do
      tab_button(report, "UTM sources") |> Locator.click!()
      dropdown(report) |> Locator.get_by_role(:button, name: "UTM campaigns") |> Locator.click!()

      Expect.to_have_attribute!(tab_button(report, "UTM campaigns"), "data-active", "true")

      expect_headers(report, ["UTM campaign", "Visitors"])

      expect_rows(report, ["SomeUTMCampaign"])

      expect_metric_values(report, "SomeUTMCampaign", ["1", "100%"])
    end

    Test.step "UTM campaigns modal" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "UTM campaigns"))

      expect_headers(modal(page), [
        "UTM campaign",
        ~r/Visitors/,
        ~r/Bounce rate/,
        ~r/Visit duration/
      ])

      expect_rows(modal(page), ["SomeUTMCampaign"])

      expect_metric_values(modal(page), "SomeUTMCampaign", ["1", "100%", "0s"])

      close_modal_button(page) |> Locator.click!()
    end

    Test.step "campaigns > UTM contents tab" do
      tab_button(report, "UTM campaigns") |> Locator.click!()
      dropdown(report) |> Locator.get_by_role(:button, name: "UTM contents") |> Locator.click!()

      Expect.to_have_attribute!(tab_button(report, "UTM contents"), "data-active", "true")

      expect_headers(report, ["UTM content", "Visitors"])

      expect_rows(report, ["SomeUTMContent"])

      expect_metric_values(report, "SomeUTMContent", ["1", "100%"])
    end

    Test.step "UTM contents modal" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "UTM contents"))

      expect_headers(modal(page), [
        "UTM content",
        ~r/Visitors/,
        ~r/Bounce rate/,
        ~r/Visit duration/
      ])

      expect_rows(modal(page), ["SomeUTMContent"])

      expect_metric_values(modal(page), "SomeUTMContent", ["1", "100%", "0s"])

      close_modal_button(page) |> Locator.click!()
    end

    Test.step "campaigns > UTM terms tab" do
      tab_button(report, "UTM contents") |> Locator.click!()
      dropdown(report) |> Locator.get_by_role(:button, name: "UTM terms") |> Locator.click!()

      Expect.to_have_attribute!(tab_button(report, "UTM terms"), "data-active", "true")

      expect_headers(report, ["UTM term", "Visitors"])

      expect_rows(report, ["SomeUTMTerm"])

      expect_metric_values(report, "SomeUTMTerm", ["1", "100%"])
    end

    Test.step "UTM terms modal" do
      details_link(report) |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "UTM terms"))

      expect_headers(modal(page), ["UTM term", ~r/Visitors/, ~r/Bounce rate/, ~r/Visit duration/])

      expect_rows(modal(page), ["SomeUTMTerm"])

      expect_metric_values(modal(page), "SomeUTMTerm", ["1", "100%", "0s"])

      close_modal_button(page) |> Locator.click!()
    end
  end
end

defmodule PlausibleE2E.Dashboard.BreakdownsSearchTermsTest do
  use PlausibleE2E.Case, async: true

  # Tests against values from Plausible.Google.API.Mock
  test "sources breakdown - search terms failure modes", %{page: page, request: request} do
    %{domain: domain} = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{name: "pageview", referrer_source: "Google", pathname: "/empty"},
        %{name: "pageview", referrer_source: "Google", pathname: "/unsupported-filters"},
        %{name: "pageview", referrer_source: "Google", pathname: "/not-configured"}
      ]
    )

    report = Page.get_by_test_id(page, "report-sources")
    search_terms_tab_button = tab_button(report, "Search terms")

    Test.step "empty" do
      Page.goto!(page, "/" <> domain <> "?f=is,source,Google&f=is,page,%2Fempty",
        wait_until: :commit
      )

      report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()
      Expect.to_have_attribute!(search_terms_tab_button, "data-active", "true")

      Expect.to_be_visible!(Locator.get_by_text(report, "No data yet"))
    end

    Test.step "unsupported filters" do
      Page.goto!(page, "/" <> domain <> "?f=is,source,Google&f=is,page,%2Funsupported-filters",
        wait_until: :commit
      )

      report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()
      Expect.to_have_attribute!(search_terms_tab_button, "data-active", "true")

      Expect.to_be_visible!(
        Locator.get_by_text(report, "Unable to fetch keyword data from Search Console")
      )

      Expect.to_be_visible!(
        Locator.get_by_text(report, "does not support the current set of filters")
      )
    end

    Test.step "not configured" do
      Page.goto!(page, "/" <> domain <> "?f=is,source,Google&f=is,page,%2Fnot-configured",
        wait_until: :commit
      )

      report |> Locator.get_by_test_id("report-end") |> Locator.scroll_into_view_if_needed!()
      Expect.to_have_attribute!(search_terms_tab_button, "data-active", "true")

      Expect.to_be_visible!(
        Locator.get_by_text(report, "The site is not connected to Google Search Keywords")
      )
    end
  end
end
