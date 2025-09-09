defmodule Plausible.Workers.NotifyAnnualRenewalTest do
  use Plausible.DataCase, async: true
  use Bamboo.Test
  use Plausible.Teams.Test
  require Plausible.Billing.Subscription.Status
  alias Plausible.Workers.NotifyAnnualRenewal
  alias Plausible.Billing.Subscription

  setup [:create_user, :create_site]
  @monthly_plan "558018"
  @yearly_plan "572810"
  @v2_pricing_yearly_plan "653232"

  test "ignores user without subscription" do
    NotifyAnnualRenewal.perform(nil)

    assert_no_emails_delivered()
  end

  test "ignores user with monthly subscription", %{user: user} do
    subscribe_to_plan(user, @monthly_plan, next_bill_date: Date.shift(Date.utc_today(), day: 7))

    NotifyAnnualRenewal.perform(nil)

    assert_no_emails_delivered()
  end

  test "ignores user with yearly subscription that's not due for renewal in 7 days", %{user: user} do
    subscribe_to_plan(user, @yearly_plan, next_bill_date: Date.shift(Date.utc_today(), day: 10))

    NotifyAnnualRenewal.perform(nil)

    assert_no_emails_delivered()
  end

  test "ignores user with old yearly subscription that's been superseded by a newer one", %{
    user: user
  } do
    subscribe_to_plan(
      user,
      @yearly_plan,
      next_bill_date: Date.shift(Date.utc_today(), day: 5),
      inserted_at: NaiveDateTime.shift(NaiveDateTime.utc_now(), day: -1)
    )

    subscribe_to_plan(
      user,
      @yearly_plan,
      next_bill_date: Date.shift(Date.utc_today(), day: 30),
      inserted_at: NaiveDateTime.utc_now()
    )

    NotifyAnnualRenewal.perform(nil)

    assert_no_emails_delivered()
  end

  test "sends renewal notification to user whose subscription is due for renewal in 7 days", %{
    user: user
  } do
    subscribe_to_plan(
      user,
      @yearly_plan,
      next_bill_date: Date.shift(Date.utc_today(), day: 7)
    )

    team = team_of(user)
    billing_member = new_user()
    add_member(team, user: billing_member, role: :billing)

    NotifyAnnualRenewal.perform(nil)

    assert_email_delivered_with(
      to: [{user.name, user.email}],
      subject: "Your Plausible subscription is up for renewal"
    )

    assert_email_delivered_with(
      to: [{billing_member.name, billing_member.email}],
      subject: "Your Plausible subscription is up for renewal"
    )
  end

  test "sends renewal notification to user whose subscription is due for renewal in 2 days", %{
    user: user
  } do
    subscribe_to_plan(
      user,
      @yearly_plan,
      next_bill_date: Date.shift(Date.utc_today(), day: 2)
    )

    NotifyAnnualRenewal.perform(nil)

    assert_email_delivered_with(
      to: [{user.name, user.email}],
      subject: "Your Plausible subscription is up for renewal"
    )
  end

  test "does not send renewal notification multiple times", %{user: user} do
    subscribe_to_plan(user, @yearly_plan, next_bill_date: Date.shift(Date.utc_today(), day: 7))

    NotifyAnnualRenewal.perform(nil)

    assert_email_delivered_with(
      to: [{user.name, user.email}],
      subject: "Your Plausible subscription is up for renewal"
    )

    NotifyAnnualRenewal.perform(nil)

    assert_no_emails_delivered()
  end

  test "sends a renewal notification again a year after the previous one", %{user: user} do
    subscribe_to_plan(user, @yearly_plan, next_bill_date: Date.shift(Date.utc_today(), day: 7))

    Repo.insert_all("sent_renewal_notifications", [
      %{
        user_id: user.id,
        timestamp: Date.shift(Date.utc_today(), year: -1) |> NaiveDateTime.new!(~T[00:00:00])
      }
    ])

    NotifyAnnualRenewal.perform(nil)

    assert_email_delivered_with(
      to: [{user.name, user.email}],
      subject: "Your Plausible subscription is up for renewal"
    )
  end

  test "does not send multiple notifications on second year", %{user: user} do
    subscribe_to_plan(user, @yearly_plan, next_bill_date: Date.shift(Date.utc_today(), day: 7))

    Repo.insert_all("sent_renewal_notifications", [
      %{
        user_id: user.id,
        timestamp: Timex.shift(Date.utc_today(), years: -1) |> Timex.to_naive_datetime()
      }
    ])

    NotifyAnnualRenewal.perform(nil)

    assert_email_delivered_with(
      to: [{user.name, user.email}],
      subject: "Your Plausible subscription is up for renewal"
    )

    NotifyAnnualRenewal.perform(nil)

    assert_no_emails_delivered()
  end

  test "sends renewal notification to user on v2 yearly pricing plans", %{
    user: user
  } do
    subscribe_to_plan(user, @v2_pricing_yearly_plan,
      next_bill_date: Date.shift(Date.utc_today(), day: 7)
    )

    NotifyAnnualRenewal.perform(nil)

    assert_email_delivered_with(
      to: [{user.name, user.email}],
      subject: "Your Plausible subscription is up for renewal"
    )
  end

  describe "expiration" do
    test "if user subscription is 'deleted', notify them about expiration instead", %{user: user} do
      subscribe_to_plan(user, @yearly_plan,
        next_bill_date: Date.shift(Date.utc_today(), day: 7),
        status: Subscription.Status.deleted()
      )

      NotifyAnnualRenewal.perform(nil)

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Your Plausible subscription is about to expire"
      )
    end
  end
end
