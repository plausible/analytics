defmodule Plausible.SitesTest do
  use Plausible.DataCase
  alias Plausible.Sites

  describe "is_owner?" do
    test "is true if user is the owner of the site" do
      user = insert(:user)
      site = insert(:site, members: [user])

      assert Sites.is_owner?(user.id, site)
    end

    test "is false if user is not the owner" do
      user = insert(:user)
      site = insert(:site)

      refute Sites.is_owner?(user.id, site)
    end
  end
end
