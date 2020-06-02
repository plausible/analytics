defmodule Plausible.AuthTest do
  use Plausible.DataCase
  alias Plausible.Auth

  describe "user_completed_setup?" do
    test "is false if user does not have any sites" do
      user = insert(:user)

      refute Auth.user_completed_setup?(user)
    end

    test "is false if user does not have any events" do
      user = insert(:user)
      insert(:site, members: [user])

      refute Auth.user_completed_setup?(user)
    end

    test "is true if user does have events" do
      user = insert(:user)
      insert(:site, members: [user], domain: "test-site.com")

      assert Auth.user_completed_setup?(user)
    end
  end
end
