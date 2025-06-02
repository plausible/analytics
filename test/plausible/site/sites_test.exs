defmodule Plausible.SitesTest do
  use Plausible.DataCase
  use Plausible.Teams.Test

  alias Plausible.Sites

  describe "create a site" do
    test "creates a site" do
      user = new_user()

      params = %{"domain" => "example.com", "timezone" => "Europe/London"}

      assert {:ok, %{site: %{domain: "example.com", timezone: "Europe/London"}}} =
               Sites.create(user, params)
    end

    test "creating a site sets `legacy_time_on_page_cutoff`" do
      user = new_user()

      params = %{"domain" => "example.com", "timezone" => "Europe/London"}

      assert {:ok, %{site: %{legacy_time_on_page_cutoff: ~D[1970-01-01]}}} =
               Sites.create(user, params)
    end

    @tag :ee_only
    test "updates team's locked state" do
      user = new_user(trial_expiry_date: Date.add(Date.utc_today(), -1), team: [locked: false])

      team = new_site(owner: user).team

      refute team.locked

      params = %{"domain" => "example.com", "timezone" => "Europe/London"}

      assert {:ok, %{site: %{domain: "example.com", timezone: "Europe/London"}}} =
               Sites.create(user, params, team)

      assert Repo.reload(team).locked
    end

    test "does not start a trial for pre-teams guest users without trial expiry date" do
      user = new_user() |> subscribe_to_growth_plan()
      new_site(owner: user)

      three_hundred_days_from_now = Date.shift(Date.utc_today(), day: 300)

      user
      |> team_of()
      |> Ecto.Changeset.change(
        trial_expiry_date: nil,
        accept_traffic_until: three_hundred_days_from_now
      )
      |> Plausible.Repo.update!()

      params = %{"domain" => "example.com", "timezone" => "Europe/London"}

      user = Plausible.Repo.reload!(user)

      assert {:ok, %{site: %{domain: "example.com", timezone: "Europe/London"}}} =
               Sites.create(user, params)

      team = user |> team_of() |> Repo.reload!()
      refute team.trial_expiry_date
      assert Date.compare(team.accept_traffic_until, three_hundred_days_from_now) == :eq
    end

    test "fails on invalid timezone" do
      user = insert(:user)

      params = %{"domain" => "example.com", "timezone" => "blah"}

      assert {:error, :site, %{errors: [timezone: {"is invalid", []}]}, %{}} =
               Sites.create(user, params)
    end

    test "fails for user owning more than one team without explicit pick" do
      user = new_user()
      _site1 = new_site(owner: user)
      site2 = new_site()
      add_member(site2.team, user: user, role: :owner)

      params = %{"domain" => "example.com", "timezone" => "Europe/London"}

      assert {:error, _, :multiple_teams, _} = Sites.create(user, params)
    end

    test "fails for user not being permitted to add sites in selected team" do
      user = new_user()
      site = new_site()
      viewer_team = site.team
      add_member(viewer_team, user: user, role: :viewer)
      other_site = new_site()
      other_team = other_site.team

      params = %{"domain" => "example.com", "timezone" => "Europe/London"}

      assert {:error, _, :permission_denied, _} = Sites.create(user, params, viewer_team)
      assert {:error, _, :permission_denied, _} = Sites.create(user, params, other_team)
    end

    test "succeeds for user being permitted to add sites in selected team" do
      user = new_user()
      viewer_site = new_site()
      viewer_team = viewer_site.team
      editor_site = new_site()
      editor_team = editor_site.team

      add_member(viewer_team, user: user, role: :viewer)
      add_member(editor_team, user: user, role: :editor)

      params = %{"domain" => "example.com", "timezone" => "Europe/London"}

      assert {:ok, %{site: site}} = Sites.create(user, params, editor_team)

      assert site.team_id == editor_team.id
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
      user1 = new_user()
      user2 = new_user()
      patch_env(:super_admin_user_ids, [user2.id])

      %{id: site_id, domain: domain} = new_site(owner: user1)
      assert %{id: ^site_id} = Plausible.Sites.get_for_user(user1, domain)

      assert %{id: ^site_id} =
               Plausible.Sites.get_for_user(user1, domain, [:owner])

      assert is_nil(Plausible.Sites.get_for_user(user2, domain))

      assert %{id: ^site_id} =
               Plausible.Sites.get_for_user(user2, domain, [:super_admin])
    end
  end

  describe "list/3 and list_with_invitations/3" do
    test "returns empty when there are no sites" do
      user = new_user()
      _rogue_site = new_site()

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

    test "lists guest sites, site invitations and transfers when no current team set" do
      user1 = new_user()
      user2 = new_user()
      user3 = new_user()
      user4 = new_user()

      # owned site on a setup team
      site1 = new_site(owner: user1, domain: "own.example.com")
      Plausible.Teams.complete_setup(site1.team)

      # guest site access
      site2 = new_site(owner: user2, domain: "guest.example.com")
      add_guest(site2, user: user1, role: :editor)

      # site invitation
      site3 = new_site(owner: user3, domain: "invitation.example.com")
      invite_guest(site3, user1, role: :viewer, inviter: user3)

      # transfer
      site4 = new_site(domain: "transfer.example.com", owner: user3)
      invite_transfer(site4, user1, inviter: user2)

      # other team site access
      site5 = new_site(domain: "team.example.com", owner: user4)
      add_member(site5.team, user: user1, role: :editor)

      assert %{
               entries: [
                 %{domain: "invitation.example.com"},
                 %{domain: "transfer.example.com"},
                 %{domain: "guest.example.com"}
               ]
             } =
               Sites.list_with_invitations(user1, %{})
    end

    test "lists guest sites, site invitations, transfers and team sites when current team set but not setup" do
      user1 = new_user()
      user2 = new_user()
      user3 = new_user()
      user4 = new_user()

      # owned site on a personal team
      site1 = new_site(owner: user1, domain: "own.example.com")

      # guest site access
      site2 = new_site(owner: user2, domain: "guest.example.com")
      add_guest(site2, user: user1, role: :editor)

      # site invitation
      site3 = new_site(owner: user3, domain: "invitation.example.com")
      invite_guest(site3, user1, role: :viewer, inviter: user3)

      # transfer
      site4 = new_site(domain: "transfer.example.com", owner: user3)
      invite_transfer(site4, user1, inviter: user2)

      # other team site access
      site5 = new_site(domain: "team.example.com", owner: user4)
      add_member(site5.team, user: user1, role: :editor)

      assert %{
               entries: [
                 %{domain: "invitation.example.com"},
                 %{domain: "transfer.example.com"},
                 %{domain: "guest.example.com"},
                 %{domain: "own.example.com"}
               ]
             } =
               Sites.list_with_invitations(user1, %{}, team: site1.team)
    end

    test "lists team sites and transfers when current team set and setup" do
      user1 = new_user()
      user2 = new_user()
      user3 = new_user()
      user4 = new_user()

      # owned site on a personal team
      new_site(owner: user1, domain: "own.example.com")

      # guest site access
      site2 = new_site(owner: user2, domain: "guest.example.com")
      add_guest(site2, user: user1, role: :editor)

      # site invitation
      site3 = new_site(owner: user3, domain: "invitation.example.com")
      invite_guest(site3, user1, role: :viewer, inviter: user3)

      # transfer
      site4 = new_site(domain: "transfer.example.com", owner: user3)
      invite_transfer(site4, user1, inviter: user2)

      # other team site access
      site5 = new_site(domain: "team.example.com", owner: user4)
      team5 = Plausible.Teams.complete_setup(site5.team)
      add_member(site5.team, user: user1, role: :admin)

      assert %{
               entries: [
                 %{domain: "transfer.example.com"},
                 %{domain: "team.example.com"}
               ]
             } =
               Sites.list_with_invitations(user1, %{}, team: team5)
    end

    test "shows both pending transfer and pinned site for user without team with guest membership" do
      owner = new_user()
      pending_owner = new_user()
      site = new_site(owner: owner, domain: "one.example.com")
      add_guest(site, user: pending_owner, role: :editor)

      invite_transfer(site, pending_owner, inviter: owner)

      {:ok, _} = Sites.toggle_pin(pending_owner, site)

      assert %{
               entries: [
                 %{domain: "one.example.com", entry_type: "invitation"},
                 %{domain: "one.example.com", entry_type: "pinned_site"}
               ]
             } =
               Sites.list_with_invitations(pending_owner, %{})
    end

    test "shows both pending transfer and site for user without team with guest membership" do
      owner = new_user()
      pending_owner = new_user()
      site = new_site(owner: owner, domain: "one.example.com")
      add_guest(site, user: pending_owner, role: :editor)

      invite_transfer(site, pending_owner, inviter: owner)

      assert %{
               entries: [
                 %{domain: "one.example.com", entry_type: "invitation"},
                 %{domain: "one.example.com", entry_type: "site"}
               ]
             } =
               Sites.list_with_invitations(pending_owner, %{})
    end

    test "shows both pending transfer and site for user with personal team with guest membership" do
      owner = new_user()
      pending_owner = new_user() |> subscribe_to_growth_plan()
      pending_team = team_of(pending_owner)
      site = new_site(owner: owner, domain: "one.example.com")
      add_guest(site, user: pending_owner, role: :editor)

      invite_transfer(site, pending_owner, inviter: owner)

      assert %{
               entries: [
                 %{domain: "one.example.com", entry_type: "invitation"},
                 %{domain: "one.example.com", entry_type: "site"}
               ]
             } =
               Sites.list_with_invitations(pending_owner, %{}, team: pending_team)
    end

    test "shows only pending transfer for user with setup team with guest membership" do
      owner = new_user()
      pending_owner = new_user() |> subscribe_to_growth_plan()

      pending_team =
        pending_owner
        |> team_of()
        |> Plausible.Teams.complete_setup()

      site = new_site(owner: owner, domain: "one.example.com")
      add_guest(site, user: pending_owner, role: :editor)

      invite_transfer(site, pending_owner, inviter: owner)

      assert %{
               entries: [
                 %{domain: "one.example.com", entry_type: "invitation"}
               ]
             } =
               Sites.list_with_invitations(pending_owner, %{}, team: pending_team)
    end

    test "does not show transfer for user with site in their personal team" do
      owner = new_user()
      pending_owner = new_user() |> subscribe_to_growth_plan()
      pending_team = team_of(pending_owner)
      site = new_site(owner: pending_owner, domain: "one.example.com")

      invite_transfer(site, pending_owner, inviter: owner)

      assert %{
               entries: [
                 %{domain: "one.example.com", entry_type: "site"}
               ]
             } =
               Sites.list_with_invitations(pending_owner, %{}, team: pending_team)
    end

    test "does not show transfer for user with site in their setup team" do
      owner = new_user()
      pending_owner = new_user() |> subscribe_to_growth_plan()
      pending_team = team_of(pending_owner)
      site = new_site(owner: pending_owner, domain: "one.example.com")

      pending_team = Plausible.Teams.complete_setup(pending_team)

      invite_transfer(site, pending_owner, inviter: owner)

      assert %{
               entries: [
                 %{domain: "one.example.com", entry_type: "site"}
               ]
             } =
               Sites.list_with_invitations(pending_owner, %{}, team: pending_team)
    end

    test "pinned site doesn't matter with membership revoked (no active invitations)" do
      user1 = new_user(email: "user1@example.com")
      _user2 = new_user(email: "user2@example.com")

      new_site(owner: user1, domain: "one.example.com")
      site2 = new_site(domain: "two.example.com")

      user1 = site2 |> add_guest(user: user1, role: :viewer)

      {:ok, _} = Sites.toggle_pin(user1, site2)

      revoke_membership(site2, user1)

      assert %{entries: [%{domain: "one.example.com"}]} = Sites.list(user1, %{})
      assert %{entries: [%{domain: "one.example.com"}]} = Sites.list_with_invitations(user1, %{})

      assert %{entries: [%{domain: "one.example.com"}]} = Plausible.Teams.Sites.list(user1, %{})

      assert %{entries: [%{domain: "one.example.com"}]} =
               Plausible.Teams.Sites.list_with_invitations(user1, %{})
    end

    test "pinned site with active invitation" do
      user1 = new_user(email: "user1@example.com")
      user2 = new_user(email: "user2@example.com")

      site1 = new_site(domain: "one.example.com", owner: user1)
      site2 = new_site(domain: "two.example.com")

      invite_guest(site2, user1, role: :editor, inviter: user2)

      {:ok, _} = Sites.toggle_pin(user1, site1)

      assert %{entries: [%{domain: "one.example.com"}]} = Sites.list(user1, %{})

      assert %{
               entries: [
                 %{domain: "two.example.com", entry_type: "invitation"},
                 %{domain: "one.example.com", entry_type: "pinned_site"}
               ]
             } =
               Sites.list_with_invitations(user1, %{})

      assert %{entries: [%{domain: "one.example.com"}]} = Plausible.Teams.Sites.list(user1, %{})

      assert %{entries: [%{domain: "two.example.com"}, %{domain: "one.example.com"}]} =
               Plausible.Teams.Sites.list_with_invitations(user1, %{})
    end

    test "pinned site on active invitation" do
      user1 = new_user(email: "user1@example.com")
      user2 = new_user(email: "user2@example.com")

      site1 = new_site(domain: "one.example.com", owner: user2)

      add_guest(site1, user: user1, role: :editor)
      {:ok, _} = Sites.toggle_pin(user1, site1)
      revoke_membership(site1, user1)

      invite_guest(site1, user1, role: :editor, inviter: user2)

      assert %{entries: []} = Sites.list(user1, %{})

      assert %{
               entries: [
                 %{domain: "one.example.com", entry_type: "invitation"}
               ]
             } =
               Sites.list_with_invitations(user1, %{})

      assert %{entries: []} = Plausible.Teams.Sites.list(user1, %{})

      assert %{entries: [%{domain: "one.example.com", entry_type: "invitation"}]} =
               Plausible.Teams.Sites.list_with_invitations(user1, %{})
    end

    test "puts invitations first, pinned sites second, sites last" do
      user1 = new_user()
      user2 = new_user()
      user3 = new_user()

      site1 = new_site(owner: user1, domain: "one.example.com")
      site2 = new_site(owner: user2, domain: "two.example.com")
      site3 = new_site(owner: user3, domain: "three.example.com")
      site4 = new_site(domain: "four.example.com")
      site5 = new_site(owner: user3, domain: "five.example.com")

      invite_guest(site2, user1, role: :editor, inviter: user2)
      add_guest(site3, user: user1, role: :viewer)
      add_guest(site4, user: user1, role: :editor)

      invite_transfer(site5, user1, inviter: user3)

      {:ok, _} = Sites.toggle_pin(user1, site3)
      {:ok, _pin_to_ignore} = Sites.toggle_pin(user2, site2)

      site1_id = site1.id
      site2_id = site2.id
      site3_id = site3.id
      site4_id = site4.id
      site5_id = site5.id

      assert %{
               entries: [
                 %{id: ^site3_id, entry_type: "pinned_site"},
                 %{id: ^site4_id, entry_type: "site"},
                 %{id: ^site1_id, entry_type: "site"}
               ]
             } = Sites.list(user1, %{})

      assert %{
               entries: [
                 %{id: ^site5_id, entry_type: "invitation"},
                 %{id: ^site2_id, entry_type: "invitation"},
                 %{id: ^site3_id, entry_type: "pinned_site"},
                 %{id: ^site4_id, entry_type: "site"},
                 %{id: ^site1_id, entry_type: "site"}
               ]
             } = Sites.list_with_invitations(user1, %{})
    end

    test "pinned sites are ordered according to the time they were pinned at" do
      user1 = new_user()
      user2 = new_user()
      user3 = new_user()

      site1 = new_site(owner: user1, domain: "one.example.com")
      site2 = new_site(owner: user2, domain: "two.example.com")
      site3 = new_site(domain: "three.example.com")
      site4 = new_site(domain: "four.example.com")
      site5 = new_site(owner: user3, domain: "five.example.com")

      invite_guest(site2, user1, role: :editor, inviter: user2)
      add_guest(site3, user: user1, role: :viewer)
      add_guest(site4, user: user1, role: :editor)

      invite_transfer(site5, user1, inviter: user3)

      {:ok, _} = Sites.toggle_pin(user1, site3)

      site1_id = site1.id
      site2_id = site2.id
      site3_id = site3.id
      site4_id = site4.id
      site5_id = site5.id

      Sites.set_option(user1, site1, :pinned_at, ~N[2023-10-22 12:00:00])
      {:ok, _} = Sites.toggle_pin(user1, site3)

      assert %{
               entries: [
                 %{id: ^site3_id, entry_type: "pinned_site"},
                 %{id: ^site1_id, entry_type: "pinned_site"},
                 %{id: ^site4_id, entry_type: "site"}
               ]
             } = Sites.list(user1, %{})

      assert %{
               entries: [
                 %{id: ^site5_id, entry_type: "invitation"},
                 %{id: ^site2_id, entry_type: "invitation"},
                 %{id: ^site3_id, entry_type: "pinned_site"},
                 %{id: ^site1_id, entry_type: "pinned_site"},
                 %{id: ^site4_id, entry_type: "site"}
               ]
             } = Sites.list_with_invitations(user1, %{})
    end

    test "filters by domain" do
      user1 = new_user()
      user2 = new_user()
      user3 = new_user()

      site1 = new_site(owner: user1, domain: "first.example.com")
      site2 = new_site(owner: user2, domain: "first-transfer.example.com")
      site3 = new_site(owner: user3, domain: "first-invitation.example.com")
      _site4 = new_site(owner: user1, domain: "another.example.com")

      invite_guest(site3, user1, role: :viewer, inviter: user3)
      invite_transfer(site2, user1, inviter: user2)

      site1_id = site1.id
      site2_id = site2.id
      site3_id = site3.id

      assert %{
               entries: [
                 %{id: ^site1_id}
               ]
             } = Sites.list(user1, %{}, filter_by_domain: "first")

      assert %{
               entries: [
                 %{id: ^site3_id},
                 %{id: ^site2_id},
                 %{id: ^site1_id}
               ]
             } = Sites.list_with_invitations(user1, %{}, filter_by_domain: "first")
    end

    test "scopes by team when provided" do
      user1 = new_user()
      user2 = new_user()
      user3 = new_user()

      site1 = new_site(owner: user1, domain: "first.example.com")
      site2 = new_site(owner: user2, domain: "first-transfer.example.com")
      site3 = new_site(owner: user3, domain: "first-invitation.example.com")
      site4 = new_site(domain: "zzzsitefromanotherteam.com")

      invite_guest(site3, user1, role: :viewer, inviter: user3)
      invite_transfer(site2, user1, inviter: user2)
      team4 = Plausible.Teams.complete_setup(site4.team)
      add_member(team4, user: user1, role: :admin)

      assert_matches %{
                       entries: [
                         %{id: ^site1.id}
                       ]
                     } = Sites.list(user1, %{})

      assert_matches %{
                       entries: [
                         %{id: ^site3.id},
                         %{id: ^site2.id},
                         %{id: ^site1.id}
                       ]
                     } = Sites.list_with_invitations(user1, %{})

      assert_matches %{
                       entries: [
                         %{id: ^site4.id}
                       ]
                     } = Sites.list(user1, %{}, team: team4)

      assert_matches %{
                       entries: [
                         %{id: ^site2.id},
                         %{id: ^site4.id}
                       ]
                     } = Sites.list_with_invitations(user1, %{}, team: team4)
    end

    test "handles pagination correctly" do
      user1 = new_user()
      user2 = new_user()
      user3 = new_user()

      site1 = new_site(owner: user1, domain: "one.example.com")
      site2 = new_site(owner: user2, domain: "two.example.com")
      site3 = new_site(domain: "three.example.com")
      site4 = new_site(domain: "four.example.com")
      site5 = new_site(owner: user3, domain: "five.example.com")

      invite_guest(site2, user1, role: :editor, inviter: user2)
      add_guest(site3, user: user1, role: :viewer)
      add_guest(site4, user: user1, role: :editor)

      invite_transfer(site5, user1, inviter: user3)

      {:ok, _} = Sites.toggle_pin(user1, site3)

      site1_id = site1.id
      site2_id = site2.id
      site3_id = site3.id
      site4_id = site4.id
      site5_id = site5.id

      assert %{
               entries: [%{id: ^site3_id}, %{id: ^site4_id}],
               page_number: 1,
               page_size: 2,
               total_entries: 3,
               total_pages: 2
             } = Sites.list(user1, %{"page_size" => 2})

      assert %{
               entries: [%{id: ^site1_id}],
               page_number: 2,
               page_size: 2,
               total_entries: 3,
               total_pages: 2
             } = Sites.list(user1, %{"page_size" => 2, "page" => 2})

      assert %{
               entries: [%{id: ^site3_id}, %{id: ^site4_id}, %{id: ^site1_id}],
               page_number: 1,
               page_size: 3,
               total_entries: 3,
               total_pages: 1
             } = Sites.list(user1, %{"page_size" => 3})

      # list_with_invitations
      #
      assert %{
               entries: [%{id: ^site5_id}, %{id: ^site2_id}],
               page_number: 1,
               page_size: 2,
               total_entries: 5,
               total_pages: 3
             } = Sites.list_with_invitations(user1, %{"page_size" => 2})

      assert %{
               entries: [%{id: ^site3_id}, %{id: ^site4_id}],
               page_number: 2,
               page_size: 2,
               total_entries: 5,
               total_pages: 3
             } = Sites.list_with_invitations(user1, %{"page_size" => 2, "page" => 2})

      assert %{
               entries: [%{id: ^site1_id}],
               page_number: 3,
               page_size: 2,
               total_entries: 5,
               total_pages: 3
             } = Sites.list_with_invitations(user1, %{"page_size" => 2, "page" => 3})
    end
  end

  describe "set_option/4" do
    test "allows setting option multiple times" do
      user = new_user()
      site = new_site(owner: user)

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
      user = new_user()
      site = new_site(owner: user)

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
      user = new_user()
      site = new_site(owner: user)

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

    test "handles multiple guest memberships with same team properly (regression)" do
      user = new_user()
      owner = new_user()
      site1 = new_site(owner: owner)
      site2 = new_site(owner: owner)
      add_guest(site1, user: user, role: :viewer)
      add_guest(site2, user: user, role: :viewer)

      assert {:ok, prefs} = Sites.toggle_pin(user, site1)
      assert prefs.site_id == site1.id
      assert prefs.user_id == user.id
      assert prefs.pinned_at
    end

    test "returns error when pins limit hit" do
      user = new_user()

      for _ <- 1..9 do
        site = new_site(owner: user)
        assert {:ok, _} = Sites.toggle_pin(user, site)
      end

      site = new_site(owner: user)

      assert {:error, :too_many_pins} = Sites.toggle_pin(user, site)
    end
  end
end
