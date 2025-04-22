defmodule PlausibleWeb.Components.Billing.NoticeTest do
  use Plausible.DataCase
  use Plausible.Teams.Test
  import Phoenix.LiveViewTest, only: [render_component: 2]
  alias PlausibleWeb.Components.Billing.Notice

  test "premium_feature/1 does not render a notice when team is on trial" do
    me = new_user(trial_expiry_date: Date.utc_today())

    assert render_component(&Notice.premium_feature/1,
             current_role: :owner,
             current_team: team_of(me),
             feature_mod: Plausible.Billing.Feature.Props
           ) == ""
  end

  test "premium_feature/1 renders an upgrade link when user is the site owner and does not have access to the feature" do
    me = new_user() |> subscribe_to_growth_plan()
    team = team_of(me)

    rendered =
      render_component(&Notice.premium_feature/1,
        current_role: :owner,
        current_team: team,
        feature_mod: Plausible.Billing.Feature.Props
      )

    assert rendered =~ "This team does not have access to Custom Properties"
    assert rendered =~ "upgrade your subscription"
    assert rendered =~ "/billing/choose-plan"
  end

  test "premium_feature/1 renders an upgrade link when user is the billing role and does not have access to the feature" do
    me = new_user() |> subscribe_to_growth_plan()
    team = team_of(me)

    rendered =
      render_component(&Notice.premium_feature/1,
        current_role: :billing,
        current_team: team,
        feature_mod: Plausible.Billing.Feature.Props
      )

    assert rendered =~ "This team does not have access to Custom Properties"
    assert rendered =~ "upgrade your subscription"
    assert rendered =~ "/billing/choose-plan"
  end

  test "premium_feature/1 does not render an upgrade link when user is not the site owner" do
    me = new_user() |> subscribe_to_growth_plan()

    rendered =
      render_component(&Notice.premium_feature/1,
        current_role: :viewer,
        current_team: team_of(me),
        feature_mod: Plausible.Billing.Feature.Funnels
      )

    assert rendered =~ "This team does not have access to Funnels"
    assert rendered =~ "please reach out to the team owner to upgrade their subscription"
  end

  test "premium_feature/1 does not render a notice when the user has access to the feature" do
    me = new_user() |> subscribe_to_business_plan()

    rendered =
      render_component(&Notice.premium_feature/1,
        current_role: :owner,
        current_team: team_of(me),
        feature_mod: Plausible.Billing.Feature.Funnels
      )

    assert rendered == ""
  end

  test "premium_feature/1 for team-less account" do
    rendered =
      render_component(&Notice.premium_feature/1,
        current_role: nil,
        current_team: nil,
        feature_mod: Plausible.Billing.Feature.Funnels
      )

    assert rendered =~ "This account does not have access to Funnels"
    assert rendered =~ "upgrade your subscription"
  end

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
