defmodule PlausibleE2E.Dashboard.Segments do
  @moduledoc "The helpers at the top of segments.spec.ts."
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

defmodule PlausibleE2E.Dashboard.SegmentsSavingTest do
  use PlausibleE2E.Case, async: true

  import PlausibleE2E.Dashboard.Segments

  test "saving a segment", %{page: page, request: request} do
    %{domain: domain} = setup_site_and_stats(page, request)

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    Test.step "creating personal segment using defaults" do
      add_source_filter(page, "Facebook")

      Page.get_by_role(page, :link, name: "Save as segment") |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Create segment"))

      Expect.to_have_value!(
        modal(page) |> Locator.get_by_label("Segment name"),
        "Source is Facebook"
      )

      Expect.to_be_checked!(modal(page) |> Locator.get_by_role(:radio, name: "Personal segment"))

      modal(page) |> Locator.get_by_role(:button, name: "Save") |> Locator.click!()

      Expect.to_have_url!(page, ~r/f=is,segment,[0-9]+/)

      Expect.to_be_visible!(
        Page.get_by_role(page, :button, name: "Remove filter: Segment is Source is Facebook")
      )

      Page.get_by_role(page, :button, name: "Remove filter: Segment is Source is Facebook")
      |> Locator.click!()

      filter_button(page) |> Locator.click!()
      open_segments_submenu(page)

      Expect.to_be_visible!(segment_item_button(page, "Source is Facebook"))

      close_filter_menu(page)
    end

    Test.step "creating a personal segment with a custom name" do
      add_source_filter(page, "Google")

      Page.get_by_role(page, :link, name: "Save as segment") |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Create segment"))

      modal(page) |> Locator.get_by_label("Segment name") |> Locator.fill!("Traffic from Google")

      Expect.to_be_checked!(modal(page) |> Locator.get_by_role(:radio, name: "Personal segment"))

      modal(page) |> Locator.get_by_role(:button, name: "Save") |> Locator.click!()

      Expect.to_have_url!(page, ~r/f=is,segment,[0-9]+/)

      Expect.to_be_visible!(
        Page.get_by_role(page, :button, name: "Remove filter: Segment is Traffic from Google")
      )

      Page.get_by_role(page, :button, name: "Remove filter: Segment is Traffic from Google")
      |> Locator.click!()

      filter_button(page) |> Locator.click!()
      open_segments_submenu(page)

      Expect.to_be_visible!(segment_item_button(page, "Traffic from Google"))
      Expect.to_be_visible!(segment_item_button(page, "Source is Facebook"))

      close_filter_menu(page)
    end

    Test.step "creating a site segment from more than one filter" do
      add_source_filter(page, "Google")
      add_utm_source_filter(page, "Adwords")

      Page.get_by_role(page, :link, name: "Save as segment") |> Locator.click!()

      Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Create segment"))

      Expect.to_have_value!(
        modal(page) |> Locator.get_by_label("Segment name"),
        "UTM source is Adwords and Source is Google"
      )

      modal(page) |> Locator.get_by_label("Segment name") |> Locator.fill!("Ads from Google")

      site_segment_radio = modal(page) |> Locator.get_by_role(:radio, name: "Site segment")

      Locator.click!(site_segment_radio)

      Expect.to_be_checked!(site_segment_radio)

      modal(page) |> Locator.get_by_role(:button, name: "Save") |> Locator.click!()

      Expect.to_have_url!(page, ~r/f=is,segment,[0-9]+/)

      Expect.to_be_visible!(
        Page.get_by_role(page, :button, name: "Remove filter: Segment is Ads from Google")
      )

      Page.get_by_role(page, :button, name: "Remove filter: Segment is Ads from Google")
      |> Locator.click!()

      filter_button(page) |> Locator.click!()
      open_segments_submenu(page)

      Expect.to_be_visible!(segment_item_button(page, "Ads from Google"))
      Expect.to_be_visible!(segment_item_button(page, "Traffic from Google"))
      Expect.to_be_visible!(segment_item_button(page, "Source is Facebook"))

      close_filter_menu(page)
    end
  end
end

defmodule PlausibleE2E.Dashboard.SegmentsCombinationTest do
  use PlausibleE2E.Case, async: true

  import PlausibleE2E.Dashboard.Segments

  test "creating a segment from a combination of segment and a filter is not allowed", %{
    page: page,
    request: request
  } do
    %{domain: domain} = setup_site_and_stats(page, request)

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    add_source_filter(page, "Google")
    create_personal_segment(page, "Traffic from Google")
    add_utm_source_filter(page, "Adwords")

    Expect.to_be_visible!(filter_pill(page, "UTM source is Adwords"))

    Expect.to_be_visible!(
      Page.get_by_role(page, :button, name: "Remove filter: Segment is Traffic from Google")
    )

    Expect.to_have_url!(page, ~r/f=is,segment,[0-9]+/)
    Expect.to_have_url!(page, ~r/f=is,utm_source,Adwords/)

    Expect.to_be_hidden!(modal(page) |> Locator.get_by_role(:heading, name: "Create segment"))
  end
end

