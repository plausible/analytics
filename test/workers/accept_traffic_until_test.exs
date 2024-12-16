defmodule Plausible.Workers.AcceptTrafficUntilTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test
  use Bamboo.Test

  alias Plausible.Workers.AcceptTrafficUntil

  @moduletag :ee_only

  test "does not send any notifications when sites have no stats" do
    today = Date.utc_today()
    next_week = today |> Date.add(+7)
    tomorrow = today |> Date.add(+1)

    user1 = new_user(team: [accept_traffic_until: next_week])

    user2 = new_user(team: [accept_traffic_until: tomorrow])

    _site1 = new_site(owner: user1)

    _site2 = new_site(owner: user2)

    {:ok, 2} = AcceptTrafficUntil.perform(nil)

    refute_notifications(user1.email)
    refute_notifications(user2.email)
  end

  test "does not send any notifications when site has stats older than 2d" do
    today = Date.utc_today()
    next_week = today |> Date.add(+7)

    user = new_user(team: [accept_traffic_until: next_week])

    new_site(owner: user)
    |> populate_stats([build(:pageview, timestamp: Date.add(today, -3))])

    {:ok, 1} = AcceptTrafficUntil.perform(nil)

    refute_notifications(user.email)
  end

  test "does send notification when last stat is 2d old" do
    today = Date.utc_today()
    next_week = today |> Date.add(+7)

    user = new_user(team: [accept_traffic_until: next_week])

    new_site(owner: user)
    |> populate_stats([build(:pageview, timestamp: Date.add(today, -2))])

    {:ok, 1} = AcceptTrafficUntil.perform(nil)

    assert_weekly_notification(user.email)
  end

  test "tomorrow: sends one e-mail" do
    tomorrow = Date.utc_today() |> Date.add(+1)
    user = new_user(team: [accept_traffic_until: tomorrow])

    new_site(owner: user) |> populate_stats([build(:pageview)])

    {:ok, 1} = AcceptTrafficUntil.perform(nil)
    assert_final_notification(user.email)
  end

  test "next week: sends one e-mail" do
    next_week = Date.utc_today() |> Date.add(+7)
    user = new_user(team: [accept_traffic_until: next_week])

    new_site(owner: user) |> populate_stats([build(:pageview)])

    {:ok, 1} = AcceptTrafficUntil.perform(nil)
    assert_weekly_notification(user.email)
  end

  test "sends combined warnings in one shot" do
    today = Date.utc_today()
    next_week = today |> Date.add(+7)
    tomorrow = today |> Date.add(+1)
    in_8_days = today |> Date.add(+8)

    user1 = new_user(team: [accept_traffic_until: next_week])
    user2 = new_user(team: [accept_traffic_until: tomorrow])
    user3 = new_user(team: [accept_traffic_until: in_8_days], email: "nope@example.com")
    user4 = new_user(team: [accept_traffic_until: today], email: "nope2@example.com")

    new_site(owner: user1) |> populate_stats([build(:pageview)])
    new_site(owner: user2) |> populate_stats([build(:pageview)])
    new_site(owner: user3) |> populate_stats([build(:pageview)])
    new_site(owner: user4) |> populate_stats([build(:pageview)])

    {:ok, 2} = AcceptTrafficUntil.perform(nil)
    assert_weekly_notification(user1.email)
    assert_final_notification(user2.email)
    refute_notifications("nope@example.com")
    refute_notifications("nope2@example.com")
  end

  test "sends multiple notifications per recipient as the time passes" do
    today = Date.utc_today()
    email = "cycle@example.com"

    user =
      new_user(
        email: email,
        trial_expiry_date: Plausible.Teams.Team.trial_expiry()
      )

    team = team_of(user)

    site = new_site(owner: user)

    populate_stats(site, [
      build(:pageview, timestamp: today),
      build(:pageview, timestamp: Date.add(team.trial_expiry_date, 7)),
      build(:pageview, timestamp: Date.add(team.trial_expiry_date, 8)),
      build(:pageview, timestamp: Date.add(team.trial_expiry_date, 13))
    ])

    # today's worker is no-op
    {:ok, 0} = AcceptTrafficUntil.perform(nil, today)
    refute_notifications(email)

    # trial_expiry + 7 days worker => we'll stop counting next week
    {:ok, 1} = AcceptTrafficUntil.perform(nil, Date.add(team.trial_expiry_date, 7))
    assert_weekly_notification(email)

    # another call on the same day == no-op, e-mail already sent
    {:ok, 0} = AcceptTrafficUntil.perform(nil, Date.add(team.trial_expiry_date, 7))
    refute_notifications(email)

    # another call on another day == no-op, no notification type applies
    {:ok, 0} = AcceptTrafficUntil.perform(nil, Date.add(team.trial_expiry_date, 8))
    refute_notifications(email)

    # day before accept_stats_until (trial_expiry_date + 14 - 1)
    {:ok, 1} = AcceptTrafficUntil.perform(nil, Date.add(team.trial_expiry_date, 13))
    assert_final_notification(email)

    # another one on the day before accept_stats_until (trial_expiry_date + 14 - 1) == no-op
    {:ok, 0} = AcceptTrafficUntil.perform(nil, Date.add(team.trial_expiry_date, 13))
    refute_notifications(email)
  end

  defp assert_weekly_notification(email) when is_binary(email) do
    assert_email_delivered_with(
      html_body: ~r/Hey Jane,/,
      to: [nil: email],
      subject:
        PlausibleWeb.Email.approaching_accept_traffic_until(%{name: "", email: email}).subject
    )
  end

  defp assert_final_notification(email) when is_binary(email) do
    assert_email_delivered_with(
      html_body: ~r/Hey Jane,/,
      to: [nil: email],
      subject:
        PlausibleWeb.Email.approaching_accept_traffic_until_tomorrow(%{name: "", email: email}).subject
    )
  end

  defp refute_notifications(email) when is_binary(email) do
    refute_email_delivered_with(to: [nil: email])
  end
end
