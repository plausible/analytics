defmodule Plausible.AuthTest do
  use Plausible.DataCase, async: true
  alias Plausible.Auth

  describe "user_completed_setup?" do
    test "is false if user does not have any sites" do
      user = insert(:user)

      refute Auth.has_active_sites?(user)
    end

    test "is false if user does not have any events" do
      user = insert(:user)
      insert(:site, members: [user])

      refute Auth.has_active_sites?(user)
    end

    test "is true if user does have events" do
      user = insert(:user)
      site = insert(:site, members: [user])

      populate_stats(site, [
        build(:pageview)
      ])

      assert Auth.has_active_sites?(user)
    end

    test "can specify which roles we're looking for" do
      user = insert(:user)

      insert(:site,
        domain: "test-site.com",
        memberships: [
          build(:site_membership, user: user, role: :admin)
        ]
      )

      refute Auth.has_active_sites?(user, [:owner])
    end
  end

  test "enterprise?/1 returns whether the user has an enterprise plan" do
    user_without_plan = insert(:user)
    user_with_plan = insert(:user, enterprise_plan: build(:enterprise_plan))

    assert Auth.enterprise?(user_with_plan)
    refute Auth.enterprise?(user_without_plan)
    refute Auth.enterprise?(nil)
  end
end
