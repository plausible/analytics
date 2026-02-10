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

    test "renders limits_reached_combined notification" do
      user = new_user()
      team = team_of(user)

      rendered =
        render_component(&Notice.usage_notification/1,
          type: :limits_reached_combined,
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

  describe "determine_notification_type/8" do
    test "returns :dashboard_locked when grace period has expired" do
      user = new_user() |> subscribe_to_growth_plan()
      team = team_of(user)

      expired_grace_period = %Plausible.Teams.GracePeriod{
        end_date: Date.add(Date.utc_today(), -1),
        is_over: false,
        manual_lock: false
      }

      team = %{team | grace_period: expired_grace_period}

      usage = %{
        current_cycle: %{total: 5000},
        last_cycle: %{total: 15000},
        penultimate_cycle: %{total: 14000}
      }

      assert Notice.determine_notification_type(team, usage, 10_000, 3, 10, 5, 10, nil) ==
               :dashboard_locked
    end

    test "returns :trial_ended when trial expired and no subscription" do
      user = new_user(trial_expiry_date: Date.add(Date.utc_today(), -5))
      team = team_of(user)

      usage = %{current_cycle: %{total: 5000}}

      assert Notice.determine_notification_type(team, usage, :unlimited, 3, 10, 5, 10, nil) ==
               :trial_ended
    end

    test "returns :traffic_exceeded_sustained when both last cycles exceeded" do
      user = new_user() |> subscribe_to_growth_plan()
      team = team_of(user)

      usage = %{
        current_cycle: %{total: 5000},
        last_cycle: %{total: 15000},
        penultimate_cycle: %{total: 14000}
      }

      assert Notice.determine_notification_type(team, usage, 10_000, 3, 10, 5, 10, team.subscription) ==
               :traffic_exceeded_sustained
    end

    test "returns :traffic_exceeded_last_cycle when only last cycle exceeded" do
      user = new_user() |> subscribe_to_growth_plan()
      team = team_of(user)

      usage = %{
        current_cycle: %{total: 5000},
        last_cycle: %{total: 15000},
        penultimate_cycle: %{total: 8000}
      }

      assert Notice.determine_notification_type(team, usage, 10_000, 3, 10, 5, 10, team.subscription) ==
               :traffic_exceeded_last_cycle
    end

    test "returns :pageview_approaching_limit when at 90% of limit" do
      user = new_user() |> subscribe_to_growth_plan()
      team = team_of(user)

      usage = %{
        current_cycle: %{total: 9000},
        last_cycle: %{total: 8000}
      }

      assert Notice.determine_notification_type(team, usage, 10_000, 3, 10, 5, 10, team.subscription) ==
               :pageview_approaching_limit
    end

    test "pageview notification takes precedence over site/member limits" do
      user = new_user() |> subscribe_to_growth_plan()
      team = team_of(user)

      usage = %{
        current_cycle: %{total: 9500}
      }

      # At limits for both sites and members, but pageview approaching takes precedence
      assert Notice.determine_notification_type(team, usage, 10_000, 10, 10, 10, 10, team.subscription) ==
               :pageview_approaching_limit
    end

    test "returns :limits_reached_combined when both site and member limits reached" do
      user = new_user() |> subscribe_to_growth_plan()
      team = team_of(user)

      usage = %{current_cycle: %{total: 5000}}

      assert Notice.determine_notification_type(team, usage, 10_000, 10, 10, 10, 10, team.subscription) ==
               :limits_reached_combined
    end

    test "returns :site_limit_reached when only site limit reached" do
      user = new_user() |> subscribe_to_growth_plan()
      team = team_of(user)

      usage = %{current_cycle: %{total: 5000}}

      assert Notice.determine_notification_type(team, usage, 10_000, 10, 10, 5, 10, team.subscription) ==
               :site_limit_reached
    end

    test "returns :team_member_limit_reached when only member limit reached" do
      user = new_user() |> subscribe_to_growth_plan()
      team = team_of(user)

      usage = %{current_cycle: %{total: 5000}}

      assert Notice.determine_notification_type(team, usage, 10_000, 5, 10, 10, 10, team.subscription) ==
               :team_member_limit_reached
    end

    test "returns nil when no notification is needed" do
      user = new_user() |> subscribe_to_growth_plan()
      team = team_of(user)

      usage = %{current_cycle: %{total: 5000}}

      assert Notice.determine_notification_type(
               team,
               usage,
               10_000,
               3,
               10,
               5,
               10,
               team.subscription
             ) ==
               nil
    end

    test "handles :unlimited limits correctly" do
      user = new_user() |> subscribe_to_growth_plan()
      team = team_of(user)

      usage = %{current_cycle: %{total: 50000}}

      # Should not trigger notifications for unlimited limits
      assert Notice.determine_notification_type(
               team,
               usage,
               :unlimited,
               100,
               :unlimited,
               100,
               :unlimited,
               team.subscription
             ) == nil
    end
  end
end
