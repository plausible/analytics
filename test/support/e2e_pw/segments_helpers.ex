defmodule PlausibleE2E.Dashboard.Segments do
  @moduledoc "Helpers of segments.spec.ts."
  import PlausibleE2E.Fixtures
  import PlausibleE2E.Utils

  alias Playwright.{Expect, Locator, Page}

  def setup_site_and_stats(page, request) do
    context = setup_site(page: page, request: request)

    populate_stats(
      request: request,
      domain: context.domain,
      events: [
        %{
          name: "pageview",
          referrer_source: "Google",
          utm_source: "Adwords",
          utm_medium: "email",
          utm_campaign: "promo"
        },
        %{name: "pageview", referrer_source: "Facebook", utm_source: "fb"},
        %{name: "pageview", referrer: "https://theguardian.com"}
      ]
    )

    context
  end

  def open_segment_pill_menu(page, segment_name) do
    page
    |> Page.get_by_role(:button, name: "Open menu: Segment is #{segment_name}", exact: true)
    |> Locator.click!()
  end

  def save_edited_segment_button(page),
    do: Page.get_by_role(page, :button, name: "Save", exact: true)

  def enter_edit_mode(page, segment_name) do
    open_segment_pill_menu(page, segment_name)
    Page.get_by_role(page, :link, name: "Edit segment") |> Locator.click!()
    Expect.to_be_visible!(save_edited_segment_button(page))
  end

  def segment_item_button(page, name), do: filter_submenu_segment_item(page, name)

  def add_source_filter(page, source_label) do
    filter_button(page) |> Locator.click!()
    open_filter_submenu_item(page, "Source", "Source")

    pick_filter_value(page, value: source_label)
    close_filter_editor(page)

    Expect.to_have_url!(page, Regex.compile!("f=is,source,#{source_label}"))
  end

  def add_utm_source_filter(page, utm_source) do
    filter_button(page) |> Locator.click!()
    open_filter_submenu_item(page, "UTM tags", "UTM source")

    pick_filter_value(page, value: utm_source)
    close_filter_editor(page)

    Expect.to_have_url!(page, Regex.compile!("f=is,utm_source,#{utm_source}"))
  end

  def create_personal_segment(page, name) do
    Page.get_by_role(page, :link, name: "Save as segment") |> Locator.click!()

    modal(page) |> Locator.get_by_label("Segment name") |> Locator.fill!(name)

    modal(page) |> Locator.get_by_role(:button, name: "Save") |> Locator.click!()

    Expect.to_have_url!(page, ~r/f=is,segment,[0-9]+/)
  end
end
