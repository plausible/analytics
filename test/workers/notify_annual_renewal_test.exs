defmodule Plausible.Workers.NotifyAnnualRenewalTest do
  use Plausible.DataCase
  use Bamboo.Test
  import Plausible.TestUtils
  alias Plausible.Workers.NotifyAnnualRenewal
  alias Plausible.Billing.Plans

  setup [:create_user, :create_site]
  @monthly_plan Plans.plans()[:monthly][:"10k"][:product_id]
  @yearly_plan Plans.plans()[:yearly][:"10k"][:product_id]
  @renewal_date ~D[2021-05-10]

  test "ignores user without subscription" do
    NotifyAnnualRenewal.perform(nil, nil)

    assert_no_emails_delivered()
  end

  test "ignores user with monthly subscription", %{user: user} do
    insert(:subscription,
      user: user,
      paddle_plan_id: @monthly_plan
    )

    NotifyAnnualRenewal.perform(nil, nil)

    assert_no_emails_delivered()
  end

  test "ignores user with yearly subscription that's not due for renewal in 7 days", %{user: user} do
    today = Timex.shift(@renewal_date, days: -10)

    insert(:subscription,
      user: user,
      paddle_plan_id: @yearly_plan,
      last_bill_date: Timex.shift(@renewal_date, months: -12, days: -10)
    )

    NotifyAnnualRenewal.perform(nil, nil, today)

    assert_no_emails_delivered()
  end

  test "sends renewal notification to user whose subscription is due for renewal in 7 days", %{
    user: user
  } do
    today = Timex.shift(@renewal_date, days: -7)

    insert(:subscription,
      user: user,
      paddle_plan_id: @yearly_plan,
      last_bill_date: Timex.shift(@renewal_date, years: -1)
    )

    NotifyAnnualRenewal.perform(nil, nil, today)

    assert_email_delivered_with(
      to: [{user.name, user.email}],
      subject: "Your Plausible subscription will renew on May 10, 2021"
    )
  end

  test "sends renewal notification to user whose subscription is due for renewal in 2 days", %{
    user: user
  } do
    today = Timex.shift(@renewal_date, days: -2)

    insert(:subscription,
      user: user,
      paddle_plan_id: @yearly_plan,
      last_bill_date: Timex.shift(@renewal_date, years: -1)
    )

    NotifyAnnualRenewal.perform(nil, nil, today)

    assert_email_delivered_with(
      to: [{user.name, user.email}],
      subject: "Your Plausible subscription will renew on May 10, 2021"
    )
  end

  test "does not send renewal notification multiple times", %{user: user} do
    today = Timex.shift(@renewal_date, days: -7)

    insert(:subscription,
      user: user,
      paddle_plan_id: @yearly_plan,
      last_bill_date: Timex.shift(@renewal_date, years: -1)
    )

    NotifyAnnualRenewal.perform(nil, nil, today)

    assert_email_delivered_with(
      to: [{user.name, user.email}],
      subject: "Your Plausible subscription will renew on May 10, 2021"
    )

    NotifyAnnualRenewal.perform(nil, nil, today)

    assert_no_emails_delivered()
  end

  test "sends a renewal notification again a year after the previous one", %{user: user} do
    today = Timex.shift(@renewal_date, days: -7)

    insert(:subscription,
      user: user,
      paddle_plan_id: @yearly_plan,
      last_bill_date: Timex.shift(@renewal_date, years: -1)
    )

    Repo.insert_all("sent_renewal_notifications", [
      %{
        user_id: user.id,
        timestamp: Timex.shift(@renewal_date, years: -1, days: -7) |> Timex.to_naive_datetime()
      }
    ])

    NotifyAnnualRenewal.perform(nil, nil, today)

    assert_email_delivered_with(
      to: [{user.name, user.email}],
      subject: "Your Plausible subscription will renew on May 10, 2021"
    )
  end
end
