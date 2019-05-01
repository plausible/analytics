defmodule Plausible.BillingTest do
  use Plausible.DataCase
  alias Plausible.Billing

  describe "trial_days_left" do
    test "is 30 days for new signup" do
      user = insert(:user)

      assert Billing.trial_days_left(user) == 30
    end

    test "is 29 days for day old user" do
      user = insert(:user, inserted_at: Timex.shift(Timex.now(), days: -2))

      assert Billing.trial_days_left(user) == 29
    end
  end
end
