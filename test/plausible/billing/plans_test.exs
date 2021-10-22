defmodule Plausible.Billing.PlansTest do
  use Plausible.DataCase
  alias Plausible.Billing.Plans

  @v1_plan_id "558018"
  @v2_plan_id "654177"

  describe "plans_for" do
    test "shows v1 pricing for users who are already on v1 pricing" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: @v1_plan_id))

      assert List.first(Plans.plans_for(user))[:monthly_product_id] == @v1_plan_id
    end

    test "shows v2 pricing for everyone else" do
      user = insert(:user) |> Repo.preload(:subscription)

      assert List.first(Plans.plans_for(user))[:monthly_product_id] == @v2_plan_id
    end
  end
end
