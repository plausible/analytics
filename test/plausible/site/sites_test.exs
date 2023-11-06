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

  describe "get_for_user/2" do
    test "get site for super_admin" do
      user1 = insert(:user)
      user2 = insert(:user)
      patch_env(:super_admin_user_ids, [user2.id])

      %{id: site_id, domain: domain} = insert(:site, members: [user1])
      assert %{id: ^site_id} = Sites.get_for_user(user1.id, domain)
      assert %{id: ^site_id} = Sites.get_for_user(user1.id, domain, [:owner])

      assert is_nil(Sites.get_for_user(user2.id, domain))
      assert %{id: ^site_id} = Sites.get_for_user(user2.id, domain, [:super_admin])
    end
  end

  describe "list/3" do
    test "returns empty when there are no sites" do
      user = insert(:user)
      _rogue_site = insert(:site)

      assert %{
               entries: [],
               page_size: 24,
               page_number: 1,
               total_entries: 0,
               total_pages: 1
             } = Sites.list(user, %{})
    end

    test "returns invitations and sites" do
      user = insert(:user, email: "hello@example.com")

      site1 = %{id: site_id1} = insert(:site, members: [user], domain: "one.example.com")
      %{id: site_id2} = insert(:site, members: [user], domain: "two.example.com")
      %{id: site_id4} = insert(:site, members: [user], domain: "four.example.com")

      _rogue_site = insert(:site, domain: "rogue.example.com")

      insert(:invitation, email: user.email, inviter: build(:user), role: :owner, site: site1)

      %{id: site_id3} =
        insert(:site,
          domain: "three.example.com",
          invitations: [
            build(:invitation, email: user.email, inviter: build(:user), role: :viewer)
          ]
        )

      insert(:invitation, email: "friend@example.com", inviter: user, role: :viewer, site: site1)

      insert(:invitation,
        site: site1,
        inviter: user,
        email: "another@example.com"
      )

      assert %{
               entries: [
                 %{id: ^site_id1, entry_type: "invitation"},
                 %{id: ^site_id3, entry_type: "invitation"},
                 %{id: ^site_id4, entry_type: "site"},
                 %{id: ^site_id2, entry_type: "site"}
               ]
             } = Sites.list(user, %{})
    end

    test "puts pinned sites first" do
      user = insert(:user, email: "hello@example.com")

      site1 = %{id: site_id1} = insert(:site, members: [user], domain: "one.example.com")
      site2 = %{id: site_id2} = insert(:site, members: [user], domain: "two.example.com")
      %{id: site_id4} = insert(:site, members: [user], domain: "four.example.com")

      _rogue_site = insert(:site, domain: "rogue.example.com")

      insert(:invitation, email: user.email, inviter: build(:user), role: :owner, site: site1)

      %{id: site_id3} =
        insert(:site,
          domain: "three.example.com",
          invitations: [
            build(:invitation, email: user.email, inviter: build(:user), role: :viewer)
          ]
        )

      insert(:invitation, email: "friend@example.com", inviter: user, role: :viewer, site: site1)

      insert(:invitation,
        site: site1,
        inviter: user,
        email: "another@example.com"
      )

      Sites.toggle_pin(user, site2)

      assert %{
               entries: [
                 %{id: ^site_id2, entry_type: "site"},
                 %{id: ^site_id1, entry_type: "invitation"},
                 %{id: ^site_id3, entry_type: "invitation"},
                 %{id: ^site_id4, entry_type: "site"}
               ]
             } = Sites.list(user, %{})
    end

    test "filters by domain" do
      user = insert(:user)
      %{id: site_id1} = insert(:site, domain: "first.example.com", members: [user])
      %{id: _site_id2} = insert(:site, domain: "second.example.com", members: [user])
      _rogue_site = insert(:site)

      %{id: site_id3} =
        insert(:site,
          domain: "first-another.example.com",
          invitations: [
            build(:invitation, email: user.email, inviter: build(:user), role: :viewer)
          ]
        )

      assert %{
               entries: [
                 %{id: ^site_id3},
                 %{id: ^site_id1}
               ]
             } = Sites.list(user, %{}, filter_by_domain: "first")
    end

    test "handles pagination correctly" do
      user = insert(:user)
      %{id: site_id1} = insert(:site, members: [user])
      %{id: site_id2} = insert(:site, members: [user])
      _rogue_site = insert(:site)

      %{id: site_id3} =
        insert(:site,
          invitations: [
            build(:invitation, email: user.email, inviter: build(:user), role: :viewer)
          ]
        )

      assert %{
               entries: [
                 %{id: ^site_id3},
                 %{id: ^site_id1}
               ],
               page_number: 1,
               page_size: 2,
               total_entries: 3,
               total_pages: 2
             } = Sites.list(user, %{"page_size" => 2})

      assert %{
               entries: [
                 %{id: ^site_id2}
               ],
               page_number: 2,
               page_size: 2,
               total_entries: 3,
               total_pages: 2
             } = Sites.list(user, %{"page" => 2, "page_size" => 2})

      assert %{
               entries: [
                 %{id: ^site_id3},
                 %{id: ^site_id1}
               ],
               page_number: 1,
               page_size: 2,
               total_entries: 3,
               total_pages: 2
             } = Sites.list(user, %{"page" => 1, "page_size" => 2})
    end
  end

  describe "set_option/4" do
    test "allows setting option multiple times" do
      user = insert(:user)
      site = insert(:site, members: [user])

      assert prefs =
               %{options: %{is_pinned: true}} = Sites.set_option(user, site, :is_pinned, true)

      prefs = Repo.reload!(prefs)
      assert prefs.site_id == site.id
      assert prefs.user_id == user.id
      assert prefs.options.is_pinned == true

      assert prefs =
               %{options: %{is_pinned: false}} = Sites.set_option(user, site, :is_pinned, false)

      prefs = Repo.reload!(prefs)
      assert prefs.site_id == site.id
      assert prefs.user_id == user.id
      assert prefs.options.is_pinned == false

      assert prefs =
               %{options: %{is_pinned: true}} = Sites.set_option(user, site, :is_pinned, true)

      prefs = Repo.reload!(prefs)
      assert prefs.site_id == site.id
      assert prefs.user_id == user.id
      assert prefs.options.is_pinned == true
    end

    test "raises on invalid option" do
      user = insert(:user)
      site = insert(:site, members: [user])

      assert_raise FunctionClauseError, fn ->
        Sites.set_option(user, site, :invalid, false)
      end
    end
  end

  describe "toggle_pin/2" do
    test "allows pinning and unpinning site" do
      user = insert(:user)
      site = insert(:site, members: [user])

      site = %{site | is_pinned: false}
      assert prefs = %{options: %{is_pinned: true}} = Sites.toggle_pin(user, site)
      prefs = Repo.reload!(prefs)
      assert prefs.site_id == site.id
      assert prefs.user_id == user.id
      assert prefs.options.is_pinned == true

      site = %{site | is_pinned: true}
      assert prefs = %{options: %{is_pinned: false}} = Sites.toggle_pin(user, site)
      prefs = Repo.reload!(prefs)
      assert prefs.site_id == site.id
      assert prefs.user_id == user.id
      assert prefs.options.is_pinned == false

      site = %{site | is_pinned: false}
      assert prefs = %{options: %{is_pinned: true}} = Sites.toggle_pin(user, site)
      prefs = Repo.reload!(prefs)
      assert prefs.site_id == site.id
      assert prefs.user_id == user.id
      assert prefs.options.is_pinned == true
    end
  end
end
