defmodule Plausible.Site.MembershipTest do
  use Plausible.DataCase

  test "raises on trying to insert two owner memberships for the same site" do
    user1 = insert(:user)
    user2 = insert(:user)
    site = insert(:site, memberships: [build(:site_membership, user: user1, role: "owner")])

    assert_raise Ecto.ConstraintError, ~r/site_memberships_site_id_index/, fn ->
      insert(:site_membership, site: site, user: user2, role: "owner")
    end
  end
end
