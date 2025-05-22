defmodule PlausibleWeb.Components.Billing.NoticeTest do
  use Plausible.DataCase
  use Plausible.Teams.Test
  import Phoenix.LiveViewTest, only: [render_component: 2]
  alias PlausibleWeb.Components.Billing.Notice

  test "limit_exceeded/1 when team is on growth displays upgrade link" do
    me = new_user() |> subscribe_to_growth_plan()
    team = team_of(me)

    rendered =
      render_component(&Notice.limit_exceeded/1,
        current_role: :owner,
        current_team: team,
        limit: 10,
        resource: "users"
      )

    assert rendered =~ "This team is limited to 10 users. To increase this limit"
    assert rendered =~ "upgrade your subscription"
    assert rendered =~ "/billing/choose-plan"
  end

  test "limit_exceeded/1 when current role is non-owner" do
    me = new_user() |> subscribe_to_growth_plan()

    rendered =
      render_component(&Notice.limit_exceeded/1,
        current_role: :editor,
        current_team: team_of(me),
        limit: 10,
        resource: "users"
      )

    assert rendered =~ "This team is limited to 10 users"
    assert rendered =~ "please reach out to the team owner to upgrade their subscription"
  end

  @tag :ee_only
  test "limit_exceeded/1 when team is on trial displays upgrade link" do
    me = new_user(trial_expiry_date: Date.utc_today())

    rendered =
      render_component(&Notice.limit_exceeded/1,
        current_role: :owner,
        current_team: team_of(me),
        limit: 10,
        resource: "users"
      )

    assert rendered =~ "This team is limited to 10 users"
    assert rendered =~ "upgrade your subscription"
    assert rendered =~ "/billing/choose-plan"
  end

  @tag :ee_only
  test "limit_exceeded/1 when team is on an enterprise plan displays support email" do
    me = new_user() |> subscribe_to_enterprise_plan()

    rendered =
      render_component(&Notice.limit_exceeded/1,
        current_role: :owner,
        current_team: team_of(me),
        limit: 10,
        resource: "users"
      )

    assert rendered =~ "This team is limited to 10 users."

    assert rendered =~ "hello@plausible.io"
    assert rendered =~ "upgrade your subscription"
  end

  @tag :ee_only
  test "limit_exceeded/1 when team is on a business plan displays support email" do
    me = new_user() |> subscribe_to_business_plan()
    team = team_of(me)

    rendered =
      render_component(&Notice.limit_exceeded/1,
        current_role: :owner,
        current_team: team,
        limit: 10,
        resource: "users"
      )

    assert rendered =~ "This team is limited to 10 users."

    assert rendered =~ "hello@plausible.io"
    assert rendered =~ "upgrade your subscription"
  end
end
