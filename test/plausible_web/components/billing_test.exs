defmodule PlausibleWeb.Components.BillingTest do
  use Plausible.DataCase
  import Phoenix.LiveViewTest
  alias PlausibleWeb.Components.Billing

  test "premium_feature_notice/1 renders a message when user is on trial" do
    me = insert(:user)

    assert render_component(&Billing.premium_feature_notice/1,
             billable_user: me,
             current_user: me,
             feature_mod: Plausible.Billing.Feature.Props
           ) =~
             "Custom Properties is part of the Plausible Business plan. You can access it during your trial"
  end

  test "premium_feature_notice/1 renders an upgrade link when user is the site owner and does not have access to the feature" do
    me = insert(:user, subscription: build(:growth_subscription))

    rendered =
      render_component(&Billing.premium_feature_notice/1,
        billable_user: me,
        current_user: me,
        feature_mod: Plausible.Billing.Feature.Props
      )

    assert rendered =~ "Custom Properties is part of the Plausible Business plan."
    assert rendered =~ "upgrade your subscription"
    assert rendered =~ "/billing/upgrade"
  end

  test "premium_feature_notice/1 does not render an upgrade link when user is not the site owner" do
    me = insert(:user)
    owner = insert(:user, subscription: build(:growth_subscription))

    rendered =
      render_component(&Billing.premium_feature_notice/1,
        billable_user: owner,
        current_user: me,
        feature_mod: Plausible.Billing.Feature.Funnels
      )

    assert rendered =~
             "Funnels is part of the Plausible Business plan. To get access to it, please reach out to the site owner to upgrade your subscription to the Business plan."

    refute rendered =~ "/billing/upgrade"
  end

  test "premium_feature_notice/1 does not render a notice when the user has access to the feature" do
    me = insert(:user, subscription: build(:business_subscription))

    rendered =
      render_component(&Billing.premium_feature_notice/1,
        billable_user: me,
        current_user: me,
        feature_mod: Plausible.Billing.Feature.Funnels
      )

    assert rendered == ""
  end
end
