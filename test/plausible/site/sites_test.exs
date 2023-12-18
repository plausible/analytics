defmodule Plausible.SitesTest do
  use Plausible.DataCase

  alias Plausible.Sites

  describe "create a site" do
    @tag :full_build_only
    test "sets accept_traffic_until for trial + 14 days" do
      user = insert(:user)

      params = %{"domain" => "example.com", "timezone" => "Europe/London"}
      {:ok, %{site: site}} = Sites.create(user, params)

      expiry = user.trial_expiry_date
      assert Date.after?(expiry, Date.utc_today())
      assert Date.diff(site.accept_traffic_until, expiry) == 14
    end

    test "sets accept_traffic_until to some time in the future for free accounts" do
      user = insert(:user, subscription: build(:subscription, paddle_plan_id: "free_10k"))

      params = %{"domain" => "example.com", "timezone" => "Europe/London"}
      {:ok, %{site: site}} = Sites.create(user, params)

      assert site.accept_traffic_until == ~D[2035-01-01]
    end

    @tag :full_build_only
    test "sets accept_traffic_until to +30d for subscriptions" do
      future = Date.add(Date.utc_today(), 30)
      user = insert(:user, subscription: build(:subscription, next_bill_date: future))

      params = %{"domain" => "example.com", "timezone" => "Europe/London"}
      {:ok, %{site: site}} = Sites.create(user, params)

      assert Date.diff(site.accept_traffic_until, Date.utc_today()) == 60
    end
  end

  describe "update_accept_traffic_until" do
    @tag :full_build_only
    test "updates owned sites" do
      user = insert(:user)

      params = %{"domain" => "1.example.com", "timezone" => "Europe/London"}
      {:ok, %{site: site1}} = Sites.create(user, params)

      params = %{"domain" => "2.example.com", "timezone" => "Europe/London"}
      {:ok, %{site: site2}} = Sites.create(user, params)

      rogue_site = insert(:site) |> Repo.reload!()

      future = Date.add(Date.utc_today(), 30)
      insert(:subscription, user: user, next_bill_date: future)

      Process.sleep(1000)

      assert {:ok, 2} = Sites.update_accept_traffic_until(user)

      updated1 = Repo.reload!(site1)
      updated2 = Repo.reload!(site2)

      assert ^rogue_site = Repo.reload!(rogue_site)

      assert updated1.updated_at != site1.updated_at
      assert updated2.updated_at != site2.updated_at
      assert updated1.accept_traffic_until == updated2.accept_traffic_until
      assert Date.after?(updated1.accept_traffic_until, site1.accept_traffic_until)
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
    @tag :full_build_only
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
             } = Sites.list_with_invitations(user, %{})
    end

    test "pinned site doesn't matter with membership revoked (no active invitations)" do
      user1 = insert(:user, email: "user1@example.com")
      user2 = insert(:user, email: "user2@example.com")

      insert(:site, members: [user1], domain: "one.example.com")

      site2 =
        insert(:site,
          members: [user2],
          domain: "two.example.com"
        )

      membership = insert(:site_membership, user: user1, role: :viewer, site: site2)

      {:ok, _} = Sites.toggle_pin(user1, site2)

      Repo.delete!(membership)

      assert %{entries: [%{domain: "one.example.com"}]} = Sites.list(user1, %{})
      assert %{entries: [%{domain: "one.example.com"}]} = Sites.list_with_invitations(user1, %{})
    end

    test "pinned site doesn't matter with membership revoked (with active invitation)" do
      user1 = insert(:user, email: "user1@example.com")
      user2 = insert(:user, email: "user2@example.com")

      insert(:site, members: [user1], domain: "one.example.com")

      site2 =
        insert(:site,
          members: [user2],
          domain: "two.example.com"
        )

      membership = insert(:site_membership, user: user1, role: :viewer, site: site2)
      insert(:invitation, email: user1.email, inviter: user2, role: :owner, site: site2)

      {:ok, _} = Sites.toggle_pin(user1, site2)

      Repo.delete!(membership)

      assert %{entries: [%{domain: "one.example.com"}]} = Sites.list(user1, %{})

      assert %{entries: [%{domain: "two.example.com"}, %{domain: "one.example.com"}]} =
               Sites.list_with_invitations(user1, %{})
    end

    test "puts invitations first, pinned sites second, sites last" do
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
                 %{id: ^site_id1, entry_type: "invitation"},
                 %{id: ^site_id3, entry_type: "invitation"},
                 %{id: ^site_id2, entry_type: "pinned_site"},
                 %{id: ^site_id4, entry_type: "site"}
               ]
             } = Sites.list_with_invitations(user, %{})
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
