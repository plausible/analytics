defmodule PlausibleE2E.Dashboard.FilteringAcquisitionTest do
  use PlausibleE2E.Case, async: true

  describe "hostname filtering tests" do
    defp hostname_filter_button(page), do: filter_item_button(page, "Hostname")

    test "filtering by hostname", %{page: page, request: request} do
      %{domain: domain} = setup_site(page: page, request: request)

      populate_stats(
        request: request,
        domain: domain,
        events: [
          %{name: "pageview", hostname: "one.example.com"},
          %{name: "pageview", hostname: "two.example.com"}
        ]
      )

      Page.goto!(page, "/" <> domain, wait_until: :commit)

      Locator.click!(filter_button(page))
      Locator.click!(hostname_filter_button(page))

      pick_filter_value(page, search: "one", value: "one.example.com")
      close_filter_editor(page)

      Expect.to_be_visible!(filter_pill(page, "Hostname is one.example.com"))

      Expect.to_have_url!(page, ~r/f=is,hostname,one.example.com/)
    end
  end

  describe "acquisition filtering tests" do
    defp open_source_filter(page, item), do: open_filter_submenu_item(page, "Source", item)

    test "filtering by source information", %{page: page, request: request} do
      %{domain: domain} = setup_site(page: page, request: request)

      populate_stats(
        request: request,
        domain: domain,
        events: [
          %{name: "pageview", referrer_source: "Google", utm_source: "Adwords"},
          %{name: "pageview", referrer_source: "Facebook", utm_source: "fb"},
          %{name: "pageview", referrer: "https://theguardian.com"}
        ]
      )

      Page.goto!(page, "/" <> domain, wait_until: :commit)

      Test.step "filtering by source" do
        Locator.click!(filter_button(page))
        open_source_filter(page, "Source")

        pick_filter_value(page, search: "goog", value: "Google")
        close_filter_editor(page)

        Expect.to_be_visible!(filter_pill(page, "Source is Google"))

        Expect.to_have_url!(page, ~r/f=is,source,Google/)

        Page.get_by_role(page, :button, name: "Remove filter: Source is Google")
        |> Locator.click!()

        Expect.not_to_have_url!(page, ~r/f=is,source,Google/)
      end

      Test.step "filtering by channel" do
        Locator.click!(filter_button(page))
        open_source_filter(page, "Channel")

        pick_filter_value(page, search: "paid", value: "Paid Search")
        close_filter_editor(page)

        Expect.to_be_visible!(filter_pill(page, "Channel is Paid Search"))

        Expect.to_have_url!(page, ~r/f=is,channel,Paid%20Search/)

        Page.get_by_role(page, :button, name: "Remove filter: Channel is Paid Search")
        |> Locator.click!()

        Expect.not_to_have_url!(page, ~r/f=is,channel,Paid%20Search/)
      end

      Test.step "filtering by referrer URL" do
        Locator.click!(filter_button(page))
        open_source_filter(page, "Referrer URL")

        pick_filter_value(page, search: "guard", value: "https://theguardian.com")
        close_filter_editor(page)

        Expect.to_be_visible!(filter_pill(page, "Referrer URL is https://theguardian.com"))

        Expect.to_have_url!(page, ~r|f=is,referrer,https://theguardian\.com|)

        Page.get_by_role(page, :button,
          name: "Remove filter: Referrer URL is https://theguardian.com"
        )
        |> Locator.click!()

        Expect.not_to_have_url!(page, ~r|f=is,referrer,https://theguardian\.com|)
      end
    end

    defp open_utm_filter(page, item), do: open_filter_submenu_item(page, "UTM tags", item)

    test "filtering by UTM tags", %{page: page, request: request} do
      %{domain: domain} = setup_site(page: page, request: request)

      populate_stats(
        request: request,
        domain: domain,
        events: [
          %{name: "pageview", utm_medium: "social"},
          %{name: "pageview", utm_source: "producthunt"},
          %{name: "pageview", utm_campaign: "ads"},
          %{name: "pageview", utm_term: "post"},
          %{name: "pageview", utm_content: "website"}
        ]
      )

      Page.goto!(page, "/" <> domain, wait_until: :commit)

      utm_steps = [
        %{item: "UTM medium", key: "utm_medium", search: "soc", value: "social"},
        %{item: "UTM source", key: "utm_source", search: "hunt", value: "producthunt"},
        %{item: "UTM campaign", key: "utm_campaign", search: "ads", value: "ads"},
        %{item: "UTM term", key: "utm_term", search: "pos", value: "post"},
        %{item: "UTM content", key: "utm_content", search: "web", value: "website"}
      ]

      for %{item: item, key: key, search: search, value: value} <- utm_steps do
        Test.step "filtering by #{item}" do
          pill_name = "#{item} is #{value}"
          url = Regex.compile!("f=is,#{key},#{value}")

          Locator.click!(filter_button(page))
          open_utm_filter(page, item)

          pick_filter_value(page, search: search, value: value)
          close_filter_editor(page)

          Expect.to_be_visible!(filter_pill(page, pill_name))

          Expect.to_have_url!(page, url)

          Page.get_by_role(page, :button, name: "Remove filter: #{pill_name}") |> Locator.click!()

          Expect.not_to_have_url!(page, url)
        end
      end
    end
  end
end
