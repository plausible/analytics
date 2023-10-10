defmodule PlausibleWeb.Components.BillingTest do
  use Plausible.DataCase
  import Phoenix.LiveViewTest
  alias PlausibleWeb.Components.Billing

  @v4_growth_plan_id "change-me-749342"
  @v4_business_plan_id "change-me-b749342"

  test "extra_feature_notice/1 renders a message when user is on trial" do
    me = insert(:user)
    site = :site |> insert(members: [me]) |> Plausible.Repo.preload(:owner)

    assert render_component(&Billing.extra_feature_notice/1,
             site: site,
             current_user: me,
             feature_mod: Plausible.Billing.Feature.Props
           ) =~
             "Custom Properties is part of the Plausible Business plan. You can access it during your trial"
  end

  test "extra_feature_notice/1 renders an upgrade link when user is the site owner and does not have access to the feature" do
    me = insert(:user, subscription: build(:subscription, paddle_plan_id: @v4_growth_plan_id))
    site = :site |> insert(members: [me]) |> Plausible.Repo.preload(:owner)

    rendered =
      render_component(&Billing.extra_feature_notice/1,
        site: site,
        current_user: me,
        feature_mod: Plausible.Billing.Feature.Props
      )

    assert rendered =~ "Custom Properties is part of the Plausible Business plan."
    assert rendered =~ "upgrade your subscription"
    assert rendered =~ "/billing/upgrade"
  end

  test "extra_feature_notice/1 does not render an upgrade link when user is not the site owner" do
    me = insert(:user)
    owner = insert(:user, subscription: build(:subscription, paddle_plan_id: @v4_growth_plan_id))

    site =
      :site
      |> insert(
        memberships: [
          build(:site_membership, user: owner, role: :owner),
          build(:site_membership, user: me, role: :admin)
        ]
      )
      |> Plausible.Repo.preload(:owner)

    rendered =
      render_component(&Billing.extra_feature_notice/1,
        site: site,
        current_user: me,
        feature_mod: Plausible.Billing.Feature.Funnels
      )

    assert rendered =~
             "Funnels is part of the Plausible Business plan. To get access to it, please reach out to the site owner to upgrade your subscription to the Business plan."

    refute rendered =~ "/billing/upgrade"
  end

  test "extra_feature_notice/1 does not render a notice when the user has access to the feature" do
    me = insert(:user, subscription: build(:subscription, paddle_plan_id: @v4_business_plan_id))
    site = :site |> insert(members: [me]) |> Plausible.Repo.preload(:owner)

    rendered =
      render_component(&Billing.extra_feature_notice/1,
        site: site,
        current_user: me,
        feature_mod: Plausible.Billing.Feature.Funnels
      )

    assert rendered == ""
  end
end
