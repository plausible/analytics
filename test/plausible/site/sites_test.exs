defmodule Plausible.SitesTest do
  use Plausible.DataCase

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

  describe "stats_start_date" do
    test "is nil if site has no stats" do
      site = insert(:site)

      assert Sites.stats_start_date(site) == nil
    end

    test "is date if first pageview if site does have stats" do
      site = insert(:site)

      populate_stats(site, [
        build(:pageview)
      ])

      assert Sites.stats_start_date(site) == Timex.today(site.timezone)
    end

    test "memoizes value of start date" do
      site = insert(:site)

      assert site.stats_start_date == nil

      populate_stats(site, [
        build(:pageview)
      ])

      assert Sites.stats_start_date(site) == Timex.today(site.timezone)
      assert Repo.reload!(site).stats_start_date == Timex.today(site.timezone)
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
  end
end
