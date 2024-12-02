defmodule PlausibleWeb.Components.Billing.NoticeTest do
  use Plausible.DataCase
  use Plausible.Teams.Test
  import Plausible.LiveViewTest, only: [render_component: 2]
  alias PlausibleWeb.Components.Billing.Notice

  test "premium_feature/1 does not render a notice when user is on trial" do
    me = new_user()

    assert render_component(&Notice.premium_feature/1,
             billable_user: me,
             current_user: me,
             feature_mod: Plausible.Billing.Feature.Props
           ) == ""
  end

  test "premium_feature/1 renders an upgrade link when user is the site owner and does not have access to the feature" do
    me = new_user() |> subscribe_to_growth_plan()

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
    me = new_user() |> subscribe_to_growth_plan()
    owner = new_user() |> subscribe_to_growth_plan()

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
    me = new_user() |> subscribe_to_business_plan()

    rendered =
      render_component(&Notice.premium_feature/1,
        billable_user: me,
        current_user: me,
        feature_mod: Plausible.Billing.Feature.Funnels
      )

    assert rendered == ""
  end

  test "limit_exceeded/1 when billable user is on growth displays upgrade link" do
    me = new_user() |> subscribe_to_growth_plan()

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
    me = new_user() |> subscribe_to_growth_plan()

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

  @tag :ee_only
  test "limit_exceeded/1 when billable user is on trial displays upgrade link" do
    me = new_user()

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

  @tag :ee_only
  test "limit_exceeded/1 when billable user is on an enterprise plan displays support email" do
    me = new_user() |> subscribe_to_enterprise_plan()

    rendered =
      render_component(&Notice.limit_exceeded/1,
        billable_user: me,
        current_user: me,
        limit: 10,
        resource: "users"
      )

    assert rendered =~ "Your account is limited to 10 users."

    assert rendered =~ "hello@plausible.io"
    assert rendered =~ "upgrade your subscription"
  end

  @tag :ee_only
  test "limit_exceeded/1 when billable user is on a business plan displays support email" do
    me = new_user() |> subscribe_to_business_plan()

    rendered =
      render_component(&Notice.limit_exceeded/1,
        billable_user: me,
        current_user: me,
        limit: 10,
        resource: "users"
      )

    assert rendered =~ "Your account is limited to 10 users."

    assert rendered =~ "hello@plausible.io"
    assert rendered =~ "upgrade your subscription"
  end
end
