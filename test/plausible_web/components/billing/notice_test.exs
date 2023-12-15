defmodule PlausibleWeb.Components.Billing.NoticeTest do
  use Plausible.DataCase
  import Phoenix.LiveViewTest
  alias PlausibleWeb.Components.Billing.Notice

  test "premium_feature/1 does not render a notice when user is on trial" do
    me = insert(:user)

    assert render_component(&Notice.premium_feature/1,
             billable_user: me,
             current_user: me,
             feature_mod: Plausible.Billing.Feature.Props
           ) == ""
  end

  test "premium_feature/1 renders an upgrade link when user is the site owner and does not have access to the feature" do
    me = insert(:user, subscription: build(:growth_subscription))

    rendered =
      render_component(&Notice.premium_feature/1,
        billable_user: me,
        current_user: me,
        feature_mod: Plausible.Billing.Feature.Props
      )

    assert rendered =~ "Your account does not have access to Custom Properties"
    assert rendered =~ "upgrade your subscription"
    assert rendered =~ "/billing/choose-plan"
  end

  test "premium_feature/1 does not render an upgrade link when user is not the site owner" do
    me = insert(:user)
    owner = insert(:user, subscription: build(:growth_subscription))

    rendered =
      render_component(&Notice.premium_feature/1,
        billable_user: owner,
        current_user: me,
        feature_mod: Plausible.Billing.Feature.Funnels
      )

    assert rendered =~ "The owner of this site does not have access to Funnels"
    assert rendered =~ "please reach out to the site owner to upgrade their subscription"
  end

  test "premium_feature/1 does not render a notice when the user has access to the feature" do
    me = insert(:user, subscription: build(:business_subscription))

    rendered =
      render_component(&Notice.premium_feature/1,
        billable_user: me,
        current_user: me,
        feature_mod: Plausible.Billing.Feature.Funnels
      )

    assert rendered == ""
  end

  test "limit_exceeded/1 when billable user is on growth displays upgrade link" do
    me = insert(:user, subscription: build(:growth_subscription))

    rendered =
      render_component(&Notice.limit_exceeded/1,
        billable_user: me,
        current_user: me,
        limit: 10,
        resource: "users"
      )

    assert rendered =~ "Your account is limited to 10 users. To increase this limit"
    assert rendered =~ "upgrade your subscription"
    assert rendered =~ "/billing/choose-plan"
  end

  test "limit_exceeded/1 when billable user is on growth but is not current user does not display upgrade link" do
    me = insert(:user, subscription: build(:growth_subscription))

    rendered =
      render_component(&Notice.limit_exceeded/1,
        billable_user: me,
        current_user: insert(:user),
        limit: 10,
        resource: "users"
      )

    assert rendered =~ "The owner of this site is limited to 10 users"
    assert rendered =~ "please reach out to the site owner to upgrade their subscription"
  end

  @tag :full_build_only
  test "limit_exceeded/1 when billable user is on trial displays upgrade link" do
    me = insert(:user)

    rendered =
      render_component(&Notice.limit_exceeded/1,
        billable_user: me,
        current_user: me,
        limit: 10,
        resource: "users"
      )

    assert rendered =~ "Your account is limited to 10 users"
    assert rendered =~ "upgrade your subscription"
    assert rendered =~ "/billing/choose-plan"
  end

  test "limit_exceeded/1 when billable user is on an enterprise plan displays support email" do
    me =
      insert(:user,
        enterprise_plan: build(:enterprise_plan, paddle_plan_id: "123321"),
        subscription: build(:subscription, paddle_plan_id: "123321")
      )

    rendered =
      render_component(&Notice.limit_exceeded/1,
        billable_user: me,
        current_user: me,
        limit: 10,
        resource: "users"
      )

    assert rendered =~ "Your account is limited to 10 users."
    assert rendered =~ "please contact hello@plausible.io to upgrade your subscription"
  end

  test "limit_exceeded/1 when billable user is on a business plan displays support email" do
    me = insert(:user, subscription: build(:business_subscription))

    rendered =
      render_component(&Notice.limit_exceeded/1,
        billable_user: me,
        current_user: me,
        limit: 10,
        resource: "users"
      )

    assert rendered =~ "Your account is limited to 10 users."
    assert rendered =~ "please contact hello@plausible.io to upgrade your subscription"
  end
end
