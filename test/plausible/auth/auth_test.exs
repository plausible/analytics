defmodule Plausible.AuthTest do
  use Plausible.DataCase
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
      insert(:site, members: [user], domain: "test-site.com")

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
end
