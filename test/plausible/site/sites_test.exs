defmodule Plausible.SitesTest do
  use Plausible.DataCase

  alias Plausible.Sites

  describe "create a site" do
    test "creates a site" do
      user = insert(:user)

      params = %{"domain" => "example.com", "timezone" => "Europe/London"}

      assert {:ok, %{site: %{domain: "example.com", timezone: "Europe/London"}}} =
               Sites.create(user, params)
    end

    test "creates a site (TEAM)" do
      user = insert(:user)
      {:ok, team} = Plausible.Teams.get_or_create(user)

      params = %{"domain" => "example.com", "timezone" => "Europe/London"}

      assert {:ok, %{site: %{domain: "example.com", timezone: "Europe/London"}}} =
               Plausible.Teams.Sites.create(team, params)
    end

    test "fails on invalid timezone" do
      user = insert(:user)

      params = %{"domain" => "example.com", "timezone" => "blah"}

      assert {:error, :site, %{errors: [timezone: {"is invalid", []}]}, %{}} =
               Sites.create(user, params)
    end

    test "fails on invalid timezone (TEAM)" do
      user = insert(:user)
      {:ok, team} = Plausible.Teams.get_or_create(user)

      params = %{"domain" => "example.com", "timezone" => "blah"}

      assert {:error, :site, %{errors: [timezone: {"is invalid", []}]}, %{}} =
               Plausible.Teams.Sites.create(team, params)
    end
  end

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

    test "is date if site does have stats" do
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

  describe "native_stats_start_date" do
    test "is nil if site has no stats" do
      site = insert(:site)

      assert Sites.native_stats_start_date(site) == nil
    end

    test "is date if site does have stats" do
      site = insert(:site)

      populate_stats(site, [
        build(:pageview)
      ])

      assert Sites.native_stats_start_date(site) == Timex.today(site.timezone)
    end

    test "ignores imported stats" do
      site = insert(:site)
      insert(:site_import, site: site)

      assert Sites.native_stats_start_date(site) == nil
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
    @tag :ee_only
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

  describe "list/3 and list_with_invitations/3" do
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

      assert %{
               entries: [],
               page_size: 24,
               page_number: 1,
               total_entries: 0,
               total_pages: 1
             } = Plausible.Teams.Sites.list(user, %{})

      assert %{
               entries: [],
               page_size: 24,
               page_number: 1,
               total_entries: 0,
               total_pages: 1
             } = Sites.list_with_invitations(user, %{})

      assert %{
               entries: [],
               page_size: 24,
               page_number: 1,
               total_entries: 0,
               total_pages: 1
             } = Plausible.Teams.Sites.list_with_invitations(user, %{})
    end

    test "pinned site doesn't matter with membership revoked (no active invitations)" do
      user1 = insert(:user, email: "user1@example.com")
      user2 = insert(:user, email: "user2@example.com")

      team1 = insert(:team)
      insert(:site, team: team1, members: [user1], domain: "one.example.com")
      insert(:team_membership, team: team1, user: user1, role: :owner)

      team2 = insert(:team)

      site2 =
        insert(:site,
          team: team2,
          members: [user2],
          domain: "two.example.com"
        )

      insert(:team_membership, team: team2, user: user2, role: :owner)

      membership = insert(:site_membership, user: user1, role: :viewer, site: site2)
      team_membership = insert(:team_membership, team: team2, user: user1, role: :guest)
      insert(:guest_membership, team_membership: team_membership, site: site2, role: :viewer)

      {:ok, _} = Sites.toggle_pin(user1, site2)

      Repo.delete!(membership)
      Repo.delete!(team_membership)

      assert %{entries: [%{domain: "one.example.com"}]} = Sites.list(user1, %{})
      assert %{entries: [%{domain: "one.example.com"}]} = Sites.list_with_invitations(user1, %{})

      assert %{entries: [%{domain: "one.example.com"}]} = Plausible.Teams.Sites.list(user1, %{})

      assert %{entries: [%{domain: "one.example.com"}]} =
               Plausible.Teams.Sites.list_with_invitations(user1, %{})
    end

    test "pinned site doesn't matter with membership revoked (with active invitation)" do
      user1 = insert(:user, email: "user1@example.com")
      user2 = insert(:user, email: "user2@example.com")

      team1 = insert(:team)
      insert(:site, team: team1, members: [user1], domain: "one.example.com")
      insert(:team_membership, team: team1, user: user1, role: :owner)

      team2 = insert(:team)

      site2 =
        insert(:site,
          team: team2,
          members: [user2],
          domain: "two.example.com"
        )

      insert(:team_membership, team: team2, user: user2, role: :owner)

      membership = insert(:site_membership, user: user1, role: :viewer, site: site2)
      team_membership = insert(:team_membership, team: team2, user: user1, role: :guest)
      insert(:guest_membership, team_membership: team_membership, site: site2, role: :viewer)

      insert(:invitation, email: user1.email, inviter: user2, role: :owner, site: site2)

      team_invitation =
        insert(:team_invitation, team: team2, email: user1.email, inviter: user2, role: :guest)

      insert(:guest_invitation, team_invitation: team_invitation, site: site2, role: :editor)

      {:ok, _} = Sites.toggle_pin(user1, site2)

      Repo.delete!(membership)
      Repo.delete!(team_membership)

      assert %{entries: [%{domain: "one.example.com"}]} = Sites.list(user1, %{})

      assert %{entries: [%{domain: "two.example.com"}, %{domain: "one.example.com"}]} =
               Sites.list_with_invitations(user1, %{})

      assert %{entries: [%{domain: "one.example.com"}]} = Plausible.Teams.Sites.list(user1, %{})

      assert %{entries: [%{domain: "two.example.com"}, %{domain: "one.example.com"}]} =
               Plausible.Teams.Sites.list_with_invitations(user1, %{})
    end

    test "puts invitations first, pinned sites second, sites last" do
      user = insert(:user, email: "hello@example.com")

      team1 = insert(:team)

      site1 =
        %{id: site_id1} = insert(:site, team: team1, members: [user], domain: "one.example.com")

      insert(:team_membership, team: team1, user: user, role: :owner)
      team2 = insert(:team)

      site2 =
        %{id: site_id2} = insert(:site, team: team2, members: [user], domain: "two.example.com")

      insert(:team_membership, team: team2, user: build(:user), role: :owner)
      team_membership2 = insert(:team_membership, team: team2, user: user, role: :guest)
      insert(:guest_membership, team_membership: team_membership2, site: site2, role: :editor)

      team4 = insert(:team)

      site4 =
        %{id: site_id4} = insert(:site, team: team4, members: [user], domain: "four.example.com")

      insert(:team_membership, team: team4, user: build(:user), role: :owner)
      team_membership4 = insert(:team_membership, team: team4, user: user, role: :guest)
      insert(:guest_membership, team_membership: team_membership4, site: site4, role: :viewer)

      _rogue_site = insert(:site, team: build(:team), domain: "rogue.example.com")

      ## Having owner invite on owned site does not make much sense?
      ## Maybe that was a repro of real-life example?
      # insert(:invitation, email: user.email, inviter: build(:user), role: :owner, site: site1)

      # team_invitation1 =
      #   insert(:team_invitation,
      #     team: team1,
      #     email: user.email,
      #     inviter: build(:user),
      #     role: :guest
      #   )

      # insert(:guest_invitation, team_invitation: team_invitation1, site: site1, role: :editor)

      team3 = insert(:team)

      site3 = %{id: site_id3} = insert(:site, team: team3, domain: "three.example.com")

      insert(:invitation, email: user.email, inviter: build(:user), role: :viewer, site: site3)

      team_invitation2 =
        insert(:team_invitation,
          team: team3,
          email: user.email,
          inviter: build(:user),
          role: :guest
        )

      insert(:guest_invitation, team_invitation: team_invitation2, site: site3, role: :viewer)

      insert(:invitation, email: "friend@example.com", inviter: user, role: :viewer, site: site1)

      team_invitation3 =
        insert(:team_invitation,
          team: team1,
          email: "friend@example.com",
          inviter: user,
          role: :guest
        )

      insert(:guest_invitation, team_invitation: team_invitation3, site: site1, role: :viewer)

      insert(:invitation,
        site: site1,
        inviter: user,
        email: "another@example.com"
      )

      team_invitation4 =
        insert(:team_invitation,
          team: team1,
          email: "another@example.com",
          inviter: user,
          role: :guest
        )

      insert(:guest_invitation, team_invitation: team_invitation4, site: site1, role: :editor)

      {:ok, _} = Sites.toggle_pin(user, site2)

      assert %{
               entries: [
                 %{id: ^site_id2, entry_type: "pinned_site"},
                 %{id: ^site_id4, entry_type: "site"},
                 %{id: ^site_id1, entry_type: "site"}
               ]
             } = Sites.list(user, %{})

      assert %{
               entries: [
                 %{id: ^site_id3, entry_type: "invitation"},
                 %{id: ^site_id2, entry_type: "pinned_site"},
                 %{id: ^site_id4, entry_type: "site"},
                 %{id: ^site_id1, entry_type: "site"}
               ]
             } = Sites.list_with_invitations(user, %{})

      assert %{
               entries: [
                 %{id: ^site_id2, entry_type: "pinned_site"},
                 %{id: ^site_id4, entry_type: "site"},
                 %{id: ^site_id1, entry_type: "site"}
               ]
             } = Plausible.Teams.Sites.list(user, %{})

      assert %{
               entries: [
                 %{id: ^site_id3, entry_type: "invitation"},
                 %{id: ^site_id2, entry_type: "pinned_site"},
                 %{id: ^site_id4, entry_type: "site"},
                 %{id: ^site_id1, entry_type: "site"}
               ]
             } = Plausible.Teams.Sites.list_with_invitations(user, %{})
    end

    test "pinned sites are ordered according to the time they were pinned at" do
      user = insert(:user, email: "hello@example.com")

      site1 = %{id: site_id1} = insert(:site, members: [user], domain: "one.example.com")
      site2 = %{id: site_id2} = insert(:site, members: [user], domain: "two.example.com")
      site4 = %{id: site_id4} = insert(:site, members: [user], domain: "four.example.com")

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

      Sites.set_option(user, site2, :pinned_at, ~N[2023-10-22 12:00:00])
      {:ok, _} = Sites.toggle_pin(user, site4)

      assert %{
               entries: [
                 %{id: ^site_id4, entry_type: "pinned_site"},
                 %{id: ^site_id2, entry_type: "pinned_site"},
                 %{id: ^site_id1, entry_type: "site"}
               ]
             } = Sites.list(user, %{})

      assert %{
               entries: [
                 %{id: ^site_id1, entry_type: "invitation"},
                 %{id: ^site_id3, entry_type: "invitation"},
                 %{id: ^site_id4, entry_type: "pinned_site"},
                 %{id: ^site_id2, entry_type: "pinned_site"}
               ]
             } = Sites.list_with_invitations(user, %{})
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
                 %{id: ^site_id1}
               ]
             } = Sites.list(user, %{}, filter_by_domain: "first")

      assert %{
               entries: [
                 %{id: ^site_id3},
                 %{id: ^site_id1}
               ]
             } = Sites.list_with_invitations(user, %{}, filter_by_domain: "first")
    end
  end

  describe "list/3" do
    test "returns sites only, no invitations" do
      user = insert(:user, email: "hello@example.com")

      site1 = %{id: site_id1} = insert(:site, members: [user], domain: "one.example.com")
      %{id: site_id2} = insert(:site, members: [user], domain: "two.example.com")
      %{id: site_id4} = insert(:site, members: [user], domain: "four.example.com")

      _rogue_site = insert(:site, domain: "rogue.example.com")

      insert(:invitation, email: user.email, inviter: build(:user), role: :owner, site: site1)

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
                 %{id: ^site_id4, entry_type: "site"},
                 %{id: ^site_id1, entry_type: "site"},
                 %{id: ^site_id2, entry_type: "site"}
               ]
             } = Sites.list(user, %{})
    end

    test "handles pagination correctly" do
      user = insert(:user)
      %{id: site_id1} = insert(:site, members: [user])
      %{id: site_id2} = insert(:site, members: [user])
      _rogue_site = insert(:site)

      insert(:site,
        invitations: [
          build(:invitation, email: user.email, inviter: build(:user), role: :viewer)
        ]
      )

      site4 = %{id: site_id4} = insert(:site, members: [user])

      {:ok, _} = Sites.toggle_pin(user, site4)

      assert %{
               entries: [
                 %{id: ^site_id4},
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
                 %{id: ^site_id4},
                 %{id: ^site_id1}
               ],
               page_number: 1,
               page_size: 2,
               total_entries: 3,
               total_pages: 2
             } = Sites.list(user, %{"page" => 1, "page_size" => 2})
    end
  end

  describe "list_with_invitations/3" do
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
             } = Sites.list_with_invitations(user, %{})
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
             } = Sites.list_with_invitations(user, %{"page_size" => 2})

      assert %{
               entries: [
                 %{id: ^site_id2}
               ],
               page_number: 2,
               page_size: 2,
               total_entries: 3,
               total_pages: 2
             } = Sites.list_with_invitations(user, %{"page" => 2, "page_size" => 2})

      assert %{
               entries: [
                 %{id: ^site_id3},
                 %{id: ^site_id1}
               ],
               page_number: 1,
               page_size: 2,
               total_entries: 3,
               total_pages: 2
             } = Sites.list_with_invitations(user, %{"page" => 1, "page_size" => 2})
    end
  end

  describe "set_option/4" do
    test "allows setting option multiple times" do
      user = insert(:user)
      site = insert(:site, members: [user])

      assert prefs =
               %{pinned_at: %NaiveDateTime{}} =
               Sites.set_option(user, site, :pinned_at, NaiveDateTime.utc_now())

      prefs = Repo.reload!(prefs)
      assert prefs.site_id == site.id
      assert prefs.user_id == user.id
      assert prefs.pinned_at

      assert prefs =
               %{pinned_at: nil} = Sites.set_option(user, site, :pinned_at, nil)

      prefs = Repo.reload!(prefs)
      assert prefs.site_id == site.id
      assert prefs.user_id == user.id
      refute prefs.pinned_at

      assert prefs =
               %{pinned_at: %NaiveDateTime{}} =
               Sites.set_option(user, site, :pinned_at, NaiveDateTime.utc_now())

      prefs = Repo.reload!(prefs)
      assert prefs.site_id == site.id
      assert prefs.user_id == user.id
      assert prefs.pinned_at
    end

    test "raises on invalid option" do
      user = insert(:user)
      site = insert(:site, members: [user])

      assert_raise FunctionClauseError, fn ->
        Sites.set_option(user, site, :invalid, false)
      end
    end

    test "raises on invalid site/user combination" do
      user = insert(:user)
      site = insert(:site)

      assert_raise Ecto.NoResultsError, fn ->
        Sites.set_option(user, site, :pinned_at, nil)
      end
    end
  end

  describe "toggle_pin/2" do
    test "allows pinning and unpinning site" do
      user = insert(:user)
      site = insert(:site, members: [user])

      site = %{site | pinned_at: nil}
      assert {:ok, prefs} = Sites.toggle_pin(user, site)
      assert prefs = %{pinned_at: %NaiveDateTime{}} = prefs
      prefs = Repo.reload!(prefs)
      assert prefs.site_id == site.id
      assert prefs.user_id == user.id
      assert prefs.pinned_at

      site = %{site | pinned_at: NaiveDateTime.utc_now()}
      assert {:ok, prefs} = Sites.toggle_pin(user, site)
      assert %{pinned_at: nil} = prefs
      prefs = Repo.reload!(prefs)
      assert prefs.site_id == site.id
      assert prefs.user_id == user.id
      refute prefs.pinned_at

      site = %{site | pinned_at: nil}
      assert {:ok, prefs} = Sites.toggle_pin(user, site)
      assert %{pinned_at: %NaiveDateTime{}} = prefs
      prefs = Repo.reload!(prefs)
      assert prefs.site_id == site.id
      assert prefs.user_id == user.id
      assert prefs.pinned_at
    end

    test "returns error when pins limit hit" do
      user = insert(:user)

      for _ <- 1..9 do
        site = insert(:site, members: [user])
        assert {:ok, _} = Sites.toggle_pin(user, site)
      end

      site = insert(:site, members: [user])

      assert {:error, :too_many_pins} = Sites.toggle_pin(user, site)
    end
  end
end
