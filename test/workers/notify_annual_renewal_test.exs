defmodule Plausible.Workers.NotifyAnnualRenewalTest do
  use Plausible.DataCase
  use Bamboo.Test
  import Plausible.TestUtils
  alias Plausible.Workers.NotifyAnnualRenewal
  alias Plausible.Billing.Plans

  setup [:create_user, :create_site]
  @monthly_plan Plans.plans()[:monthly][:"10k"][:product_id]
  @yearly_plan Plans.plans()[:yearly][:"10k"][:product_id]

  test "ignores user without subscription" do
    NotifyAnnualRenewal.perform(nil)

    assert_no_emails_delivered()
  end

  test "ignores user with monthly subscription", %{user: user} do
    insert(:subscription,
      user: user,
      paddle_plan_id: @monthly_plan,
      next_bill_date: Timex.shift(Timex.today(), days: 7)
    )

    NotifyAnnualRenewal.perform(nil)

    assert_no_emails_delivered()
  end

  test "ignores user with yearly subscription that's not due for renewal in 7 days", %{user: user} do
    insert(:subscription,
      user: user,
      paddle_plan_id: @yearly_plan,
      next_bill_date: Timex.shift(Timex.today(), days: 10)
    )

    NotifyAnnualRenewal.perform(nil)

    assert_no_emails_delivered()
  end

  test "sends renewal notification to user whose subscription is due for renewal in 7 days", %{
    user: user
  } do
    insert(:subscription,
      user: user,
      paddle_plan_id: @yearly_plan,
      next_bill_date: Timex.shift(Timex.today(), days: 7)
    )

    NotifyAnnualRenewal.perform(nil)

    assert_email_delivered_with(
      to: [{user.name, user.email}],
      subject: "Your Plausible subscription is up for renewal"
    )
  end

  test "sends renewal notification to user whose subscription is due for renewal in 2 days", %{
    user: user
  } do
    insert(:subscription,
      user: user,
      paddle_plan_id: @yearly_plan,
      next_bill_date: Timex.shift(Timex.today(), days: 2)
    )

    NotifyAnnualRenewal.perform(nil)

    assert_email_delivered_with(
      to: [{user.name, user.email}],
      subject: "Your Plausible subscription is up for renewal"
    )
  end

  test "does not send renewal notification multiple times", %{user: user} do
    insert(:subscription,
      user: user,
      paddle_plan_id: @yearly_plan,
      next_bill_date: Timex.shift(Timex.today(), days: 7)
    )

    NotifyAnnualRenewal.perform(nil)

    assert_email_delivered_with(
      to: [{user.name, user.email}],
      subject: "Your Plausible subscription is up for renewal"
    )

    NotifyAnnualRenewal.perform(nil)

    assert_no_emails_delivered()
  end

  test "sends a renewal notification again a year after the previous one", %{user: user} do
    insert(:subscription,
      user: user,
      paddle_plan_id: @yearly_plan,
      next_bill_date: Timex.shift(Timex.today(), days: 7)
    )

    Repo.insert_all("sent_renewal_notifications", [
      %{
        user_id: user.id,
        timestamp: Timex.shift(Timex.today(), years: -1) |> Timex.to_naive_datetime()
      }
    ])

    NotifyAnnualRenewal.perform(nil)

    assert_email_delivered_with(
      to: [{user.name, user.email}],
      subject: "Your Plausible subscription is up for renewal"
    )
  end

  describe "expiration" do
    test "if user subscription is 'deleted', notify them about expiration instead", %{user: user} do
      insert(:subscription,
        user: user,
        paddle_plan_id: @yearly_plan,
        next_bill_date: Timex.shift(Timex.today(), days: 7),
        status: "deleted"
      )

      NotifyAnnualRenewal.perform(nil)

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Your Plausible subscription is about to expire"
      )
    end
  end
end