defmodule PlausibleE2E.Dashboard.SegmentsEditingTest do
  use PlausibleE2E.Case, async: true

  import PlausibleE2E.Dashboard.Segments

  test "editing an existing segment", %{page: page, request: request} do
    %{domain: domain} = setup_site_and_stats(page, request)

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    add_source_filter(page, "Google")
    create_personal_segment(page, "Traffic from Google")

    enter_edit_mode(page, "Traffic from Google")

    add_utm_source_filter(page, "Adwords")

    save_edited_segment_button(page) |> Locator.click!()

    Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Update segment"))

    Expect.to_have_value!(
      modal(page) |> Locator.get_by_label("Segment name"),
      "Traffic from Google"
    )

    modal(page) |> Locator.get_by_label("Segment name") |> Locator.fill!("Ads from Google")

    modal(page) |> Locator.get_by_role(:button, name: "Save") |> Locator.click!()

    Expect.to_be_visible!(
      Page.get_by_role(page, :button, name: "Remove filter: Segment is Ads from Google")
    )

    enter_edit_mode(page, "Ads from Google")

    Expect.to_be_visible!(filter_pill(page, "UTM source is Adwords"))
    Expect.to_be_visible!(filter_pill(page, "Source is Google"))

    Page.get_by_role(page, :link, name: "Cancel") |> Locator.click!()

    Page.get_by_role(page, :button, name: "Remove filter: Segment is Ads from Google")
    |> Locator.click!()

    Expect.not_to_have_url!(page, ~r/f=is,segment,[0-9]+/)

    filter_button(page) |> Locator.click!()
    open_segments_submenu(page)

    Expect.to_be_visible!(segment_item_button(page, "Ads from Google"))
    Expect.to_be_hidden!(segment_item_button(page, "Traffic from Google"))
  end
end

defmodule PlausibleE2E.Dashboard.SegmentsDuplicatingTest do
  use PlausibleE2E.Case, async: true

  import PlausibleE2E.Dashboard.Segments

  test "duplicating a segment", %{page: page, request: request} do
    %{domain: domain} = setup_site_and_stats(page, request)

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    add_source_filter(page, "Google")
    create_personal_segment(page, "Traffic from Google")

    open_segment_pill_menu(page, "Traffic from Google")

    Page.get_by_role(page, :button, name: "Duplicate segment") |> Locator.click!()

    Expect.to_be_visible!(modal(page) |> Locator.get_by_role(:heading, name: "Create segment"))

    Expect.to_have_value!(
      modal(page) |> Locator.get_by_label("Segment name"),
      "Copy of Traffic from Google"
    )

    modal(page) |> Locator.get_by_label("Segment name") |> Locator.fill!("Google copy")

    modal(page) |> Locator.get_by_role(:button, name: "Save") |> Locator.click!()

    enter_edit_mode(page, "Google copy")

    Expect.to_be_visible!(filter_pill(page, "Source is Google"))

    Page.get_by_role(page, :link, name: "Cancel") |> Locator.click!()

    Page.get_by_role(page, :button, name: "Remove filter: Segment is Google copy")
    |> Locator.click!()

    filter_button(page) |> Locator.click!()
    open_segments_submenu(page)

    Expect.to_be_visible!(segment_item_button(page, "Google copy"))
    Expect.to_be_visible!(segment_item_button(page, "Traffic from Google"))
  end
end

defmodule PlausibleE2E.Dashboard.SegmentsDeletingTest do
  use PlausibleE2E.Case, async: true

  import PlausibleE2E.Dashboard.Segments

  test "deleting segment", %{page: page, request: request} do
    %{domain: domain} = setup_site_and_stats(page, request)

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    add_source_filter(page, "Google")
    create_personal_segment(page, "Traffic from Google")

    open_segment_pill_menu(page, "Traffic from Google")

    Page.get_by_role(page, :button, name: "Delete segment") |> Locator.click!()

    Expect.to_be_visible!(
      modal(page)
      |> Locator.get_by_role(:heading, name: "Delete personal segment")
    )

    modal(page) |> Locator.get_by_role(:button, name: "Delete") |> Locator.click!()

    filter_button(page) |> Locator.click!()

    # The only segment is gone, so the filter menu no longer offers segments at all.
    Expect.to_be_hidden!(filter_item_button(page, "Segment"))
  end
end

defmodule PlausibleE2E.Dashboard.SegmentsCancellingTest do
  use PlausibleE2E.Case, async: true

  import PlausibleE2E.Dashboard.Segments

  test "cancelling edited segment without saving", %{page: page, request: request} do
    %{domain: domain} = setup_site_and_stats(page, request)

    Page.goto!(page, "/" <> domain, wait_until: :commit)

    add_source_filter(page, "Google")
    create_personal_segment(page, "Traffic from Google")

    enter_edit_mode(page, "Traffic from Google")

    add_utm_source_filter(page, "Adwords")

    Page.get_by_role(page, :link, name: "Cancel") |> Locator.click!()

    Expect.to_have_url!(page, ~r/f=is,segment,[0-9]+/)
    Expect.not_to_have_url!(page, ~r/f=is,utm_source,Adwords/)

    enter_edit_mode(page, "Traffic from Google")

    Expect.to_be_hidden!(filter_pill(page, "UTM source is Adwords"))
    Expect.to_be_visible!(filter_pill(page, "Source is Google"))
  end
end
