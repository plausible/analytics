defmodule PlausibleE2E.Dashboard.TeamSetupEnterTest do
  use PlausibleE2E.Case, async: true

  test "submitting team name via Enter key does not crash", %{page: page, request: request} do
    setup_site(page: page, request: request)
    Page.goto!(page, "/team/setup", wait_until: :commit)

    expect_live_view_connected(page)

    Expect.to_be_visible!(Page.get_by_role(page, :button, name: "Create team"))

    name_input = Page.locator(page, ~s|input[name="team[name]"]|)

    Locator.clear!(name_input)
    Locator.fill!(name_input, "My New Team")

    # Enter submits the whole form directly (single phx-submit handler)
    Locator.press!(name_input, "Enter")

    Expect.to_have_url!(page, ~r/\/settings\/team\/general/)

    expect_live_view_connected(page)

    name_input2 = Page.locator(page, ~s|input[name="team[name]"]|)

    Expect.to_have_value!(name_input2, "My New Team")
  end
end

defmodule PlausibleE2E.Dashboard.TeamSetupAddAnotherTest do
  use PlausibleE2E.Case, async: true

  test "add another button shows the next row, and disappears once the row limit is reached", %{
    page: page,
    request: request
  } do
    setup_site(page: page, request: request)
    Page.goto!(page, "/team/setup", wait_until: :commit)

    expect_live_view_connected(page)

    add_another = Page.get_by_role(page, :button, name: "Add another")
    visible_rows = Page.locator(page, "#member-rows > div:not(.hidden)")
    # 10 is the team member limit for a trial account
    max_rows = 10

    Expect.to_be_visible!(add_another)
    Expect.to_have_count!(Page.locator(page, "#member-rows > div"), max_rows)

    Locator.click!(add_another)

    Expect.to_be_focused!(
      Page.locator(page, ~s|#member-rows > div:nth-child(2) input[type="email"]|)
    )

    # one row already exists by default, one more was just added above
    for _ <- 2..(max_rows - 1)//1 do
      Locator.click!(add_another)
    end

    Expect.to_have_count!(visible_rows, max_rows)
    Expect.to_be_hidden!(add_another)
  end
end

defmodule PlausibleE2E.Dashboard.TeamSetupRowsTest do
  use PlausibleE2E.Case, async: true

  test "removing and re-adding a row", %{page: page, request: request} do
    setup_site(page: page, request: request)
    # A growth plan with a team member limit of 3
    subscribe_to_plan(page: page, plan_id: "857097")

    Page.goto!(page, "/team/setup", wait_until: :commit)

    expect_live_view_connected(page)

    add_another = Page.get_by_role(page, :button, name: "Add another")
    visible_rows = Page.locator(page, "#member-rows > div:not(.hidden)")

    row1 = Page.locator(page, "#member-row-1")
    row2 = Page.locator(page, "#member-row-2")
    row3 = Page.locator(page, "#member-row-3")
    email = fn row -> Locator.locator(row, ~s|input[type="email"]|) end

    email.(row1) |> Locator.fill!("row1@example.com")
    row1 |> Locator.get_by_role(:button, name: "Role") |> Locator.click!()
    row1 |> Locator.get_by_role(:option, name: "Admin") |> Locator.click!()

    Locator.click!(add_another)
    email.(row2) |> Locator.fill!("row2@example.com")
    row2 |> Locator.get_by_role(:button, name: "Role") |> Locator.click!()
    row2 |> Locator.get_by_role(:option, name: "Editor") |> Locator.click!()

    Locator.click!(add_another)
    email.(row3) |> Locator.fill!("row3@example.com")
    row3 |> Locator.get_by_role(:button, name: "Role") |> Locator.click!()
    row3 |> Locator.get_by_role(:option, name: "Billing") |> Locator.click!()

    row2 |> Locator.get_by_role(:button, name: "Remove row") |> Locator.click!()

    Expect.to_have_count!(visible_rows, 2)
    Expect.to_be_hidden!(row2)

    Expect.to_have_value!(email.(row1), "row1@example.com")
    Expect.to_have_text!(Locator.get_by_test_id(row1, "role"), "Admin")

    Expect.to_have_value!(email.(row3), "row3@example.com")
    Expect.to_have_text!(Locator.get_by_test_id(row3, "role"), "Billing")

    Locator.click!(add_another)

    Expect.to_have_count!(visible_rows, 3)
    Expect.to_have_attribute!(Locator.nth(visible_rows, 2), "id", "member-row-2")

    Expect.to_have_value!(email.(row2), "")
    Expect.to_have_text!(Locator.get_by_test_id(row2, "role"), "Viewer")
  end
end

defmodule PlausibleE2E.Dashboard.TeamSetupOnboardingAfterSiteTest do
  use PlausibleE2E.Case, async: true

  import PlausibleE2E.Dashboard.TeamSetup

  test "team created during onboarding after adding a site stays the current team", %{
    page: page,
    request: request
  } do
    user = new_user()
    team_name = "Onboarded team #{random_id()}"

    register(page: page, request: request, user: user)

    Page.get_by_label(page, "Domain") |> Locator.fill!("#{random_id()}.example.com")
    Page.get_by_role(page, :button, name: "Add site") |> Locator.click!()

    create_team_in_onboarding(page, team_name)

    Expect.to_have_url!(page, ~r/\/installation\?flow=register&__team=/)

    # without the `__team` param
    expect_current_team_on_sites_page(page, team_name)

    # with a fresh session
    logout(page)
    login(page: page, user: user)
    expect_current_team_on_sites_page(page, team_name)
  end
end

defmodule PlausibleE2E.Dashboard.TeamSetupOnboardingSkipTest do
  use PlausibleE2E.Case, async: true

  import PlausibleE2E.Dashboard.TeamSetup

  test "team created during onboarding after skipping adding a site stays the current team", %{
    page: page,
    request: request
  } do
    user = new_user()
    team_name = "Onboarded team #{random_id()}"

    register(page: page, request: request, user: user)

    Page.get_by_role(page, :link, name: "Skip") |> Locator.click!()

    create_team_in_onboarding(page, team_name)

    Expect.to_have_url!(page, ~r/\/sites\?__team=/)

    # without the `__team` param
    expect_current_team_on_sites_page(page, team_name)

    # with a fresh session
    logout(page)
    login(page: page, user: user)
    expect_current_team_on_sites_page(page, team_name)
  end
end
