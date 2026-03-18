defmodule Plausible.SitesTest do
  use Plausible.DataCase

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

  on_ee do
    describe "create a site - SSO user" do
      setup [:create_user, :create_team, :create_site, :setup_sso, :provision_sso_user]

      test "creates a site for SSO user in a setup team", %{user: user, team: team} do
        params = %{"domain" => "example.com", "timezone" => "Europe/London"}

        assert {:ok, %{site: %{domain: "example.com", timezone: "Europe/London"}}} =
                 Sites.create(user, params, team)
      end

      test "does not allow creating a site in SSO user's personal team", %{
        team: team,
        sso_integration: integration
      } do
        user = add_member(team, role: :editor)
        {:ok, personal_team} = Plausible.Teams.get_or_create(user)
        identity = new_identity(user.name, user.email, integration)
        {:ok, _, _, user} = Plausible.Auth.SSO.provision_user(identity)

        params = %{"domain" => "example.com", "timezone" => "Europe/London"}

        assert {:error, _, :permission_denied, _} = Sites.create(user, params, personal_team)
      end
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

      assert Sites.stats_start_date(site) == Plausible.Times.today(site.timezone)
    end

    test "memoizes value of start date" do
      site = insert(:site)

      assert site.stats_start_date == nil

      populate_stats(site, [
        build(:pageview)
      ])

      assert Sites.stats_start_date(site) == Plausible.Times.today(site.timezone)
      assert Repo.reload!(site).stats_start_date == Plausible.Times.today(site.timezone)
    end

    on_ee do
      test "resets consolidated view stats dates every time" do
        owner = new_user()
        new_site(owner: owner)
        new_site(owner: owner)
        team = team_of(owner)

        consolidated_view = new_consolidated_view(team)

        assert consolidated_view.stats_start_date == ~D[2000-01-01]
        assert Sites.stats_start_date(consolidated_view) == ~D[2000-01-01]

        new_site(team: team, native_stats_start_at: ~N[1999-01-01 12:00:00])

        assert Sites.stats_start_date(consolidated_view) == ~D[1999-01-01]
      end
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

      assert Sites.native_stats_start_date(site) == Plausible.Times.today(site.timezone)
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
      assert %{id: ^site_id} = Sites.get_for_user(user1, domain)

      assert %{id: ^site_id} =
               Sites.get_for_user(user1, domain, roles: [:owner])

      assert is_nil(Sites.get_for_user(user2, domain))

      assert %{id: ^site_id} =
               Sites.get_for_user(user2, domain, roles: [:super_admin])
    end

    test "ignores consolidated site by default" do
      user = new_user()
      %{domain: domain} = new_site(owner: user, consolidated: true)
      refute Sites.get_for_user(user, domain)
      assert_raise(Ecto.NoResultsError, fn -> Sites.get_for_user!(user, domain) end)
    end

    test "includes consolidated site when explicitly requested" do
      user = new_user()
      %{domain: domain} = new_site(owner: user, consolidated: true)
      assert Sites.get_for_user(user, domain, include_consolidated?: true)
      assert Sites.get_for_user!(user, domain, include_consolidated?: true)
    end
  end
end
