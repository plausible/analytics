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

  describe "usage_notification/1" do
    test "renders pageview_approaching_limit notification" do
      user = new_user()
      team = team_of(user)

      rendered =
        render_component(&Notice.usage_notification/1,
          type: :pageview_approaching_limit,
          team: team
        )

      assert rendered =~ "close to your monthly pageview limit"
      assert rendered =~ "Occasional traffic spikes are normal"
      assert rendered =~ "Upgrade"
      assert rendered =~ "Learn more"
    end

    test "renders team_member_limit_reached notification" do
      user = new_user()
      team = team_of(user)

      rendered =
        render_component(&Notice.usage_notification/1,
          type: :team_member_limit_reached,
          team: team
        )

      assert rendered =~ "reached your current team member limit"
      assert rendered =~ "Upgrade"
    end

    test "renders site_limit_reached notification" do
      user = new_user()
      team = team_of(user)

      rendered =
        render_component(&Notice.usage_notification/1,
          type: :site_limit_reached,
          team: team
        )

      assert rendered =~ "reached your current site limit"
      assert rendered =~ "Upgrade"
    end

    test "renders site_and_team_member_limit_reached notification" do
      user = new_user()
      team = team_of(user)

      rendered =
        render_component(&Notice.usage_notification/1,
          type: :site_and_team_member_limit_reached,
          team: team
        )

      assert rendered =~ "reached your current limits for team members and sites"
      assert rendered =~ "Upgrade"
    end

    test "renders traffic_exceeded_last_cycle notification" do
      user = new_user()
      team = team_of(user)

      rendered =
        render_component(&Notice.usage_notification/1,
          type: :traffic_exceeded_last_cycle,
          team: team
        )

      assert rendered =~ "Traffic exceeded plan limit last cycle"
      assert rendered =~ "Occasional traffic spikes are normal"
      assert rendered =~ "Upgrade"
      assert rendered =~ "Learn more"
    end

    test "renders traffic_exceeded_sustained notification" do
      user = new_user()
      team = team_of(user)

      rendered =
        render_component(&Notice.usage_notification/1,
          type: :traffic_exceeded_sustained,
          team: team
        )

      assert rendered =~ "Upgrade required due to sustained higher traffic"
      assert rendered =~ "within the next 7 days"
      assert rendered =~ "Upgrade"
      assert rendered =~ "Learn more"
    end

    test "renders dashboard_locked notification" do
      user = new_user()
      team = team_of(user)

      rendered =
        render_component(&Notice.usage_notification/1,
          type: :dashboard_locked,
          team: team
        )

      assert rendered =~ "Dashboard access temporarily locked"
      assert rendered =~ "stats are still being tracked"
      assert rendered =~ "Upgrade"
      assert rendered =~ "Learn more"
    end

    test "renders trial_ended notification" do
      user = new_user()
      team = team_of(user)

      rendered =
        render_component(&Notice.usage_notification/1,
          type: :trial_ended,
          team: team
        )

      assert rendered =~ "Your free trial has ended"
      assert rendered =~ "Choose a plan"
    end

    test "renders nothing for unknown notification type" do
      user = new_user()
      team = team_of(user)

      rendered =
        render_component(&Notice.usage_notification/1,
          type: :unknown_type,
          team: team
        )

      assert rendered == ""
    end
  end
end
