defmodule PlausibleE2E.Dashboard.AnnotationsTest do
  use PlausibleE2E.Case, async: true, locale: "en-GB"

  test "user can create annotations across granularities, edit, and delete them", %{
    page: page,
    request: request
  } do
    user = %{
      email: "site-owner-for-annotations-#{random_id()}@example.com",
      # name matters in this test
      name: "J R.R. Smith",
      password: "VeryStrongVerySecret"
    }

    register(page: page, request: request, user: user)
    %{domain: domain} = setup_site(page: page, request: request, user: user)

    populate_stats(
      request: request,
      domain: domain,
      events: [
        %{user_id: 0, name: "pageview", pathname: "/", timestamp: "2026-04-01 00:00:00"},
        %{user_id: 1, name: "pageview", pathname: "/", timestamp: "2026-06-29 05:00:00"},
        %{user_id: 2, name: "pageview", pathname: "/", timestamp: "2026-06-29 10:00:00"}
      ]
    )

    Page.goto!(page, "/#{domain}?period=7d&date=2026-07-06&comparison=off", wait_until: :commit)

    monday_in_7d = Page.get_by_test_id(page, "graph-dot-series-1-bucket-0")
    monday_marker_7d = Page.get_by_test_id(page, "annotation-marker-on-bucket-0")

    tooltip = Page.get_by_test_id(page, "graph-tooltip")

    # inputs in create / edit modals
    note_field = Page.get_by_role(page, :textbox, name: "Note")
    save_button = Page.get_by_role(page, :button, name: "Save")

    site_note_text = "Company-wide: launch day"
    personal_note_text = "Feature available for 50% of customers"
    updated_note_text = "Feature fully released (correction)"

    personal_note_attribution = "Personal note • 29 Jun 10:00"
    site_note_attribution = "#{user.name} • 29 Jun"
    # when all annotations in a bucket are exactly for the date (& time) of the bucket
    # the attribution is shortened because it's unambiguous
    site_note_attribution_unambiguous = "#{user.name}"
    personal_note_attribution_unambiguous = "Personal note"

    # Asserts the tooltip's annotation list matches provided list exactly
    expect_tooltip_annotations = fn expected ->
      rows = Locator.locator(tooltip, "div.group")
      Expect.to_have_count!(rows, length(expected))

      for {{note, attribution}, i} <- Enum.with_index(expected) do
        row = Locator.nth(rows, i)
        Expect.to_contain_text!(row, note)

        row
        |> Locator.get_by_test_id("annotation-attribution")
        |> Expect.to_have_text!(attribution)
      end
    end

    # Needed because the tests expect a particular graph interval
    set_graph_interval = fn label ->
      Page.get_by_test_id(page, "dashboard-options-menu") |> Locator.click!()
      Page.get_by_role(page, :button, name: label, exact: true) |> Locator.click!()
      Keyboard.press!(Page.keyboard(page), "Escape")
    end

    Test.step "in 7d view, create date-granularity site annotation on Monday" do
      set_graph_interval.("Days")

      # hovered tooltip
      Locator.hover!(monday_in_7d)
      Expect.to_be_visible!(tooltip)
      expect_tooltip_annotations.([])

      Expect.to_contain_text!(tooltip, "Click to view day")
      Expect.to_contain_text!(tooltip, "Right click for more actions")

      # persisted tooltip
      Locator.click!(monday_in_7d, button: :right)
      Expect.to_be_visible!(tooltip)

      tooltip |> Locator.locator("button") |> Expect.to_contain_text!(["Add note", "View day"])
      tooltip |> Locator.get_by_role(:button, name: "Add note") |> Locator.click!()

      create_modal_heading =
        Page.get_by_role(page, :heading, name: "Add note for Mon, 29 Jun", exact: true)

      Expect.to_be_visible!(create_modal_heading)

      Locator.fill!(note_field, site_note_text)
      Page.get_by_role(page, :radio, name: ~r/Site note/) |> Locator.check!()
      Locator.click!(save_button)

      Expect.to_be_hidden!(create_modal_heading)
      Expect.to_be_visible!(monday_marker_7d)
    end

    Test.step ~s|right-click Monday and zoom in via "View day"| do
      Locator.hover!(monday_in_7d)

      expect_tooltip_annotations.([{site_note_text, site_note_attribution_unambiguous}])

      Locator.click!(monday_in_7d, button: :right)

      tooltip |> Locator.get_by_role(:button, name: "View day") |> Locator.click!()
      Expect.to_have_url!(page, ~r/period=day&date=2026-06-29/)

      # Date-granularity annotations don't map to hour buckets — no marker in day view.
      Expect.to_have_count!(Page.get_by_test_id(page, ~r/^annotation-marker-on-bucket-/), 0)
    end

    Test.step "in day view, create minute-granularity personal annotation at 10:00" do
      set_graph_interval.("Hours")

      hour10_in_day = Page.get_by_test_id(page, "graph-dot-series-1-bucket-10")
      Locator.hover!(hour10_in_day)
      Locator.click!(hour10_in_day, button: :right)
      Expect.to_be_visible!(tooltip)

      tooltip |> Locator.get_by_role(:button, name: "Add note") |> Locator.click!()

      create_modal_heading =
        Page.get_by_role(page, :heading, name: "Add note for Mon, 29 Jun at 10:00", exact: true)

      Expect.to_be_visible!(create_modal_heading)
      Expect.to_be_hidden!(tooltip)

      Locator.fill!(note_field, personal_note_text)
      Locator.click!(save_button)

      Expect.to_be_hidden!(create_modal_heading)
      Expect.to_be_visible!(Page.get_by_test_id(page, "annotation-marker-on-bucket-10"))
    end

    Test.step "in day view, hovering the 10:00 bucket with the single note omits the duplicative datetime label from the note" do
      hour10_in_day = Page.get_by_test_id(page, "graph-dot-series-1-bucket-10")
      Locator.hover!(hour10_in_day)
      Expect.to_be_visible!(tooltip)

      expect_tooltip_annotations.([{personal_note_text, personal_note_attribution_unambiguous}])
    end

    Test.step "zoom back out to 7d, both annotations are visible on Monday" do
      Page.go_back!(page, wait_until: :commit)
      set_graph_interval.("Days")

      Expect.to_be_visible!(monday_marker_7d)

      expected_on_monday = [
        {site_note_text, site_note_attribution},
        {personal_note_text, personal_note_attribution}
      ]

      Locator.hover!(monday_in_7d)
      Expect.to_be_visible!(tooltip)
      expect_tooltip_annotations.(expected_on_monday)

      Locator.click!(monday_in_7d, button: :right)
      Expect.to_be_visible!(tooltip)
      expect_tooltip_annotations.(expected_on_monday)
    end

    Test.step "edit personal annotation" do
      personal_row = Locator.locator(tooltip, "div.group", has_text: personal_note_text)
      Locator.hover!(personal_row)
      personal_row |> Locator.get_by_role(:button, name: "Edit note") |> Locator.click!()

      update_modal_heading =
        Page.get_by_role(page, :heading,
          name: "Update note for Mon, 29 Jun at 10:00",
          exact: true
        )

      Expect.to_be_visible!(update_modal_heading)
      Expect.to_be_hidden!(tooltip)
      Expect.to_have_value!(note_field, personal_note_text)

      Locator.fill!(note_field, updated_note_text)
      Locator.click!(save_button)

      Expect.to_be_hidden!(update_modal_heading)

      Locator.hover!(monday_in_7d)
      Locator.click!(monday_in_7d, button: :right)

      expect_tooltip_annotations.([
        {site_note_text, site_note_attribution},
        {updated_note_text, personal_note_attribution}
      ])
    end

    Test.step "delete personal annotation" do
      personal_note = Locator.locator(tooltip, "div.group", has_text: updated_note_text)
      Locator.hover!(personal_note)
      personal_note |> Locator.get_by_role(:button, name: "Edit note") |> Locator.click!()

      update_modal_heading =
        Page.get_by_role(page, :heading,
          name: "Update note for Mon, 29 Jun at 10:00",
          exact: true
        )

      Expect.to_be_visible!(update_modal_heading)

      Page.get_by_role(page, :button, name: "Delete note") |> Locator.click!()

      delete_modal_heading =
        Page.get_by_role(page, :heading,
          name: ~s|Delete personal note "#{updated_note_text}"?|,
          exact: true
        )

      Expect.to_be_visible!(delete_modal_heading)
      Expect.to_be_hidden!(update_modal_heading)

      Page.get_by_role(page, :button, name: "Delete", exact: true) |> Locator.click!()

      Expect.to_be_hidden!(delete_modal_heading)
      Locator.hover!(monday_in_7d)
      expect_tooltip_annotations.([{site_note_text, site_note_attribution_unambiguous}])
      Expect.to_be_visible!(monday_marker_7d)
    end

    Test.step "date annotations are shown for All period" do
      Page.get_by_test_id(page, "current-query-period") |> Locator.click!()

      page
      |> Page.get_by_test_id("query-period-picker")
      |> Locator.get_by_role(:link, name: "All time")
      |> Locator.click!()

      Expect.to_have_url!(page, ~r/period=all/)

      marker = Page.get_by_test_id(page, ~r/^annotation-marker-on-bucket-/)
      Expect.to_have_count!(marker, 1)
      Expect.to_be_visible!(marker)

      set_graph_interval.("Months")
      Page.get_by_text(page, "June 2026", exact: true) |> Locator.hover!()
      expect_tooltip_annotations.([{site_note_text, site_note_attribution}])
    end
  end
end
