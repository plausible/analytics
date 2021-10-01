defmodule Plausible.SitesTest do
  use Plausible.DataCase
  import Plausible.TestUtils
  alias Plausible.Sites

  describe "is_member?" do
    test "is true if user is a member of the site" do
      user = insert(:user)
      site = insert(:site, members: [user])

      assert Sites.is_member?(user.id, site)
    end

    test "is false if user is not a member" do
      user = insert(:user)
      site = insert(:site)

      refute Sites.is_member?(user.id, site)
    end
  end

  describe "has_stats?" do
    test "is false if site has no stats" do
      site = insert(:site)

      refute Sites.has_stats?(site)
    end

    test "is true if site has stats" do
      site = insert(:site)

      populate_stats(site, [
        build(:pageview)
      ])

      assert Sites.has_stats?(site)
    end

    test "memoizes has_stats value" do
      site = insert(:site)

      populate_stats(site, [
        build(:pageview)
      ])

      refute site.has_stats

      assert Sites.has_stats?(site)
      assert Repo.reload!(site).has_stats
    end
  end
end
