defmodule PlausibleWeb.Components.Billing.NoticeTest do
  use Plausible.DataCase
  import Phoenix.LiveViewTest, only: [render_component: 2]
  alias PlausibleWeb.Components.Billing.Notice

  test "limit_exceeded/1 when user is on growth displays upgrade link" do
    user = new_user() |> subscribe_to_growth_plan()
    team = team_of(user)

    rendered =
      render_component(&Notice.limit_exceeded/1,
        current_user: user,
        current_team: team,
        limit: 10,
        resource: "users"
      )

    assert rendered =~ "This account is limited to 10 users. To increase this limit"
    assert rendered =~ "upgrade your subscription"
    assert rendered =~ "/billing/choose-plan"
  end

  test "limit_exceeded/1 prints resource in singular case when limit is 1" do
    user = new_user() |> subscribe_to_growth_plan()

    rendered =
      render_component(&Notice.limit_exceeded/1,
        current_user: user,
        current_team: team_of(user),
        limit: 1,
        resource: "users"
      )

    assert rendered =~ "This account is limited to a single user. To increase this limit"
    assert rendered =~ "upgrade your subscription"
    assert rendered =~ "/billing/choose-plan"
  end

  test "limit_exceeded/1 when current team role is non-owner" do
    user = new_user() |> subscribe_to_growth_plan()
    team = team_of(user) |> Plausible.Teams.complete_setup()
    editor = add_member(team, role: :editor)

    rendered =
      render_component(&Notice.limit_exceeded/1,
        current_user: editor,
        current_team: team,
        limit: 10,
        resource: "users"
      )

    assert rendered =~ "This team is limited to 10 users"
    assert rendered =~ "ask your team owner to upgrade their subscription"
  end

  @tag :ee_only
  test "limit_exceeded/1 when user is on trial displays upgrade link" do
    user = new_user(trial_expiry_date: Date.utc_today())

    rendered =
      render_component(&Notice.limit_exceeded/1,
        current_user: user,
        current_team: team_of(user),
        limit: 10,
        resource: "users"
      )

    assert rendered =~ "This account is limited to 10 users"
    assert rendered =~ "upgrade your subscription"
    assert rendered =~ "/billing/choose-plan"
  end

  @tag :ee_only
  test "limit_exceeded/1 when user is on an enterprise plan displays support email" do
    user = new_user() |> subscribe_to_enterprise_plan()

    rendered =
      render_component(&Notice.limit_exceeded/1,
        current_user: user,
        current_team: team_of(user),
        limit: 10,
        resource: "users"
      )

    assert rendered =~ "This account is limited to 10 users."

    assert rendered =~ "hello@plausible.io"
    assert rendered =~ "upgrade your subscription"
  end

  @tag :ee_only
  test "limit_exceeded/1 when user is on a business plan displays support email" do
    user = new_user() |> subscribe_to_business_plan()
    team = team_of(user)

    rendered =
      render_component(&Notice.limit_exceeded/1,
        current_user: user,
        current_team: team,
        limit: 10,
        resource: "users"
      )

    assert rendered =~ "This account is limited to 10 users."

    assert rendered =~ "hello@plausible.io"
    assert rendered =~ "upgrade your subscription"
  end
end
