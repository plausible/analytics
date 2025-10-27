defmodule Plausible.ConsolidatedViewTest do
  use Plausible

  on_ee do
    use Plausible.DataCase, async: true
    import Ecto.Query
    import Plausible.Teams.Test
    alias Plausible.ConsolidatedView
    alias Plausible.Teams

    describe "enable/1 and enabled?/1" do
      setup [:create_user, :create_team]

      test "creates and persists a new consolidated site instance", %{team: team} do
        new_site(team: team)
        team = Teams.complete_setup(team)
        assert {:ok, %Plausible.Site{consolidated: true}} = ConsolidatedView.enable(team)
        assert ConsolidatedView.enabled?(team)
      end

      test "is idempotent", %{team: team} do
        new_site(team: team)
        team = Teams.complete_setup(team)
        assert {:ok, s1} = ConsolidatedView.enable(team)
        assert {:ok, s2} = ConsolidatedView.enable(team)

        assert 1 =
                 from(s in Plausible.ConsolidatedView.sites(), where: s.team_id == ^team.id)
                 |> Plausible.Repo.aggregate(:count)

        assert s1.domain == s2.domain
      end

      test "returns {:error, :no_sites} when the team does not have any sites", %{team: team} do
        team = Teams.complete_setup(team)
        assert {:error, :no_sites} = ConsolidatedView.enable(team)
        refute ConsolidatedView.enabled?(team)
      end

      test "returns {:error, :team_not_setup} when the team is not set up", %{team: team} do
        assert {:error, :team_not_setup} = ConsolidatedView.enable(team)
        refute ConsolidatedView.enabled?(team)
      end

      @tag :skip
      test "returns {:error, :upgrade_required} when team ineligible for this feature"

      test "creates consolidated view with stats start dates of the oldest site", %{team: team} do
        team = Teams.complete_setup(team)

        datetimes = [
          ~N[2024-01-01 12:00:00],
          ~N[2024-01-01 11:00:00],
          ~N[2024-02-01 12:00:00]
        ]

        for dt <- datetimes, do: new_site(team: team, native_stats_start_at: dt)

        {:ok, view} = ConsolidatedView.enable(team)

        min = Enum.min(datetimes)
        assert view.native_stats_start_at == min
        assert view.stats_start_date == NaiveDateTime.to_date(min)
      end

      test "enable/1 updates cache", %{team: team} do
        team = Teams.complete_setup(team)
        site = new_site(team: team)
        {:ok, _} = ConsolidatedView.enable(team)

        assert eventually(fn ->
                 {ConsolidatedView.Cache.get(team.identifier) == [site.id], :ok}
               end)
      end

      test "sets Etc/UTC by default", %{team: team} do
        new_site(team: team)
        team = Teams.complete_setup(team)

        assert {:ok, %Plausible.Site{timezone: "Etc/UTC"}} =
                 ConsolidatedView.enable(team)
      end

      test "sets Etc/UTC for UTC sites", %{team: team} do
        new_site(team: team, timezone: "UTC")
        team = Teams.complete_setup(team)

        assert {:ok, %Plausible.Site{timezone: "Etc/UTC"}} =
                 ConsolidatedView.enable(team)
      end

      test "sets majority timezone by default", %{team: team} do
        new_site(team: team, timezone: "Etc/UTC")
        new_site(team: team, timezone: "Europe/Tallinn")
        new_site(team: team, timezone: "Europe/Warsaw")
        new_site(team: team, timezone: "Europe/Tallinn")

        team = Teams.complete_setup(team)

        assert {:ok, %Plausible.Site{timezone: "Europe/Tallinn"}} =
                 ConsolidatedView.enable(team)
      end
    end

    describe "disable/1" do
      setup [:create_user, :create_team, :create_site]

      setup %{team: team} do
        new_consolidated_view(team)
        :ok
      end

      test "deletes an existing consolidated site instance", %{team: team} do
        assert ConsolidatedView.get(team)

        assert :ok = ConsolidatedView.disable(team)

        refute ConsolidatedView.get(team)
      end

      test "is idempotent", %{team: team} do
        assert :ok = ConsolidatedView.disable(team)
        assert :ok = ConsolidatedView.disable(team)

        refute ConsolidatedView.get(team)
      end
    end

    describe "can_manage?/2" do
      test "invalid membership" do
        refute ConsolidatedView.can_manage?(%Plausible.Auth.User{id: 1}, %Plausible.Teams.Team{
                 id: 1
               })
      end

      test "viewer" do
        team = new_site().team
        viewer = add_member(team, role: :viewer)
        refute ConsolidatedView.can_manage?(viewer, team)
      end

      test "not a viewer" do
        team = new_site().team
        viewer = add_member(team, role: :editor)
        assert ConsolidatedView.can_manage?(viewer, team)
      end

      test "not a viewer + guest" do
        site = new_site()
        viewer = add_guest(site, role: :editor)
        refute ConsolidatedView.can_manage?(viewer, site.team)
      end

      test "viewer + guest" do
        site = new_site()
        viewer = add_guest(site, role: :viewer)
        refute ConsolidatedView.can_manage?(viewer, site.team)
      end
    end

    describe "site_ids/1" do
      setup [:create_user, :create_team, :create_site]

      test "returns {:error, :not_found} when no consolidated view exists", %{team: team} do
        assert {:error, :not_found} = ConsolidatedView.site_ids(team)
      end

      test "returns site_ids owned by the team when consolidated view exists", %{
        team: team,
        site: site
      } do
        new_consolidated_view(team)
        assert ConsolidatedView.site_ids(team) == {:ok, [site.id]}
      end
    end

    describe "get/1" do
      setup [:create_user, :create_team, :create_site]

      test "can get by team", %{team: team} do
        assert is_nil(ConsolidatedView.get(team))
        new_consolidated_view(team)
        assert %Plausible.Site{} = ConsolidatedView.get(team)
      end

      test "can get by team.identifier", %{team: team} do
        assert is_nil(ConsolidatedView.get(team.identifier))
        new_consolidated_view(team)
        assert %Plausible.Site{} = ConsolidatedView.get(team.identifier)
      end
    end

    # see also: Site.RemovalTest and Sites.TransferTest
    describe "reset_if_enabled/1" do
      setup [:create_user, :create_team]

      test "no-op if disabled", %{team: team} do
        :ok = ConsolidatedView.reset_if_enabled(team)
        refute ConsolidatedView.enabled?(team)
        refute ConsolidatedView.get(team)
      end

      @tag :slow
      test "re-enables", %{team: team} do
        _site =
          new_site(
            team: team,
            native_stats_start_at: ~N[2024-01-01 12:00:00],
            timezone: "Europe/Warsaw"
          )

        team = Teams.complete_setup(team)

        {:ok, first_enable} = ConsolidatedView.enable(team)

        another_site =
          new_site(
            team: team,
            native_stats_start_at: ~N[2024-01-01 10:00:00],
            timezone: "Europe/Tallinn"
          )

        Process.sleep(1_000)

        :ok = ConsolidatedView.reset_if_enabled(team)
        assert ConsolidatedView.enabled?(team)

        consolidated_view = ConsolidatedView.get(team)
        assert consolidated_view.native_stats_start_at == another_site.native_stats_start_at
        assert NaiveDateTime.after?(consolidated_view.updated_at, first_enable.updated_at)
        assert consolidated_view.timezone == "Europe/Tallinn"
      end
    end
  end
end
