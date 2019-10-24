defmodule Plausible.AuthTest do
  use Plausible.DataCase
  alias Plausible.Auth

  describe "user_completed_setup?" do
    test "is false if user does not have any events" do
      user = insert(:user)
      insert(:site, members: [user])

      refute Auth.user_completed_setup?(user)
    end

    test "is true if user does have events" do
      user = insert(:user)
      site = insert(:site, members: [user])
      insert(:pageview, hostname: site.domain)

      assert Auth.user_completed_setup?(user)
    end
  end
end
