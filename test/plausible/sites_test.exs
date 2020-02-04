defmodule Plausible.SitesTest do
  use Plausible.DataCase
  alias Plausible.Sites

  describe "has_pageviews?" do
    test "is true if site has pageviews" do
      site = insert(:site)
      insert(:pageview, domain: site.domain)

      assert Sites.has_pageviews?(site)
    end

    test "is false if site does not have pageviews" do
      site = insert(:site)

      refute Sites.has_pageviews?(site)
    end
  end

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
