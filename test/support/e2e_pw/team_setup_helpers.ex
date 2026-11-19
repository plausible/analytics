defmodule PlausibleE2E.Dashboard.TeamSetup do
  @moduledoc "Helpers of team-setup.spec.ts."
  import PlausibleE2E.Utils

  alias Playwright.{Expect, Locator, Page}

  def new_user do
    user_id = random_id()

    %{
      name: "User #{user_id}",
      email: "email-#{user_id}@example.com",
      password: "VeryStrongVerySecret"
    }
  end

  def create_team_in_onboarding(page, team_name) do
    Expect.to_have_url!(page, ~r/\/team\/setup\?flow=register/)
    expect_live_view_connected(page)

    name_input = Page.locator(page, ~s|input[name="team[name]"]|)
    Locator.clear!(name_input)
    Locator.fill!(name_input, team_name)

    Page.get_by_role(page, :button, name: "Create team") |> Locator.click!()
  end

  def expect_current_team_on_sites_page(page, team_name) do
    Page.goto!(page, "/sites", wait_until: :commit)
    expect_live_view_connected(page)

    Expect.to_have_text!(Page.get_by_role(page, :heading, level: 2), team_name)
  end
end
